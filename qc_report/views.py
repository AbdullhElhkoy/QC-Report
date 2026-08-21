from decimal import Decimal

from django.conf import settings
from django.contrib import messages
from django.contrib.auth.decorators import login_required
from django.core.exceptions import ValidationError
from django.db import IntegrityError, transaction
from django.core.paginator import Paginator
from django.http import Http404, HttpResponse
from django.shortcuts import get_object_or_404, redirect, render
from django.template.loader import render_to_string
from django.utils import timezone

from .aggregations import full_daily_report
from .pdf_charts import generate_report_charts
from .forms import (
    DCPColorGradingForm,
    DCPReworkForm,
    DCPSummaryForm,
    DCPUnderTestForm,
    DCPWhiteQualityForm,
    GCCLineItemForm,
    LoadingLineItemForm,
    PALineItemForm,
    SALineItemForm,
    ShiftEntryForm,
    SOPLineItemForm,
)
from .models import (
    ColorGradingCategory,
    DCPColorGrading,
    DCPRework,
    DCPSummary,
    DCPUnderTest,
    DCPWhiteQuality,
    GCCLineItem,
    LoadingLineItem,
    LoadingProductType,
    PALineItem,
    PackageType,
    ProductType,
    SALineItem,
    Shift,
    ShiftEntry,
    SOPLineItem,
    SOP_PRODUCT_TYPES,
    Unit,
)

ZERO = Decimal("0")

# تسلسل الورديات المتكرر خلال اليوم: أول إدخال = الأولى، تاني = الثانية، تالت = الثالثة
SHIFT_SEQUENCE = [Shift.SHIFT_1, Shift.SHIFT_2, Shift.SHIFT_3]


def next_shift_for(unit, entry_date):
    """يرجّع أول وردية متاحة بالترتيب (1 ثم 2 ثم 3) لوحد معين في يوم معين،
    أو None لو الورديات الثلاثة اتسجلت بالفعل."""
    taken = set(
        ShiftEntry.objects.filter(unit=unit, entry_date=entry_date).values_list(
            "shift", flat=True
        )
    )
    for s in SHIFT_SEQUENCE:
        if s not in taken:
            return s
    return None


def header_context(request, unit, entry=None):
    """بيانات الهيدر الجاهزة تلقائياً: المستخدم، التاريخ، الوحدة، الوردية."""
    if entry is not None:
        return {
            "header_user": entry.submitted_by.get_full_name()
            or entry.submitted_by.username,
            "header_date": entry.entry_date,
            "header_shift": entry.get_shift_display(),
        }
    return {
        "header_user": request.user.get_full_name() or request.user.username,
        "header_date": timezone.localdate(),
        "header_shift_label": dict(Shift.choices)[next_shift_for(unit, timezone.localdate())]
        if next_shift_for(unit, timezone.localdate())
        else None,
    }

SOP_UNIT_TEMPLATES = {
    "SOP_A": "entry_sop.html",
    "SOP_B": "entry_sop.html",
    "SOP_C": "entry_sop.html",
    "SOP_D": "entry_sop.html",
    "G_SOP": "entry_sop.html",
    "C_PACKING": "entry_sop.html",
}


def unit_label(unit):
    return dict(ShiftEntry._meta.get_field("unit").choices)[unit]


def get_unit_or_404(unit):
    if unit not in Unit.values:
        raise Http404
    return unit


def user_can_access_unit(user, unit):
    return user.is_manager or user.assigned_unit == unit


def _first(queryset):
    return queryset.first()


def build_sop_rows(unit, data=None, entry=None):
    rows = []
    for pt in SOP_PRODUCT_TYPES[unit]:
        instance = None
        if entry is not None:
            instance = entry.sop_line_items.filter(product_type=pt).first()
        form = SOPLineItemForm(data, instance=instance, prefix=f"row_{pt}")
        show_car = pt == ProductType.BULK
        rows.append({"form": form, "label": ProductType(pt).label, "show_car": show_car})
    return rows


def save_sop_rows(entry, data):
    for pt in SOP_PRODUCT_TYPES[entry.unit]:
        form = SOPLineItemForm(data, prefix=f"row_{pt}")
        if form.is_valid():
            obj = form.save(commit=False)
            obj.shift_entry = entry
            obj.product_type = pt
            obj.save()


def build_gcc_rows(data=None, entry=None):
    rows = []
    for pt in PackageType:
        instance = None
        if entry is not None:
            instance = entry.gcc_line_items.filter(package_type=pt).first()
        form = GCCLineItemForm(data, instance=instance, prefix=f"row_{pt}")
        rows.append({"form": form, "label": PackageType(pt).label})
    return rows


def save_gcc_rows(entry, data):
    for pt in PackageType:
        form = GCCLineItemForm(data, prefix=f"row_{pt}")
        if form.is_valid():
            obj = form.save(commit=False)
            obj.shift_entry = entry
            obj.package_type = pt
            obj.save()


def build_loading_rows(data=None, entry=None):
    rows = []
    for pt in LoadingProductType:
        instance = None
        if entry is not None:
            instance = entry.loading_line_items.filter(product_type=pt).first()
        form = LoadingLineItemForm(data, instance=instance, prefix=f"row_{pt}")
        rows.append({"form": form, "label": LoadingProductType(pt).label})
    return rows


def save_loading_rows(entry, data):
    for pt in LoadingProductType:
        form = LoadingLineItemForm(data, prefix=f"row_{pt}")
        if form.is_valid():
            obj = form.save(commit=False)
            obj.shift_entry = entry
            obj.product_type = pt
            obj.save()


def build_dcp_forms(data=None, entry=None):
    def single(form_class, related_name, prefix):
        instance = getattr(entry, related_name, None) if entry is not None else None
        return form_class(data, instance=instance, prefix=prefix)

    grading_rows = []
    for cat in ColorGradingCategory:
        instance = None
        if entry is not None:
            instance = entry.dcp_color_gradings.filter(category=cat).first()
        grading_rows.append(
            {
                "form": DCPColorGradingForm(data, instance=instance, prefix=f"grade_{cat}"),
                "label": ColorGradingCategory(cat).label,
            }
        )
    return {
        "summary": single(DCPSummaryForm, "dcp_summary", "summary"),
        "grading_rows": grading_rows,
        "under_test": single(DCPUnderTestForm, "dcp_under_test", "under_test"),
        "white_quality": single(DCPWhiteQualityForm, "dcp_white_quality", "white_quality"),
        "rework": single(DCPReworkForm, "dcp_rework", "rework"),
    }


def save_dcp_forms(entry, data):
    summary = DCPSummaryForm(
        data, instance=getattr(entry, "dcp_summary", None), prefix="summary"
    )
    if summary.is_valid():
        obj = summary.save(commit=False)
        obj.shift_entry = entry
        obj.save()
    for cat in ColorGradingCategory:
        existing = entry.dcp_color_gradings.filter(category=cat).first()
        form = DCPColorGradingForm(data, instance=existing, prefix=f"grade_{cat}")
        if form.is_valid():
            obj = form.save(commit=False)
            obj.shift_entry = entry
            obj.category = cat
            obj.save()
    under_test = DCPUnderTestForm(
        data, instance=getattr(entry, "dcp_under_test", None), prefix="under_test"
    )
    if under_test.is_valid():
        obj = under_test.save(commit=False)
        obj.shift_entry = entry
        obj.save()
    white_quality = DCPWhiteQualityForm(
        data, instance=getattr(entry, "dcp_white_quality", None), prefix="white_quality"
    )
    if white_quality.is_valid():
        obj = white_quality.save(commit=False)
        obj.shift_entry = entry
        obj.save()
    rework = DCPReworkForm(
        data, instance=getattr(entry, "dcp_rework", None), prefix="rework"
    )
    if rework.is_valid():
        obj = rework.save(commit=False)
        obj.shift_entry = entry
        obj.save()


def all_row_forms_valid(forms_iterable):
    return all(f.is_valid() for f in forms_iterable)


@login_required
def dashboard(request):
    today = timezone.localdate()
    context = {"today": today}
    if request.user.is_manager:
        context["units"] = [
            {"value": u, "label": label}
            for u, label in ShiftEntry._meta.get_field("unit").choices
        ]
        context["is_manager"] = True
    else:
        unit = request.user.assigned_unit
        context["unit"] = unit
        context["unit_label"] = unit_label(unit)
        context["entries_today"] = ShiftEntry.objects.filter(unit=unit, entry_date=today)
        context["is_manager"] = False
    return render(request, "dashboard.html", context)


def _entry_template(unit):
    if unit in SOP_UNIT_TEMPLATES:
        return SOP_UNIT_TEMPLATES[unit]
    templates = {
        "DCP": "entry_dcp.html",
        "PA": "entry_pa.html",
        "SA": "entry_sa.html",
        "GCC1": "entry_gcc.html",
        "GCC2": "entry_gcc.html",
        "LOADING": "entry_loading.html",
    }
    return templates[unit]


def _build_all_forms(unit, data=None, entry=None):
    ctx = {
        "shift_form": ShiftEntryForm(data, instance=entry),
        "rows": [],
        "dcp": None,
        "pa_form": None,
        "sa_form": None,
    }
    if unit in SOP_UNIT_TEMPLATES:
        ctx["rows"] = build_sop_rows(unit, data, entry)
    elif unit in ("GCC1", "GCC2"):
        ctx["rows"] = build_gcc_rows(data, entry)
    elif unit == "LOADING":
        ctx["rows"] = build_loading_rows(data, entry)
    elif unit == "DCP":
        ctx["dcp"] = build_dcp_forms(data, entry)
    elif unit == "PA":
        instance = _first(entry.pa_line_items.all()) if entry is not None else None
        ctx["pa_form"] = PALineItemForm(data, instance=instance, prefix="pa")
    elif unit == "SA":
        instance = _first(entry.sa_line_items.all()) if entry is not None else None
        ctx["sa_form"] = SALineItemForm(data, instance=instance, prefix="sa")
    return ctx


def _flatten_forms(ctx):
    forms = [ctx["shift_form"]]
    forms.extend(r["form"] for r in ctx["rows"])
    if ctx["dcp"]:
        d = ctx["dcp"]
        forms.append(d["summary"])
        forms.extend(r["form"] for r in d["grading_rows"])
        forms.append(d["under_test"])
        forms.append(d["white_quality"])
        forms.append(d["rework"])
    if ctx["pa_form"]:
        forms.append(ctx["pa_form"])
    if ctx["sa_form"]:
        forms.append(ctx["sa_form"])
    return forms


def _save_related(entry, data):
    unit = entry.unit
    if unit in SOP_UNIT_TEMPLATES:
        save_sop_rows(entry, data)
    elif unit in ("GCC1", "GCC2"):
        save_gcc_rows(entry, data)
    elif unit == "LOADING":
        save_loading_rows(entry, data)
    elif unit == "DCP":
        save_dcp_forms(entry, data)
    elif unit == "PA":
        form = PALineItemForm(
            data, instance=entry.pa_line_items.first(), prefix="pa"
        )
        if form.is_valid():
            obj = form.save(commit=False)
            obj.shift_entry = entry
            obj.save()
    elif unit == "SA":
        form = SALineItemForm(
            data, instance=entry.sa_line_items.first(), prefix="sa"
        )
        if form.is_valid():
            obj = form.save(commit=False)
            obj.shift_entry = entry
            obj.save()


@login_required
def entry_new(request, unit):
    get_unit_or_404(unit)
    if not user_can_access_unit(request.user, unit):
        messages.error(request, "لا تملك صلاحية إدخال بيانات لهذه الوحدة.")
        return redirect("dashboard")

    today = timezone.localdate()

    # الوردية بتتحدد أوتوماتيك بالتسلسل: لو الورديات الثلاثة خلصت نمنع إدخال جديد
    next_shift = next_shift_for(unit, today)
    if next_shift is None:
        messages.info(
            request,
            f"تم تسجيل ورديات اليوم الثلاثة لوحدة {unit_label(unit)} بالفعل. "
            "لتعديل بيانات استخدم زر تعديل من لوحة التحكم.",
        )
        return redirect("dashboard")

    if request.method == "POST":
        ctx = _build_all_forms(unit, data=request.POST)
        shift_form = ctx["shift_form"]
        if all_row_forms_valid(_flatten_forms(ctx)):
            try:
                with transaction.atomic():
                    entry = shift_form.save(commit=False)
                    entry.unit = unit
                    entry.submitted_by = request.user
                    # التاريخ والوردية يتحسموا على السيرفر مش من المستخدم
                    entry.entry_date = today
                    entry.shift = next_shift
                    entry.full_clean()
                    entry.save()
                    _save_related(entry, request.POST)
                return redirect("entry_done", unit=unit, pk=entry.pk)
            except (IntegrityError, ValidationError):
                shift_form.add_error(
                    None,
                    "تم إدخال هذه الوردية بالفعل لهذا اليوم والوحدة. عدّل الإدخال الموجود.",
                )
                messages.warning(request, "هذا الإدخال موجود بالفعل.")
    else:
        ctx = _build_all_forms(unit)

    entries_today = ShiftEntry.objects.filter(unit=unit, entry_date=today)
    existing_shifts = {e.shift: e for e in entries_today}
    return render(
        request,
        _entry_template(unit),
        {
            "unit": unit,
            "unit_label": unit_label(unit),
            "today": today,
            "entries_today": entries_today,
            "existing_shifts": existing_shifts,
            **header_context(request, unit),
            **ctx,
        },
    )


@login_required
def entry_edit(request, unit, entry_date, shift):
    get_unit_or_404(unit)
    entry = get_object_or_404(
        ShiftEntry, unit=unit, entry_date=entry_date, shift=shift
    )
    if not (request.user.is_manager or entry.submitted_by == request.user):
        messages.error(request, "لا تملك صلاحية تعديل هذا الإدخال.")
        return redirect("dashboard")

    if request.method == "POST":
        ctx = _build_all_forms(unit, data=request.POST, entry=entry)
        if all_row_forms_valid(_flatten_forms(ctx)):
            try:
                with transaction.atomic():
                    ctx["shift_form"].save()
                    _save_related(entry, request.POST)
                messages.success(request, "تم تعديل الإدخال بنجاح.")
                return redirect("entry_done", unit=unit, pk=entry.pk)
            except (IntegrityError, ValidationError):
                ctx["shift_form"].add_error(
                    None,
                    "يوجد إدخال آخر لنفس الوحدة والتاريخ والوردية.",
                )
    else:
        ctx = _build_all_forms(unit, entry=entry)

    return render(
        request,
        _entry_template(unit),
        {
            "unit": unit,
            "unit_label": unit_label(unit),
            "editing": True,
            "entry": entry,
            "today": timezone.localdate(),
            **header_context(request, unit, entry=entry),
            **ctx,
        },
    )


def entry_summary_context(entry):
    ctx = {}
    unit = entry.unit
    if unit in SOP_UNIT_TEMPLATES:
        items = entry.sop_line_items.all()
        ctx["sop_items"] = items
        ctx["sop_total"] = sum((i.total for i in items), ZERO)
    elif unit == "DCP":
        ctx["dcp_summary"] = getattr(entry, "dcp_summary", None)
        ctx["gradings"] = entry.dcp_color_gradings.all()
        ctx["under_test"] = getattr(entry, "dcp_under_test", None)
        ctx["white_quality"] = getattr(entry, "dcp_white_quality", None)
        ctx["rework"] = getattr(entry, "dcp_rework", None)
    elif unit == "PA":
        ctx["pa_items"] = entry.pa_line_items.all()
    elif unit == "SA":
        ctx["sa_items"] = entry.sa_line_items.all()
    elif unit in ("GCC1", "GCC2"):
        ctx["gcc_items"] = entry.gcc_line_items.all()
    elif unit == "LOADING":
        ctx["loading_items"] = entry.loading_line_items.all()
    return ctx


@login_required
def entry_done(request, unit, pk):
    get_unit_or_404(unit)
    entry = get_object_or_404(ShiftEntry, pk=pk, unit=unit)
    can_edit = request.user.is_manager or entry.submitted_by == request.user
    return render(
        request,
        "confirm.html",
        {
            "entry": entry,
            "unit_label": unit_label(unit),
            "can_edit": can_edit,
            **entry_summary_context(entry),
        },
    )


@login_required
def daily_report(request, date=None):
    if not request.user.is_manager:
        messages.error(request, "التقرير اليومي متاح للمدير فقط.")
        return redirect("dashboard")
    report_date = date or timezone.localdate()
    context = full_daily_report(report_date)
    context["prev_date"] = report_date - timezone.timedelta(days=1)
    context["next_date"] = report_date + timezone.timedelta(days=1)
    context["today"] = timezone.localdate()
    return render(request, "report.html", context)


@login_required
def daily_report_pdf(request, date=None):
    if not request.user.is_manager:
        messages.error(request, "التقرير اليومي متاح للمدير فقط.")
        return redirect("dashboard")
    report_date = date or timezone.localdate()

    # الاستيراد هنا (lazy import) عشان WeasyPrint يحتاج مكتبات نظام (Cairo/Pango)
    # قد لا تكون متاحة في كل بيئة، فمنعزلها عن باقي التطبيق حتى لا يفشل التشغيل كله لو غابت.
    try:
        from weasyprint import HTML
    except (ImportError, OSError):
        messages.error(
            request,
            "خدمة PDF غير متاحة على هذه البيئة. ثبّت weasyprint ومكتبات النظام المطلوبة "
            "(Pango/Cairo) أو استخدم زر الطباعة من المتصفح.",
        )
        return redirect("report", report_date)

    context = full_daily_report(report_date)
    context["charts"] = generate_report_charts(context["charts"])
    context["doc_control"] = settings.QC_REPORT_DOC_CONTROL

    html = render_to_string("report_pdf.html", context, request=request)

    pdf_bytes = HTML(string=html, base_url=request.build_absolute_uri("/")).write_pdf()

    response = HttpResponse(pdf_bytes, content_type="application/pdf")
    filename = f"QC_Report_{report_date.strftime('%d-%m-%Y')}.pdf"
    response["Content-Disposition"] = f'inline; filename="{filename}"'
    return response


def _format_field_value(field, value):
    """تنسيق قيمة حقل للعرض في الجداول: اختيارات بالتسمية، أرقام بدون أصفار زائدة."""
    if value is None or value == "":
        return "—"
    if getattr(field, "choices", None):
        return dict(field.choices).get(value, str(value))
    if isinstance(value, Decimal):
        return f"{value:f}".rstrip("0").rstrip(".") if "." in f"{value:f}" else f"{value:f}"
    return str(value)


def entry_tables(entry):
    """يبني جداول كل بيانات الإدخال تلقائياً من علاقات الموديل،
    فأي حقل جديد يتضافر لموديل يظهر هنا من غير تعديل القالب."""
    sections = []
    for rel in ShiftEntry._meta.related_objects:
        accessor = rel.get_accessor_name()
        if rel.one_to_one:
            obj = getattr(entry, accessor, None)
            instances = [obj] if obj else []
        else:
            instances = list(getattr(entry, accessor).all())
        if not instances:
            continue
        model = rel.related_model
        fields = [
            f
            for f in model._meta.concrete_fields
            if not f.primary_key and f.name != "shift_entry"
        ]
        section = {
            "title": model._meta.verbose_name_plural
            or model._meta.verbose_name
            or model.__name__,
            "headers": [str(f.verbose_name) for f in fields],
            "rows": [
                [_format_field_value(f, getattr(inst, f.name)) for f in fields]
                for inst in instances
            ],
        }
        if len(instances) == 1:
            # لجداول الصف الواحد نجهز أزواج (اسم: قيمة) للعرض المدمج
            row = section["rows"][0]
            section["pairs"] = [
                {"label": h, "value": v} for h, v in zip(section["headers"], row)
            ]
        sections.append(section)
    return sections


@login_required
def records_list(request):
    qs = ShiftEntry.objects.select_related("submitted_by")
    if not request.user.is_manager:
        qs = qs.filter(unit=request.user.assigned_unit)

    unit = request.GET.get("unit") or ""
    date_from = request.GET.get("from") or ""
    date_to = request.GET.get("to") or ""
    if unit:
        qs = qs.filter(unit=unit)
    try:
        if date_from:
            qs = qs.filter(entry_date__gte=date_from)
        if date_to:
            qs = qs.filter(entry_date__lte=date_to)
    except (ValueError, ValidationError):
        messages.error(request, "صيغة التاريخ غير صحيحة.")
        date_from = date_to = ""

    qs = qs.order_by("-entry_date", "shift", "-pk")
    paginator = Paginator(qs, 25)
    page_obj = paginator.get_page(request.GET.get("page"))

    params = request.GET.copy()
    params.pop("page", None)
    querystring = params.urlencode()

    if request.user.is_manager:
        available_units = Unit.choices
    else:
        available_units = [(request.user.assigned_unit, unit_label(request.user.assigned_unit))]

    return render(
        request,
        "records.html",
        {
            "page_obj": page_obj,
            "units": available_units,
            "sel_unit": unit,
            "date_from": date_from,
            "date_to": date_to,
            "querystring": querystring,
            "total": paginator.count,
        },
    )


@login_required
def record_detail(request, pk):
    entry = get_object_or_404(
        ShiftEntry.objects.select_related("submitted_by"), pk=pk
    )
    if not (request.user.is_manager or entry.submitted_by == request.user
            or entry.unit == request.user.assigned_unit):
        messages.error(request, "لا تملك صلاحية عرض هذا الإدخال.")
        return redirect("dashboard")
    can_edit = request.user.is_manager or entry.submitted_by == request.user
    return render(
        request,
        "record_detail.html",
        {
            "entry": entry,
            "unit_label": unit_label(entry.unit),
            "can_edit": can_edit,
            "sections": entry_tables(entry),
        },
    )
