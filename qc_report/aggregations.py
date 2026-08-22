from decimal import Decimal

from django.db.models import Count, Q, Sum

from .models import (
    BulkLog,
    DCPASRow,
    DCPBBRow,
    DCPReasonLine,
    DCPReasonCategory,
    DCPTests,
    DCPSBRow,
    GCCLineItem,
    LoadingLineItem,
    LoadingProductType,
    PALineItem,
    PackageType,
    ProductType,
    SALineItem,
    ShiftEntry,
    SOPLineItem,
    SOP_PRODUCT_TYPES,
    SOP_UNITS,
    Unit,
)

ZERO = Decimal("0")


def _pct(part, whole):
    if not whole:
        return ZERO
    return (Decimal(part) / Decimal(whole)) * 100


def _normalize_range(start, end):
    """تطبيع فترة التجميع: لو مفيش تاريخ نهاية تبقى فترة يوم واحد."""
    return start, end or start


def sop_section(start, end=None):
    start, end = _normalize_range(start, end)
    entries = ShiftEntry.objects.filter(
        unit__in=SOP_UNITS, entry_date__range=(start, end)
    )
    items = SOPLineItem.objects.filter(shift_entry__in=entries)
    rows = []
    for unit in SOP_UNITS:
        unit_items = [i for i in items if i.shift_entry.unit == unit]
        product_rows = []
        unit_total = ZERO
        for pt in SOP_PRODUCT_TYPES[unit]:
            pt_items = [i for i in unit_items if i.product_type == pt]
            exp = sum((i.exp for i in pt_items), ZERO)
            dom = sum((i.dom for i in pt_items), ZERO)
            std = sum((i.std for i in pt_items), ZERO)
            nc = sum((i.nc for i in pt_items), ZERO)
            total = exp + dom + std
            unit_total += total
            # نصوص Cause وNote من كل الأيام داخل الفترة، مدموجة بفاصل &
            texts = [
                t
                for i in pt_items
                for t in (getattr(i, "cause", ""), getattr(i, "note", ""))
                if t
            ]
            product_rows.append(
                {
                    "product_type": ProductType(pt).label,
                    "exp": exp,
                    "dom": dom,
                    "std": std,
                    "nc": nc,
                    "total": total,
                    "texts": " & ".join(texts),
                }
            )
        rows.append(
            {
                "unit": unit,
                "label": dict(ShiftEntry._meta.get_field("unit").choices)[unit],
                "products": product_rows,
                "total": unit_total,
            }
        )
    # SOP UNIT %: تجميع قيم وحدات SOP_A حتى SOP_D فقط + النسبة من الإجمالي
    abcd_units = ["SOP_A", "SOP_B", "SOP_C", "SOP_D"]
    abcd = {"exp": ZERO, "dom": ZERO, "std": ZERO, "nc": ZERO}
    for i in items:
        if i.shift_entry.unit in abcd_units:
            abcd["exp"] += i.exp
            abcd["dom"] += i.dom
            abcd["std"] += i.std
            abcd["nc"] += i.nc
    value_total = sum(abcd.values())
    unit_pct = {
        "values": abcd,
        "value_total": value_total,
        "percents": {
            k: _pct(v, value_total) for k, v in abcd.items()
        },
        "percent_total": Decimal("100"),
    }
    # عربيات BULK: العدد من BulkLog والوزن من بنود BULK نفسها
    bulk_units = [u for u in SOP_UNITS if "BULK" in SOP_PRODUCT_TYPES.get(u, [])]
    bulk_entries = entries.filter(unit__in=bulk_units)
    bulk_counts = BulkLog.objects.filter(shift_entry__in=bulk_entries).aggregate(
        exp=Sum("exp_trucks"),
        dom=Sum("dom_trucks"),
        std=Sum("std_trucks"),
        nc=Sum("nc_trucks"),
    )
    bulk_weights = SOPLineItem.objects.filter(
        shift_entry__in=bulk_entries, product_type=ProductType.BULK
    ).aggregate(exp=Sum("exp"), dom=Sum("dom"), std=Sum("std"), nc=Sum("nc"))
    bulk = {
        "counts": {k: v or 0 for k, v in bulk_counts.items()},
        "weights": {
            k: v if v is not None else ZERO for k, v in bulk_weights.items()
        },
    }
    bulk["count_total"] = sum(bulk["counts"].values())
    bulk["weight_total"] = (
        bulk["weights"]["exp"]
        + bulk["weights"]["dom"]
        + bulk["weights"]["std"]
        + bulk["weights"]["nc"]
    )
    return {
        "rows": rows,
        "unit_pct": unit_pct,
        "bulk": bulk,
    }


def _sum_rows_by_shift(qs, fields):
    """يجمع صفوف الموديل حسب الوردية: 3 صفوف + إجمالي."""
    shifts = {"SHIFT_1": {}, "SHIFT_2": {}, "SHIFT_3": {}}
    totals = {f: 0 for f in fields}
    order = []
    for row in qs.select_related("shift_entry"):
        sh = row.shift_entry.shift
        if sh not in shifts:
            continue
        if sh not in order:
            order.append(sh)
        bucket = shifts[sh]
        for f in fields:
            bucket[f] = bucket.get(f, 0) + getattr(row, f)
            totals[f] += getattr(row, f)
    rows = []
    for sh in ("SHIFT_1", "SHIFT_2", "SHIFT_3"):
        data = {"shift": sh, **{f: shifts[sh].get(f, 0) for f in fields}}
        if any(data[f] for f in fields):
            rows.append(data)
    return rows, totals


def dcp_section(start, end=None):
    start, end = _normalize_range(start, end)
    entries = ShiftEntry.objects.filter(unit="DCP", entry_date__range=(start, end))

    bb_qs = DCPBBRow.objects.filter(shift_entry__in=entries)
    sb_qs = DCPSBRow.objects.filter(shift_entry__in=entries)
    as_qs = DCPASRow.objects.filter(shift_entry__in=entries)

    bb_rows, bb_t = _sum_rows_by_shift(bb_qs, ["green", "yellow", "green_yellow", "blue", "white", "red"])
    sb_rows, sb_t = _sum_rows_by_shift(sb_qs, ["exp", "dom", "sb_white"])
    as_rows, as_t = _sum_rows_by_shift(as_qs, ["exp", "dom", "sb_white"])

    total_exp = bb_t["green"] + bb_t["yellow"] + bb_t["green_yellow"] + bb_t["blue"]
    total_dom = bb_t["white"]
    total_nc = bb_t["red"]
    as_sb_total = as_t["exp"] + as_t["dom"] + as_t["sb_white"]
    sb_total_val = sb_t["exp"] + sb_t["dom"] + sb_t["sb_white"]
    totals = {
        "total_exp": total_exp,
        "total_dom": total_dom,
        "total_nc": total_nc,
        "as_sb": as_sb_total,
        "total": total_exp + total_dom + total_nc + as_sb_total,
        "sb": sb_total_val,
        "total_sb": sb_total_val + as_sb_total,
    }

    # أسباب الأبيض والأحمر مجمعة على الفترة
    def reason_summary(category):
        lines = (
            DCPReasonLine.objects.filter(
                shift_entry__in=entries, reason__category=category
            )
            .values("reason__name", "reason__order")
            .annotate(total=Sum("qty"))
            .order_by("reason__order", "reason__id")
        )
        return [
            {"name": l["reason__name"], "qty": l["total"]} for l in lines
        ]

    white_lines = reason_summary(DCPReasonCategory.WHITE)
    nc_lines = reason_summary(DCPReasonCategory.NC)

    # الاختبارات: اختبار اليوم = وردية 3 من آخر يوم، واختبار امس = وردية 3 من اليوم اللي قبله
    import datetime as _dt

    tests = {"today": 0, "yesterday": 0}

    def shift3_tests(day):
        e = ShiftEntry.objects.filter(
            unit="DCP", entry_date=day, shift="SHIFT_3"
        ).select_related("dcp_tests").first()
        t = getattr(e, "dcp_tests", None)
        return t.total_tests if t else 0

    tests["today"] = shift3_tests(end)
    tests["yesterday"] = shift3_tests(end - _dt.timedelta(days=1))
    period_lab = sum(t.lab_test for t in DCPTests.objects.filter(shift_entry__in=entries))
    period_floor = sum(t.floor_test for t in DCPTests.objects.filter(shift_entry__in=entries))

    notes = list(entries.exclude(general_notes="").values_list("general_notes", flat=True))

    return {
        "bb_rows": bb_rows,
        "bb_total": bb_t,
        "sb_rows": sb_rows,
        "sb_total": sb_t,
        "as_rows": as_rows,
        "as_total": as_t,
        "totals": totals,
        "white_lines": white_lines,
        "nc_lines": nc_lines,
        "tests": tests,
        "period_lab": period_lab,
        "period_floor": period_floor,
        "notes": notes,
    }


def pa_section(start, end=None):
    start, end = _normalize_range(start, end)
    agg = PALineItem.objects.filter(
        shift_entry__unit="PA", shift_entry__entry_date__range=(start, end)
    ).aggregate(
        jc_43=Sum("jc_43"), jc_62=Sum("jc_62"), cube_43=Sum("cube_43"), cube_61=Sum("cube_61")
    )
    values = {k: v or ZERO for k, v in agg.items()}
    values["total"] = values["jc_43"] + values["jc_62"] + values["cube_43"] + values["cube_61"]
    return values


def sa_section(start, end=None):
    start, end = _normalize_range(start, end)
    value = SALineItem.objects.filter(
        shift_entry__unit="SA", shift_entry__entry_date__range=(start, end)
    ).aggregate(jc=Sum("jc"))["jc"] or ZERO
    return {"jc": value}


def gcc_section(start, end=None):
    start, end = _normalize_range(start, end)
    units_data = []
    for unit in ("GCC1", "GCC2"):
        items = GCCLineItem.objects.filter(
            shift_entry__unit=unit, shift_entry__entry_date__range=(start, end)
        )
        package_rows = []
        unit_totals = {"green": 0, "yellow": 0, "white": 0, "blue": 0}
        for pt in PackageType:
            agg = items.filter(package_type=pt).aggregate(
                green=Sum("green"),
                yellow=Sum("yellow"),
                white=Sum("white"),
                blue=Sum("blue"),
                nc=Sum("nc"),
            )
            row = {k: v or 0 for k, v in agg.items()}
            row["package_type"] = pt.label
            row["total"] = row["green"] + row["yellow"] + row["white"] + row["blue"]
            package_rows.append(row)
            for key in unit_totals:
                unit_totals[key] += row[key]
        units_data.append(
            {
                "unit": unit,
                "packages": package_rows,
                "totals": unit_totals,
                "grand_total": sum(unit_totals.values()),
            }
        )
    return units_data


def loading_section(start, end=None):
    start, end = _normalize_range(start, end)
    items = LoadingLineItem.objects.filter(
        shift_entry__unit="LOADING", shift_entry__entry_date__range=(start, end)
    )
    rows = []
    grand = ZERO
    for pt in LoadingProductType:
        agg = items.filter(product_type=pt).aggregate(exp=Sum("exp"), dom=Sum("dom"))
        exp = agg["exp"] or ZERO
        dom = agg["dom"] or ZERO
        total = exp + dom
        grand += total
        rows.append({"product_type": pt.label, "exp": exp, "dom": dom, "total": total})
    return {"rows": rows, "grand_total": grand}


def charts_data(start, end=None):
    start, end = _normalize_range(start, end)
    date_filter = {"shift_entry__entry_date__range": (start, end)}
    sop_qty = (
        SOPLineItem.objects.filter(
            shift_entry__unit__in=["SOP_A", "SOP_B", "SOP_C", "SOP_D"],
            **date_filter,
        ).aggregate(qty=Sum("exp") + Sum("dom") + Sum("std"))["qty"]
        or ZERO
    )
    gsop_qty = (
        SOPLineItem.objects.filter(
            shift_entry__unit="G_SOP", **date_filter
        ).aggregate(qty=Sum("exp") + Sum("dom") + Sum("std"))["qty"]
        or ZERO
    )
    cp_qty = (
        SOPLineItem.objects.filter(
            shift_entry__unit="C_PACKING", **date_filter
        ).aggregate(qty=Sum("exp") + Sum("dom") + Sum("std"))["qty"]
        or ZERO
    )

    def gcc_colors(unit):
        agg = GCCLineItem.objects.filter(
            shift_entry__unit=unit, **date_filter
        ).aggregate(
            green=Sum("green"), yellow=Sum("yellow"), white=Sum("white"), blue=Sum("blue")
        )
        return {k: v or 0 for k, v in agg.items()}

    _dcp_sec = dcp_section(start, end)
    dcp_chart = _dcp_sec["bb_total"]
    loading = loading_section(start, end)
    return {
        "total_qty": {
            "labels": ["Sop", "Gsop", "C.P", "GCC1", "GCC2", "DCP", "PA", "SA"],
            "values": [
                float(sop_qty),
                float(gsop_qty),
                float(cp_qty),
                float(gcc_section(start, end)[0]["grand_total"]),
                float(gcc_section(start, end)[1]["grand_total"]),
                float(_dcp_sec["totals"]["total"]),
                float(pa_section(start, end)["total"]),
                float(sa_section(start, end)["jc"]),
            ],
        },
        "dcp": {
            "labels": ["Green", "Yellow", "G + Y", "Blue", "White", "Red"],
            "values": [
                dcp_chart.get("green", 0),
                dcp_chart.get("yellow", 0),
                dcp_chart.get("green_yellow", 0),
                dcp_chart.get("blue", 0),
                dcp_chart.get("white", 0),
                dcp_chart.get("red", 0),
            ],
        },
        "gcc": {
            "labels": [
                "GCC1 Green",
                "GCC1 Yellow",
                "GCC1 White",
                "GCC1 Blue",
                "GCC2 Green",
                "GCC2 Yellow",
                "GCC2 White",
                "GCC2 Blue",
            ],
            "values": [
                gcc_colors("GCC1")["green"],
                gcc_colors("GCC1")["yellow"],
                gcc_colors("GCC1")["white"],
                gcc_colors("GCC1")["blue"],
                gcc_colors("GCC2")["green"],
                gcc_colors("GCC2")["yellow"],
                gcc_colors("GCC2")["white"],
                gcc_colors("GCC2")["blue"],
            ],
        },
        "loading": {
            "labels": [r["product_type"] for r in loading["rows"]],
            "values": [float(r["total"]) for r in loading["rows"]],
        },
    }


def full_daily_report(date_from, date_to=None):
    """تجميع التقرير على فترة: يوم واحد أو عدة أيام (حتى 3 أيام مثلاً)."""
    start, end = _normalize_range(date_from, date_to)
    return {
        "date": start,
        "date_from": start,
        "date_to": end,
        "period_label": (
            f"{start.strftime('%Y-%m-%d')} — {end.strftime('%Y-%m-%d')}"
            if end != start
            else start.strftime("%Y-%m-%d")
        ),
        "sop": sop_section(start, end),
        "dcp": dcp_section(start, end),
        "pa": pa_section(start, end),
        "sa": sa_section(start, end),
        "gcc": gcc_section(start, end),
        "loading": loading_section(start, end),
        "charts": charts_data(start, end),
    }
