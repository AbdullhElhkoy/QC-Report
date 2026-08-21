"""
توليد صور الرسوم البيانية (PNG) لاستخدامها داخل تقرير PDF.
WeasyPrint لا يقدر يرندر Chart.js (canvas)، فبنولد الشارتات كصور ثابتة
بنفس الألوان والتنسيق المستخدم في تقرير الإكسل الأصلي.
"""
import base64
from io import BytesIO

import matplotlib

matplotlib.use("Agg")  # بدون واجهة رسومية (سيرفر بدون شاشة)
import matplotlib.pyplot as plt

BAR_BLUE = "#4472C4"
# ملاحظة: التصميم الأصلي بيستخدم تسميات إنجليزية للشارتات (مش عربي)
# عشان مكتبة matplotlib محتاجة إعداد تشكيل عربي (arabic_reshaper + bidi) عشان
# ترندر العربي صح، وده تعقيد إضافي مش له داعي هنا. بنطابق تصميم الأصل مباشرة.
DCP_ORDER = ["Green", "Yellow", "G + Y", "Blue", "White", "Red"]
DCP_COLORS = {
    "Green": "#548235",
    "Yellow": "#FFD700",
    "G + Y": "#8FBC3F",
    "Blue": "#1F4E79",
    "White": "#FFFFFF",
    "Red": "#C00000",
}
GCC_COLORS = {
    "GREEN": "#548235",
    "YELLOW": "#FFD700",
    "WHITE": "#FFFFFF",
    "BLUE": "#1F4E79",
}


def _fig_to_base64(fig):
    buf = BytesIO()
    fig.savefig(buf, format="png", dpi=150, bbox_inches="tight")
    plt.close(fig)
    buf.seek(0)
    return base64.b64encode(buf.read()).decode("ascii")


def _bar_chart(title, labels, values, colors=None, figsize=(6.2, 3.2)):
    fig, ax = plt.subplots(figsize=figsize)
    bar_colors = colors or BAR_BLUE
    bars = ax.bar(labels, values, color=bar_colors, edgecolor="#444", linewidth=0.6)
    ax.set_title(title, fontsize=9, fontweight="bold", pad=4)
    ax.spines[["top", "right"]].set_visible(False)
    ax.grid(axis="y", linestyle="-", linewidth=0.4, alpha=0.4)
    ax.set_axisbelow(True)
    for b in bars:
        height = b.get_height()
        ax.annotate(
            f"{height:g}",
            xy=(b.get_x() + b.get_width() / 2, height),
            xytext=(0, 2),
            textcoords="offset points",
            ha="center",
            fontsize=7,
        )
    plt.xticks(rotation=0, fontsize=7)
    plt.yticks(fontsize=7)
    fig.tight_layout(pad=0.3)
    return _fig_to_base64(fig)


def generate_report_charts(charts_data):
    """
    ياخد نفس الـ dict الراجع من aggregations.charts_data()
    ويرجع dict فيه صور base64 جاهزة للحقن في <img src="data:image/png;base64,...">
    """
    # كل شارت شريط كامل العرض وقصير الارتفاع، عشان الأربعة يتكدسوا في صفحة واحدة
    # (نفس ترتيب التصميم الأصلي: شارت واحد تحت التاني)
    size = (10, 1.5)

    total_qty = _bar_chart(
        "Total QTY For All Product",
        charts_data["total_qty"]["labels"],
        charts_data["total_qty"]["values"],
        figsize=size,
    )

    # ترتيب قيم dcp.categories جاي بنفس ترتيب DCP_ORDER من aggregations
    # (green, yellow, green_yellow, blue, white, red) فبنستخدم تسميات إنجليزية بس
    dcp = _bar_chart(
        "DCP",
        DCP_ORDER,
        charts_data["dcp"]["values"],
        colors=[DCP_COLORS[lbl] for lbl in DCP_ORDER],
        figsize=size,
    )

    gcc_labels = ["GREEN", "YELLOW", "WHITE", "BLUE", "GREEN", "YELLOW", "WHITE", "BLUE"]
    gcc = _bar_chart(
        "GCC1 - GCC2",
        gcc_labels,
        charts_data["gcc"]["values"],
        colors=[GCC_COLORS[lbl] for lbl in gcc_labels],
        figsize=size,
    )

    loading = _bar_chart(
        "LOADING",
        charts_data["loading"]["labels"],
        charts_data["loading"]["values"],
        figsize=size,
    )

    return {
        "total_qty": total_qty,
        "dcp": dcp,
        "gcc": gcc,
        "loading": loading,
    }
