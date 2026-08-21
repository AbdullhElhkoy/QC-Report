from decimal import Decimal

from django.db.models import Count, Q, Sum

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
    grand = {"exp": ZERO, "dom": ZERO, "std": ZERO, "nc": ZERO}
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
            if unit != Unit.C_PACKING:
                grand["exp"] += exp
                grand["dom"] += dom
                grand["std"] += std
                grand["nc"] += nc
        rows.append(
            {
                "unit": unit,
                "label": dict(ShiftEntry._meta.get_field("unit").choices)[unit],
                "products": product_rows,
                "total": unit_total,
            }
        )
    grand_total = grand["exp"] + grand["dom"] + grand["std"]
    percentages = {
        "nc": _pct(grand["nc"], grand_total),
        "std": _pct(grand["std"], grand_total),
        "dom": _pct(grand["dom"], grand_total),
        "exp": _pct(grand["exp"], grand_total),
    }
    bulk = [i for i in items if i.product_type == ProductType.BULK]
    car_summary = {
        "car_number_exp": sum(1 for i in bulk if i.car_number is not None and i.exp > 0),
        "car_number_dom": sum(1 for i in bulk if i.car_number is not None and i.dom > 0),
        "car_number_std": sum(1 for i in bulk if i.car_number is not None and i.std > 0),
        "car_number_total": sum(1 for i in bulk if i.car_number is not None),
        "weight_exp": sum((i.car_weight or ZERO for i in bulk if i.exp > 0), ZERO),
        "weight_dom": sum((i.car_weight or ZERO for i in bulk if i.dom > 0), ZERO),
        "weight_std": sum((i.car_weight or ZERO for i in bulk if i.std > 0), ZERO),
        "weight_total": sum((i.car_weight or ZERO for i in bulk), ZERO),
    }
    return {
        "rows": rows,
        "percentages": percentages,
        "grand": grand,
        "grand_total": grand_total,
        "car_summary": car_summary,
    }


def dcp_section(start, end=None):
    start, end = _normalize_range(start, end)
    entries = ShiftEntry.objects.filter(unit="DCP", entry_date__range=(start, end))
    summary = DCPSummary.objects.filter(shift_entry__in=entries).aggregate(
        bb_total=Sum("bb_total"),
        as_sb_total=Sum("as_sb_total"),
        total_1=Sum("total_1"),
        total_2=Sum("total_2"),
        lab_test_count=Sum("lab_test_count"),
        yesterday_test_count=Sum("yesterday_test_count"),
        unlabeled_value=Sum("unlabeled_value"),
    )
    gradings = DCPColorGrading.objects.filter(shift_entry__in=entries)
    categories = []
    for cat in ColorGradingCategory:
        agg = gradings.filter(category=cat).aggregate(
            green=Sum("green"),
            yellow=Sum("yellow"),
            green_yellow=Sum("green_yellow"),
            blue=Sum("blue"),
            white=Sum("white"),
            red=Sum("red"),
        )
        values = {k: v or 0 for k, v in agg.items()}
        values["category"] = cat.label
        values["total"] = (
            values["green"]
            + values["yellow"]
            + values["green_yellow"]
            + values["blue"]
            + values["white"]
            + values["red"]
        )
        categories.append(values)
    under_test = DCPUnderTest.objects.filter(shift_entry__in=entries).aggregate(
        quantity=Sum("quantity")
    )["quantity"] or ZERO
    white_quality = DCPWhiteQuality.objects.filter(shift_entry__in=entries).aggregate(
        im=Sum("im"),
        over=Sum("over"),
        color=Sum("color"),
        p2o5=Sum("p2o5"),
        mc=Sum("mc"),
        nc_count=Sum("nc_count"),
    )
    rework = DCPRework.objects.filter(shift_entry__in=entries).aggregate(
        total=Sum("total"),
        green_yellow=Sum("green_yellow"),
        yellow=Sum("yellow"),
        green=Sum("green"),
    )
    notes = list(
        ShiftEntry.objects.filter(unit="DCP", entry_date__range=(start, end))
        .exclude(general_notes="")
        .values_list("general_notes", flat=True)
    )
    return {
        "summary": {k: v if v is not None else ZERO for k, v in summary.items()},
        "categories": categories,
        "under_test": under_test,
        "white_quality": {k: v if v is not None else ZERO for k, v in white_quality.items()},
        "rework": {k: v if v is not None else ZERO for k, v in rework.items()},
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

    dcp_chart = next(
        (
            c
            for c in dcp_section(start, end)["categories"]
            if c["category"] == ColorGradingCategory.TOTAL.label
        ),
        None,
    )
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
                float(dcp_section(start, end)["summary"]["total_1"]),
                float(pa_section(start, end)["total"]),
                float(sa_section(start, end)["jc"]),
            ],
        },
        "dcp": {
            "labels": ["أخضر", "أصفر", "أخضر وأصفر", "أزرق", "أبيض", "أحمر"],
            "values": [
                dcp_chart["green"],
                dcp_chart["yellow"],
                dcp_chart["green_yellow"],
                dcp_chart["blue"],
                dcp_chart["white"],
                dcp_chart["red"],
            ]
            if dcp_chart
            else [0, 0, 0, 0, 0, 0],
        },
        "gcc": {
            "labels": [
                "GCC1 أخضر",
                "GCC1 أصفر",
                "GCC1 أبيض",
                "GCC1 أزرق",
                "GCC2 أخضر",
                "GCC2 أصفر",
                "GCC2 أبيض",
                "GCC2 أزرق",
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
