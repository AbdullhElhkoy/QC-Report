"""
واجهة API (DRF) لتطبيق Flutter (ويب/موبايل/ديسكتوب).

الفكرة الأساسية: مفيش تكرار لمنطق التحقق (validation) الموجود في forms.py.
بدل ما نعيد كتابة نفس القواعد كـ DRF Serializers، بنحوّل الـ JSON البسيط اللي
جاي من Flutter لنفس شكل الـ QueryDict اللي الفورمز الحالية بتفهمه (مع نفس
الـ prefixes بتاعتها)، وبعدين بننادي بالظبط نفس الدوال المستخدمة في views.py
(build_sop_rows / gcc_color_form / build_dcp_forms / PackingTableForm / ...).

ده معناه أي قاعدة تحقق موجودة في forms.py هتتطبق تلقائيًا هنا كمان،
من غير ما نصلحها في مكانين مختلفين.
"""
from decimal import Decimal

from django.core.exceptions import ValidationError
from django.db import transaction
from django.http import QueryDict
from django.utils import timezone
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .aggregations import full_daily_report
from .models import (
    DCPReason,
    DCPReasonCategory,
    EntryRevision,
    GCCColor,
    LoadingProductType,
    PackingFactory,
    PackingLineItem,
    PackingType,
    ShiftEntry,
    SOP_BULK_UNITS,
    SOP_PRODUCT_TYPES,
    Unit,
)
from .forms import (
    BulkLogForm,
    DCPASRowForm,
    DCPBBRowForm,
    DCPSBRowForm,
    DCPTestsForm,
    GCCSummaryForm,
    LoadingLineItemForm,
    PackingTableForm,
    ShiftEntryForm,
    SOPLineItemForm,
)
from .views import (
    _build_all_forms,
    _flatten_forms,
    _save_related,
    entry_tables,
    gcc_color_form,
    get_unit_or_404,
    next_shift_for,
    save_dcp_forms,
    save_loading_rows,
    save_sop_rows,
    snapshot_entry,
    unit_label,
    user_can_access_unit,
    SOP_UNIT_TEMPLATES,
)


def _jsonable(value):
    """Decimal/date/choice objects -> قيم عادية قابلة لـ JSON."""
    if isinstance(value, Decimal):
        return float(value)
    if hasattr(value, "isoformat"):
        return value.isoformat()
    return value


def _deep_jsonable(value):
    if isinstance(value, dict):
        return {k: _deep_jsonable(v) for k, v in value.items()}
    if isinstance(value, (list, tuple)):
        return [_deep_jsonable(v) for v in value]
    return _jsonable(value)


def _querydict_from_json(flat_fields):
    """
    flat_fields: dict بسيط {"row_S_B-exp": "0", "row_S_B-dom": "0", ...}
    بيتحول لـ QueryDict عشان فورمز Django تقدر تقرأه زي أي POST عادي.
    """
    qd = QueryDict(mutable=True)
    for key, value in flat_fields.items():
        if value is None:
            continue
        qd[key] = str(value)
    return qd


def _no_shift_response(unit_lbl):
    return Response(
        {"detail": f"تم تسجيل ورديات اليوم الثلاثة لوحدة {unit_lbl} بالفعل."},
        status=409,
    )


def _flat_from_payload(unit, payload):
    """بي steady نفس تحويل الـ create views: payload JSON -> QueryDict مسطّح
    بالـ prefixes اللي فورمز الويب بتفهمها. بيستخدم في التعديل (PUT)."""
    flat = {"general_notes": payload.get("general_notes", "")}
    if unit in SOP_UNIT_TEMPLATES:
        rows = payload.get("rows", {})
        for pt in SOP_PRODUCT_TYPES[unit]:
            row = rows.get(pt, {}) or {}
            for field in ("exp", "dom", "std", "nc", "cause", "note",
                          "defect_reason", "notes", "car_number", "car_weight"):
                if field in row:
                    flat[f"row_{pt}-{field}"] = row[field]
        if unit in SOP_BULK_UNITS and payload.get("bulk_log"):
            for field, val in payload["bulk_log"].items():
                flat[f"bulk-{field}"] = val
    elif unit in ("GCC1", "GCC2"):
        colors_in = payload.get("colors", {})
        for color in GCCColor:
            row = colors_in.get(color.value, {}) or {}
            flat[f"gcc_{color.value.lower()}-bb"] = row.get("bb", 0) or 0
            flat[f"gcc_{color.value.lower()}-defect_reason"] = row.get("defect_reason", "")
            flat[f"gcc_{color.value.lower()}-note"] = row.get("note", "")
        flat["gcc_sum-sb"] = payload.get("sb", 0) or 0
        flat["gcc_sum-nc"] = payload.get("nc", 0) or 0
    elif unit == "LOADING":
        rows = payload.get("rows", {})
        for pt in LoadingProductType:
            row = rows.get(pt, {}) or {}
            for field in ("exp", "dom"):
                if field in row:
                    flat[f"row_{pt}-{field}"] = row[field]
    elif unit == "DCP":
        section_map = (("bb", DCPBBRowForm), ("sb", DCPSBRowForm),
                       ("as_row", DCPASRowForm), ("tests", DCPTestsForm))
        prefix_map = {"bb": "bb", "sb": "sb", "as_row": "as", "tests": "tests"}
        field_map = {
            "bb": ["green", "yellow", "green_yellow", "blue", "white", "red", "note"],
            "sb": ["exp", "dom", "sb_white", "note"],
            "as_row": ["exp", "dom", "sb_white", "note"],
            "tests": ["lab_test", "floor_test"],
        }
        for key, _cls in section_map:
            section = payload.get(key, {}) or {}
            for field in field_map[key]:
                if field in section:
                    flat[f"{prefix_map[key]}-{field}"] = section[field]
        return flat, payload.get("white_reasons") or [], payload.get("nc_reasons") or []
    elif unit in ("PA", "SA"):
        values = payload.get("values", {}) or {}
        table = PackingTableForm(unit, entry=None, prefix=unit.lower())
        for t in table.types:
            flat[f"{unit.lower()}-type_{t.pk}"] = values.get(str(t.pk), values.get(t.pk, 0)) or 0
    return flat


def _build_payload_qd(unit, payload):
    """يرجع QueryDict جاهز للفورمز (مع أسباب DCP setlist)."""
    if unit == "DCP":
        flat, w_reasons, n_reasons = _flat_from_payload(unit, payload)
        data = _querydict_from_json(flat)
        data.setlist("w_reason", [str(r.get("reason_id", "")) for r in w_reasons])
        data.setlist("w_qty", [str(r.get("qty", 0)) for r in w_reasons])
        data.setlist("n_reason", [str(r.get("reason_id", "")) for r in n_reasons])
        data.setlist("n_qty", [str(r.get("qty", 0)) for r in n_reasons])
        return data
    return _querydict_from_json(_flat_from_payload(unit, payload))


def _num(value):
    if isinstance(value, int) or isinstance(value, float):
        return value
    try:
        return float(value)
    except (TypeError, ValueError):
        return 0


def entry_edit_values(entry):
    """قيم الإدخال الحالي بنفس شكل الـ create payloads عشان شاشة التعديل
    في Flutter تقدر تملأ نفس الحقول (pre-fill)."""
    unit = entry.unit
    values = {"general_notes": entry.general_notes}
    if unit in SOP_UNIT_TEMPLATES:
        rows = {}
        for pt in SOP_PRODUCT_TYPES[unit]:
            line = entry.sop_line_items.filter(product_type=pt).first()
            if line is None:
                rows[pt] = {}
                continue
            row = {
                "exp": line.exp, "dom": line.dom, "std": line.std, "nc": line.nc,
                "cause": line.cause, "note": line.note,
                "defect_reason": line.defect_reason, "notes": line.notes,
                "car_number": line.car_number, "car_weight": line.car_weight,
            }
            rows[pt] = _deep_jsonable(row)
        values["rows"] = rows
        if unit in SOP_BULK_UNITS and hasattr(entry, "bulk_log") and entry.bulk_log:
            b = entry.bulk_log
            values["bulk_log"] = {
                "exp_trucks": b.exp_trucks, "dom_trucks": b.dom_trucks,
                "std_trucks": b.std_trucks, "nc_trucks": b.nc_trucks,
            }
    elif unit in ("GCC1", "GCC2"):
        colors = {}
        for c in GCCColor:
            row = entry.gcc_rows.filter(color=c.value).first()
            colors[c.value] = {
                "bb": row.bb if row else 0,
                "defect_reason": row.defect_reason if row else "",
                "note": row.note if row else "",
            }
        values["colors"] = colors
        summary = getattr(entry, "gcc_summary", None)
        values["sb"] = _num(summary.sb) if summary else 0
        values["nc"] = _num(summary.nc) if summary else 0
    elif unit == "LOADING":
        rows = {}
        for pt in LoadingProductType:
            line = entry.loading_line_items.filter(product_type=pt).first()
            rows[pt] = {"exp": line.exp if line else 0, "dom": line.dom if line else 0}
        values["rows"] = rows
    elif unit == "DCP":
        bb = getattr(entry, "dcp_bb", None)
        sb = getattr(entry, "dcp_sb", None)
        as_row = getattr(entry, "dcp_as", None)
        tests = getattr(entry, "dcp_tests", None)
        values["bb"] = (
            {"green": bb.green, "yellow": bb.yellow, "green_yellow": bb.green_yellow,
             "blue": bb.blue, "white": bb.white, "red": bb.red, "note": bb.note}
            if bb else {}
        )
        values["sb"] = (
            {"exp": _num(sb.exp), "dom": _num(sb.dom),
             "sb_white": _num(sb.sb_white), "note": sb.note}
            if sb else {}
        )
        values["as_row"] = (
            {"exp": _num(as_row.exp), "dom": _num(as_row.dom),
             "sb_white": _num(as_row.sb_white), "note": as_row.note}
            if as_row else {}
        )
        values["tests"] = (
            {"lab_test": tests.lab_test, "floor_test": tests.floor_test}
            if tests else {}
        )
        w, n = [], []
        for line in entry.dcp_reason_lines.all():
            item = {"reason_id": line.reason_id, "qty": line.qty}
            if line.reason.category == DCPReasonCategory.WHITE:
                w.append(item)
            else:
                n.append(item)
        values["white_reasons"] = w
        values["nc_reasons"] = n
    elif unit in ("PA", "SA"):
        values["values"] = {
            str(item.packing_type_id): _num(item.value)
            for item in entry.packing_items.all()
        }
    return _deep_jsonable(values)


class MeAPIView(APIView):
    """بيانات المستخدم الحالي: اسمه، وحدته، هل هو مدير."""

    permission_classes = [IsAuthenticated]

    def get(self, request):
        u = request.user
        return Response(
            {
                "username": u.username,
                "full_name": u.get_full_name() or u.username,
                "is_manager": u.is_manager,
                "assigned_unit": u.assigned_unit,
                "assigned_unit_label": unit_label(u.assigned_unit) if u.assigned_unit else None,
            }
        )


class UnitsAPIView(APIView):
    """الوحدات المتاحة للمستخدم يقدر يدخل بيانات فيها."""

    permission_classes = [IsAuthenticated]

    def get(self, request):
        if request.user.is_manager:
            units = [{"value": v, "label": lbl} for v, lbl in Unit.choices]
        else:
            u = request.user.assigned_unit
            units = [{"value": u, "label": unit_label(u)}] if u else []
        return Response({"units": units})


class EntryStatusAPIView(APIView):
    """هل فيه وردية متاحة للإدخال دلوقتي لوحدة معينة؟"""

    permission_classes = [IsAuthenticated]

    def get(self, request, unit):
        get_unit_or_404(unit)
        if not user_can_access_unit(request.user, unit):
            return Response({"detail": "لا تملك صلاحية الوصول لهذه الوحدة."}, status=403)
        today = timezone.localdate()
        next_shift = next_shift_for(unit, today)
        from qc_report.models import ShiftEntry

        entries = ShiftEntry.objects.filter(
            entry_date=today, unit=unit
        ).order_by("shift")
        return Response(
            {
                "unit": unit,
                "unit_label": unit_label(unit),
                "date": today.isoformat(),
                "next_shift": next_shift,
                "all_shifts_done_today": next_shift is None,
                "today_entries": [
                    {
                        "id": e.pk,
                        "shift": e.shift,
                        "shift_label": e.get_shift_display(),
                        "submitted_at": e.submitted_at.astimezone().strftime("%H:%M"),
                    }
                    for e in entries
                ],
            }
        )


class SOPEntryCreateAPIView(APIView):
    """
    POST /api/entries/sop/<unit>/
    body:
    {
      "general_notes": "...",
      "bulk_log": {"exp_trucks": 0, "dom_trucks": 0, "std_trucks": 0, "nc_trucks": 0},
      "rows": {
        "S_B": {"exp": 0, "dom": 0, "std": 0, "nc": 0, "cause": "", "note": "",
                "defect_reason": "", "notes": "", "car_number": null, "car_weight": null}
      }
    }
    """

    permission_classes = [IsAuthenticated]

    def post(self, request, unit):
        get_unit_or_404(unit)
        if unit not in SOP_UNIT_TEMPLATES:
            return Response({"detail": "هذه الوحدة ليست من وحدات SOP."}, status=400)
        if not user_can_access_unit(request.user, unit):
            return Response({"detail": "لا تملك صلاحية إدخال بيانات لهذه الوحدة."}, status=403)

        today = timezone.localdate()
        next_shift = next_shift_for(unit, today)
        if next_shift is None:
            return _no_shift_response(unit_label(unit))

        payload = request.data
        rows = payload.get("rows", {})
        flat = {"general_notes": payload.get("general_notes", "")}
        for pt in SOP_PRODUCT_TYPES[unit]:
            row = rows.get(pt, {}) or {}
            for field in ("exp", "dom", "std", "nc", "cause", "note",
                          "defect_reason", "notes", "car_number", "car_weight"):
                if field in row:
                    flat[f"row_{pt}-{field}"] = row[field]
        if unit in SOP_BULK_UNITS and payload.get("bulk_log"):
            for field, val in payload["bulk_log"].items():
                flat[f"bulk-{field}"] = val

        data = _querydict_from_json(flat)

        shift_form = ShiftEntryForm(data)
        row_forms = [SOPLineItemForm(data, prefix=f"row_{pt}") for pt in SOP_PRODUCT_TYPES[unit]]
        bulk_form = None
        forms_ok = shift_form.is_valid() and all(f.is_valid() for f in row_forms)
        if unit in SOP_BULK_UNITS:
            bulk_form = BulkLogForm(data, prefix="bulk")
            forms_ok = forms_ok and bulk_form.is_valid()

        if not forms_ok:
            errors = {"shift": shift_form.errors, "rows": [f.errors for f in row_forms]}
            if bulk_form:
                errors["bulk_log"] = bulk_form.errors
            return Response({"detail": "بيانات غير صحيحة.", "errors": errors}, status=400)

        with transaction.atomic():
            entry = shift_form.save(commit=False)
            entry.unit = unit
            entry.submitted_by = request.user
            entry.entry_date = today
            entry.shift = next_shift
            entry.full_clean()
            entry.save()
            save_sop_rows(entry, data)
            if bulk_form:
                obj = bulk_form.save(commit=False)
                obj.shift_entry = entry
                obj.save()

        return Response(
            {"id": entry.pk, "shift": entry.shift, "entry_date": str(entry.entry_date)}, status=201
        )


class GCCEntryCreateAPIView(APIView):
    """
    POST /api/entries/gcc/<unit>/   (unit = GCC1 أو GCC2)
    body:
    {
      "general_notes": "",
      "colors": {
        "GREEN":  {"bb": 100, "defect_reason": "", "note": ""},
        "YELLOW": {"bb": 50}, "BLUE": {"bb": 25}, "WHITE": {"bb": 0}
      },
      "sb": 7.5,
      "nc": 3
    }
    """

    permission_classes = [IsAuthenticated]

    def post(self, request, unit):
        get_unit_or_404(unit)
        if unit not in ("GCC1", "GCC2"):
            return Response({"detail": "هذه الوحدة ليست GCC1/GCC2."}, status=400)
        if not user_can_access_unit(request.user, unit):
            return Response({"detail": "لا تملك صلاحية إدخال بيانات لهذه الوحدة."}, status=403)

        today = timezone.localdate()
        next_shift = next_shift_for(unit, today)
        if next_shift is None:
            return _no_shift_response(unit_label(unit))

        payload = request.data
        colors_in = payload.get("colors", {})
        flat = {"general_notes": payload.get("general_notes", "")}
        for color in GCCColor:
            row = colors_in.get(color.value, {}) or {}
            flat[f"gcc_{color.value.lower()}-bb"] = row.get("bb", 0) or 0
            flat[f"gcc_{color.value.lower()}-defect_reason"] = row.get("defect_reason", "")
            flat[f"gcc_{color.value.lower()}-note"] = row.get("note", "")
        flat["gcc_sum-sb"] = payload.get("sb", 0) or 0
        flat["gcc_sum-nc"] = payload.get("nc", 0) or 0

        data = _querydict_from_json(flat)

        shift_form = ShiftEntryForm(data)
        color_forms = {c.value: gcc_color_form(c.value, data=data, entry=None) for c in GCCColor}
        sum_form = GCCSummaryForm(data, prefix="gcc_sum")
        if not (
            shift_form.is_valid()
            and sum_form.is_valid()
            and all(f.is_valid() for f in color_forms.values())
        ):
            return Response(
                {
                    "detail": "بيانات غير صحيحة.",
                    "errors": {
                        "shift": shift_form.errors,
                        "summary": sum_form.errors,
                        "colors": {k: f.errors for k, f in color_forms.items()},
                    },
                },
                status=400,
            )

        with transaction.atomic():
            entry = shift_form.save(commit=False)
            entry.unit = unit
            entry.submitted_by = request.user
            entry.entry_date = today
            entry.shift = next_shift
            entry.full_clean()
            entry.save()
            for c in GCCColor:
                form = color_forms[c.value]
                obj = form.save(commit=False)
                obj.shift_entry = entry
                obj.color = c.value
                obj.save()
            summary = sum_form.save(commit=False)
            summary.shift_entry = entry
            summary.save()

        return Response(
            {"id": entry.pk, "shift": entry.shift, "entry_date": str(entry.entry_date)}, status=201
        )


class LoadingEntryCreateAPIView(APIView):
    """
    POST /api/entries/loading/
    body:
    {"general_notes": "", "rows": {"SOP": {"exp": 0, "dom": 0}, "GSOP": {...}, ...}}
    """

    permission_classes = [IsAuthenticated]
    UNIT = "LOADING"

    def post(self, request):
        unit = self.UNIT
        if not user_can_access_unit(request.user, unit):
            return Response({"detail": "لا تملك صلاحية إدخال بيانات لهذه الوحدة."}, status=403)

        today = timezone.localdate()
        next_shift = next_shift_for(unit, today)
        if next_shift is None:
            return _no_shift_response(unit_label(unit))

        payload = request.data
        rows = payload.get("rows", {})
        flat = {"general_notes": payload.get("general_notes", "")}
        for pt in LoadingProductType:
            row = rows.get(pt, {}) or {}
            for field in ("exp", "dom"):
                if field in row:
                    flat[f"row_{pt}-{field}"] = row[field]

        data = _querydict_from_json(flat)

        shift_form = ShiftEntryForm(data)
        row_forms = [
            LoadingLineItemForm(data, prefix=f"row_{pt}") for pt in LoadingProductType
        ]
        if not (shift_form.is_valid() and all(f.is_valid() for f in row_forms)):
            return Response(
                {
                    "detail": "بيانات غير صحيحة.",
                    "errors": {"shift": shift_form.errors, "rows": [f.errors for f in row_forms]},
                },
                status=400,
            )

        with transaction.atomic():
            entry = shift_form.save(commit=False)
            entry.unit = unit
            entry.submitted_by = request.user
            entry.entry_date = today
            entry.shift = next_shift
            entry.full_clean()
            entry.save()
            save_loading_rows(entry, data)

        return Response(
            {"id": entry.pk, "shift": entry.shift, "entry_date": str(entry.entry_date)}, status=201
        )


class DCPEntryCreateAPIView(APIView):
    """
    POST /api/entries/dcp/
    body:
    {
      "general_notes": "",
      "bb": {"green": 0, "yellow": 0, "green_yellow": 0, "blue": 0, "white": 5, "red": 2, "note": ""},
      "sb": {"exp": 0, "dom": 0, "sb_white": 0, "note": ""},
      "as_row": {"exp": 0, "dom": 0, "sb_white": 0, "note": ""},
      "tests": {"lab_test": 0, "floor_test": 0},
      "white_reasons": [{"reason_id": 3, "qty": 5}],
      "nc_reasons": [{"reason_id": 7, "qty": 2}]
    }

    قواعد التطابق الموجودة في save_dcp_forms بتتطبق تلقائيًا:
    مجموع أسباب الأبيض = bb.white ومجموع أسباه NC = bb.red، وإلا 400.
    """

    permission_classes = [IsAuthenticated]
    UNIT = "DCP"

    def post(self, request):
        unit = self.UNIT
        if not user_can_access_unit(request.user, unit):
            return Response({"detail": "لا تملك صلاحية إدخال بيانات لهذه الوحدة."}, status=403)

        today = timezone.localdate()
        next_shift = next_shift_for(unit, today)
        if next_shift is None:
            return _no_shift_response(unit_label(unit))

        payload = request.data
        flat = {"general_notes": payload.get("general_notes", "")}

        section_map = (("bb", DCPBBRowForm), ("sb", DCPSBRowForm),
                       ("as_row", DCPASRowForm), ("tests", DCPTestsForm))
        prefix_map = {"bb": "bb", "sb": "sb", "as_row": "as", "tests": "tests"}
        field_map = {
            "bb": ["green", "yellow", "green_yellow", "blue", "white", "red", "note"],
            "sb": ["exp", "dom", "sb_white", "note"],
            "as_row": ["exp", "dom", "sb_white", "note"],
            "tests": ["lab_test", "floor_test"],
        }
        sections = {}
        for key, _cls in section_map:
            sections[key] = payload.get(key, {}) or {}
            for field in field_map[key]:
                if field in sections[key]:
                    flat[f"{prefix_map[key]}-{field}"] = sections[key][field]

        data = _querydict_from_json(flat)
        # أسباب العيوب: قوائم (QueryDict.setlist) بنفس أسماء مفاتيح صفحة الويب
        w_reasons = payload.get("white_reasons") or []
        n_reasons = payload.get("nc_reasons") or []
        data.setlist("w_reason", [str(r.get("reason_id", "")) for r in w_reasons])
        data.setlist("w_qty", [str(r.get("qty", 0)) for r in w_reasons])
        data.setlist("n_reason", [str(r.get("reason_id", "")) for r in n_reasons])
        data.setlist("n_qty", [str(r.get("qty", 0)) for r in n_reasons])

        shift_form = ShiftEntryForm(data)
        check_forms = {
            "bb": DCPBBRowForm(data, prefix="bb"),
            "sb": DCPSBRowForm(data, prefix="sb"),
            "as_row": DCPASRowForm(data, prefix="as"),
            "tests": DCPTestsForm(data, prefix="tests"),
        }
        forms_ok = shift_form.is_valid() and all(f.is_valid() for f in check_forms.values())
        if not forms_ok:
            errors = {"shift": shift_form.errors}
            errors.update({k: f.errors for k, f in check_forms.items()})
            return Response({"detail": "بيانات غير صحيحة.", "errors": errors}, status=400)

        try:
            with transaction.atomic():
                entry = shift_form.save(commit=False)
                entry.unit = unit
                entry.submitted_by = request.user
                entry.entry_date = today
                entry.shift = next_shift
                entry.full_clean()
                entry.save()
                save_dcp_forms(entry, data)  # هنا تحقق تطابق الأسباب بيشتغل تلقائيًا
        except ValidationError as exc:
            return Response({"detail": exc.message}, status=400)

        return Response(
            {"id": entry.pk, "shift": entry.shift, "entry_date": str(entry.entry_date)}, status=201
        )


class DCPReasonsAPIView(APIView):
    """GET /api/dcp-reasons/ -> أسباب العيوب المتاحة لكل جدول (dropdown)."""

    permission_classes = [IsAuthenticated]

    def get(self, request):
        qs = DCPReason.objects.filter(is_active=True).order_by("name")

        def ser(category):
            return [
                {"id": r.id, "name": r.name}
                for r in qs.filter(category=category)
            ]

        return Response({"white": ser(DCPReasonCategory.WHITE), "nc": ser(DCPReasonCategory.NC)})


class PackingTypesAPIView(APIView):
    """GET /api/packing-types/<factory>/  (factory = PA أو SA) -> أنواع التعبئة النشطة."""

    permission_classes = [IsAuthenticated]

    def get(self, request, factory):
        factory = factory.upper()
        if factory not in (PackingFactory.PA, PackingFactory.SA):
            return Response({"detail": "المصنع لازم يكون PA أو SA."}, status=400)
        types = PackingType.objects.filter(factory=factory, is_active=True).order_by("order", "id")
        return Response(
            {"factory": factory, "types": [{"id": t.id, "name": t.name} for t in types]}
        )


class PackingEntryCreateAPIView(APIView):
    """
    POST /api/entries/packing/<unit>/   (unit = PA أو SA)
    body: {"general_notes": "", "values": {"<packing_type_id>": 12.5}}
    """

    permission_classes = [IsAuthenticated]

    def post(self, request, unit):
        unit = unit.upper()
        if unit not in (PackingFactory.PA, PackingFactory.SA):
            return Response({"detail": "الوحدة لازم تكون PA أو SA."}, status=400)
        if not user_can_access_unit(request.user, unit):
            return Response({"detail": "لا تملك صلاحية إدخال بيانات لهذه الوحدة."}, status=403)

        today = timezone.localdate()
        next_shift = next_shift_for(unit, today)
        if next_shift is None:
            return _no_shift_response(unit_label(unit))

        payload = request.data
        values = payload.get("values", {}) or {}
        flat = {"general_notes": payload.get("general_notes", "")}
        table = PackingTableForm(unit, entry=None, prefix=unit.lower())
        for t in table.types:
            flat[f"{unit.lower()}-type_{t.pk}"] = values.get(str(t.pk), values.get(t.pk, 0)) or 0

        data = _querydict_from_json(flat)

        shift_form = ShiftEntryForm(data)
        bound = PackingTableForm(unit, data=data, prefix=unit.lower())
        if not (shift_form.is_valid() and bound.is_valid()):
            return Response(
                {
                    "detail": "بيانات غير صحيحة.",
                    "errors": {"shift": shift_form.errors, "packing": bound.errors},
                },
                status=400,
            )

        cleaned = bound.cleaned_data
        with transaction.atomic():
            entry = shift_form.save(commit=False)
            entry.unit = unit
            entry.submitted_by = request.user
            entry.entry_date = today
            entry.shift = next_shift
            entry.full_clean()
            entry.save()
            for t in bound.types:
                value = cleaned.get(f"type_{t.pk}") or 0
                PackingLineItem.objects.update_or_create(
                    shift_entry=entry,
                    packing_type=t,
                    defaults={"value": value},
                )

        return Response(
            {"id": entry.pk, "shift": entry.shift, "entry_date": str(entry.entry_date)}, status=201
        )


class EntryDetailAPIView(APIView):
    """
    GET/PUT/DELETE /api/entries/<pk>/
    GET: تفاصيل الإدخال (أي وحدة) بنفس entry_tables() المستخدمة على الويب +
         values بنفس شكل create payloads عشان شاشة التعديل.
    PUT: تعديل الإدخال — نفس فورمز الويب والتحقق بتاعهم + نسخة في EntryRevision.
    DELETE: حذف الإدخال (لو المدير أو صاحب الإدخال).
    """

    permission_classes = [IsAuthenticated]

    def _get_entry(self, request, pk):
        try:
            entry = ShiftEntry.objects.select_related("submitted_by").get(pk=pk)
        except ShiftEntry.DoesNotExist:
            return None, None
        u = request.user
        can_edit = u.is_manager or entry.submitted_by == u
        if not (can_edit or entry.unit == u.assigned_unit):
            return entry, None  # يظهر لصاحب الوحدة للعرض بس
        return entry, can_edit

    def get(self, request, pk):
        entry, can_edit = self._get_entry(request, pk)
        if entry is None:
            return Response({"detail": "غير موجود."}, status=404)
        u = request.user
        if not (u.is_manager or entry.submitted_by == u or entry.unit == u.assigned_unit):
            return Response({"detail": "لا تملك صلاحية عرض هذا الإدخال."}, status=403)

        sections = entry_tables(entry)
        return Response(
            {
                "id": entry.pk,
                "unit": entry.unit,
                "unit_label": unit_label(entry.unit),
                "entry_date": entry.entry_date.isoformat(),
                "shift": entry.shift,
                "shift_label": entry.get_shift_display(),
                "submitted_by": entry.submitted_by.get_full_name() or entry.submitted_by.username,
                "general_notes": entry.general_notes,
                "sections": _deep_jsonable(sections),
                "values": entry_edit_values(entry),
                "can_edit": can_edit,
                "can_delete": can_edit,
            }
        )

    def put(self, request, pk):
        entry, can_edit = self._get_entry(request, pk)
        if entry is None:
            return Response({"detail": "غير موجود."}, status=404)
        if not can_edit:
            return Response({"detail": "لا تملك صلاحية تعديل هذا الإدخال."}, status=403)

        unit = entry.unit
        data = _build_payload_qd(unit, request.data)
        ctx = _build_all_forms(unit, data, entry=entry)
        if not all(f.is_valid() for f in _flatten_forms(ctx)):
            errors = {"shift": ctx["shift_form"].errors}
            if ctx.get("gcc_color_forms"):
                errors["colors"] = {r["color"]: r["form"].errors for r in ctx["gcc_color_forms"]}
            if ctx.get("rows"):
                errors["rows"] = [r["form"].errors for r in ctx["rows"]]
            if ctx.get("bulk_form"):
                errors["bulk_log"] = ctx["bulk_form"].errors
            if ctx.get("dcp"):
                for k, f in ctx["dcp"].items():
                    errors[k] = f.errors
            if ctx.get("pa_table"):
                errors["packing"] = ctx["pa_table"].errors or ctx["sa_table"].errors
            return Response({"detail": "بيانات غير صحيحة.", "errors": errors}, status=400)

        try:
            with transaction.atomic():
                snapshot = snapshot_entry(entry)
                ctx["shift_form"].save()
                _save_related(entry, data)
                EntryRevision.objects.create(
                    shift_entry=entry,
                    edited_by=request.user,
                    data=snapshot,
                )
        except ValidationError as exc:
            return Response({"detail": exc.message}, status=400)

        return Response(
            {"id": entry.pk, "shift": entry.shift, "entry_date": str(entry.entry_date)},
            status=200,
        )

    def delete(self, request, pk):
        entry, can_edit = self._get_entry(request, pk)
        if entry is None:
            return Response({"detail": "غير موجود."}, status=404)
        if not can_edit:
            return Response({"detail": "لا تملك صلاحية حذف هذا الإدخال."}, status=403)
        entry.delete()
        return Response(status=204)


class EntriesListAPIView(APIView):
    """GET /api/entries/ — سجل الإدخالات بنفس فلاتر صفحة records الويب:
    unit / from / to + صفحة اختيارية (page, page_size)."""

    permission_classes = [IsAuthenticated]

    def get(self, request):
        u = request.user
        qs = ShiftEntry.objects.select_related("submitted_by")
        if not u.is_manager:
            qs = qs.filter(unit=u.assigned_unit)
        unit = request.query_params.get("unit") or ""
        date_from = request.query_params.get("from") or ""
        date_to = request.query_params.get("to") or ""
        if unit:
            qs = qs.filter(unit=unit)
        try:
            if date_from:
                qs = qs.filter(entry_date__gte=date_from)
            if date_to:
                qs = qs.filter(entry_date__lte=date_to)
        except (ValueError, ValidationError):
            date_from = date_to = ""
        qs = qs.order_by("-entry_date", "shift", "-pk")

        page = request.query_params.get("page")
        page_size = int(request.query_params.get("page_size", "50"))
        total = qs.count()
        if page:
            start = (int(page) - 1) * page_size
            rows = qs[start:start + page_size]
        else:
            rows = qs[:page_size]

        return Response(
            {
                "total": total,
                "entries": [
                    {
                        "id": e.pk,
                        "entry_date": e.entry_date.isoformat(),
                        "shift": e.shift,
                        "shift_label": e.get_shift_display(),
                        "unit": e.unit,
                        "unit_label": unit_label(e.unit),
                        "submitted_by": e.submitted_by.get_full_name() or e.submitted_by.username,
                        "can_edit": u.is_manager or e.submitted_by == u,
                    }
                    for e in rows
                ],
            }
        )


class DailyReportAPIView(APIView):
    """GET /api/reports/daily/<date>/ -> نفس بيانات التقرير اليومي كـ JSON."""

    permission_classes = [IsAuthenticated]

    def get(self, request, date):
        if not request.user.is_manager:
            return Response({"detail": "التقرير اليومي متاح للمدير فقط."}, status=403)
        report = full_daily_report(date)
        return Response(_deep_jsonable(report))
