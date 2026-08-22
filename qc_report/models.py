from django.conf import settings
from django.contrib.auth.models import AbstractUser
from django.db import models


class Unit(models.TextChoices):
    SOP_A = "SOP_A", "SOP A"
    SOP_B = "SOP_B", "SOP B"
    SOP_C = "SOP_C", "SOP C"
    SOP_D = "SOP_D", "SOP D"
    G_SOP = "G_SOP", "G SOP"
    C_PACKING = "C_PACKING", "C.Packing"
    DCP = "DCP", "DCP"
    PA = "PA", "PA"
    SA = "SA", "SA"
    GCC1 = "GCC1", "GCC1"
    GCC2 = "GCC2", "GCC2"
    LOADING = "LOADING", "Loading"


class Shift(models.TextChoices):
    SHIFT_1 = "SHIFT_1", "الوردية الأولى"
    SHIFT_2 = "SHIFT_2", "الوردية الثانية"
    SHIFT_3 = "SHIFT_3", "الوردية الثالثة"


class ProductType(models.TextChoices):
    S_B = "S_B", "S.B"
    B_B = "B_B", "B.B"
    BULK = "BULK", "BULK"
    O_M = "O_M", "O.M"
    VA = "VA", "VA"


class PackageType(models.TextChoices):
    B_B = "B_B", "B.B"
    S_B = "S_B", "S.B"


class LoadingProductType(models.TextChoices):
    SOP = "SOP", "SOP"
    GSOP = "GSOP", "GSOP"
    GCC = "GCC", "GCC"
    DCP = "DCP", "DCP"
    PA = "PA", "PA"
    SA = "SA", "SA"
    HCL = "HCL", "HCL"


SOP_PRODUCT_TYPES = {
    Unit.SOP_A: [ProductType.S_B, ProductType.B_B, ProductType.BULK],
    Unit.SOP_B: [ProductType.S_B, ProductType.B_B, ProductType.BULK],
    Unit.SOP_C: [ProductType.S_B, ProductType.B_B, ProductType.BULK],
    Unit.SOP_D: [ProductType.S_B, ProductType.B_B, ProductType.BULK],
    Unit.G_SOP: [ProductType.S_B, ProductType.B_B],
    Unit.C_PACKING: [ProductType.O_M, ProductType.VA, ProductType.B_B],
}

SOP_UNITS = [
    Unit.SOP_A,
    Unit.SOP_B,
    Unit.SOP_C,
    Unit.SOP_D,
    Unit.G_SOP,
    Unit.C_PACKING,
]


class User(AbstractUser):
    assigned_unit = models.CharField(
        "الوحدة المسند إليها",
        max_length=20,
        choices=Unit.choices,
        null=True,
        blank=True,
    )

    @property
    def is_manager(self):
        return self.is_staff or self.is_superuser or self.assigned_unit is None


class ShiftEntry(models.Model):
    unit = models.CharField("الوحدة", max_length=20, choices=Unit.choices)
    entry_date = models.DateField("التاريخ")
    shift = models.CharField("الوردية", max_length=10, choices=Shift.choices)
    submitted_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        verbose_name="أدخلها",
        on_delete=models.CASCADE,
        related_name="shift_entries",
    )
    submitted_at = models.DateTimeField("وقت الإدخال", auto_now_add=True)
    general_notes = models.TextField("ملاحظات عامة", blank=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["unit", "entry_date", "shift"],
                name="unique_shift_per_unit_per_day",
            )
        ]
        ordering = ["entry_date", "unit", "shift"]

    def __str__(self):
        return f"{self.get_unit_display()} - {self.entry_date} - {self.get_shift_display()}"


class SOPLineItem(models.Model):
    shift_entry = models.ForeignKey(
        ShiftEntry, on_delete=models.CASCADE, related_name="sop_line_items"
    )
    product_type = models.CharField("نوع المنتج", max_length=10, choices=ProductType.choices)
    exp = models.DecimalField("EXP", max_digits=10, decimal_places=2, default=0)
    dom = models.DecimalField("DOM", max_digits=10, decimal_places=2, default=0)
    std = models.DecimalField("STD", max_digits=10, decimal_places=2, default=0)
    nc = models.DecimalField("NC", max_digits=10, decimal_places=2, default=0)
    cause = models.CharField("Cause", max_length=200, blank=True)
    note = models.CharField("Note", max_length=200, blank=True)
    defect_reason = models.CharField("سبب العيب", max_length=100, blank=True)
    notes = models.TextField("ملاحظات", blank=True)
    car_number = models.PositiveIntegerField("رقم العربية", null=True, blank=True)
    car_weight = models.DecimalField(
        "وزن العربية", max_digits=10, decimal_places=2, null=True, blank=True
    )

    class Meta:
        ordering = ["product_type"]

    @property
    def total(self):
        return self.exp + self.dom + self.std

    def __str__(self):
        return f"{self.shift_entry} - {self.get_product_type_display()}"


class DCPReasonCategory(models.TextChoices):
    WHITE = "WHITE", "DCP White"
    NC = "NC", "DCP NC"


class DCPReason(models.Model):
    """أسباب الأبيض/الأحمر — بتتدار من الإعدادات (Admin)."""

    category = models.CharField("النوع", max_length=10, choices=DCPReasonCategory.choices)
    name = models.CharField("السبب", max_length=50)
    order = models.PositiveIntegerField("الترتيب", default=0)
    is_active = models.BooleanField("مفعل", default=True)

    class Meta:
        ordering = ["category", "order", "id"]
        constraints = [
            models.UniqueConstraint(
                fields=["category", "name"], name="uniq_dcp_reason_per_category"
            )
        ]

    def __str__(self):
        return f"{self.get_category_display()} - {self.name}"


class DCPBBRow(models.Model):
    """جدول B.B رقم 1: عدد الألوان لكل وردية."""

    shift_entry = models.OneToOneField(
        ShiftEntry, on_delete=models.CASCADE, related_name="dcp_bb"
    )
    green = models.PositiveIntegerField("Green", default=0)
    yellow = models.PositiveIntegerField("Yellow", default=0)
    green_yellow = models.PositiveIntegerField("Green & Yellow", default=0)
    blue = models.PositiveIntegerField("Blue", default=0)
    white = models.PositiveIntegerField("White", default=0)
    red = models.PositiveIntegerField("Red", default=0)
    note = models.CharField("Note", max_length=200, blank=True)

    @property
    def total(self):
        return (
            self.green
            + self.yellow
            + self.green_yellow
            + self.blue
            + self.white
            + self.red
        )

    def __str__(self):
        return f"B.B - {self.shift_entry}"


class _DCPSBBase(models.Model):
    shift_entry = models.OneToOneField(
        ShiftEntry, on_delete=models.CASCADE, related_name="+"
    )
    exp = models.DecimalField("EXP", max_digits=10, decimal_places=2, default=0)
    dom = models.DecimalField("DOM", max_digits=10, decimal_places=2, default=0)
    sb_white = models.DecimalField("S.B White", max_digits=10, decimal_places=2, default=0)
    note = models.CharField("Note", max_length=200, blank=True)

    class Meta:
        abstract = True

    @property
    def total(self):
        return self.exp + self.dom + self.sb_white

    def __str__(self):
        return f"{self._meta.object_name} - {self.shift_entry}"


class DCPSBRow(_DCPSBBase):
    """جدول S.B رقم 2."""

    shift_entry = models.OneToOneField(
        ShiftEntry, on_delete=models.CASCADE, related_name="dcp_sb"
    )


class DCPASRow(_DCPSBBase):
    """جدول S.B AS رقم 3."""

    shift_entry = models.OneToOneField(
        ShiftEntry, on_delete=models.CASCADE, related_name="dcp_as"
    )


class DCPReasonLine(models.Model):
    """سطر سبب: الرقم ممكن يتوزع على سبب أو أكتر (White أو NC)."""

    shift_entry = models.ForeignKey(
        ShiftEntry, on_delete=models.CASCADE, related_name="dcp_reason_lines"
    )
    reason = models.ForeignKey(DCPReason, on_delete=models.PROTECT, verbose_name="السبب")
    qty = models.PositiveIntegerField("الرقم", default=0)

    class Meta:
        ordering = ["reason__category", "reason__order", "id"]

    def __str__(self):
        return f"{self.reason.name}: {self.qty} ({self.shift_entry})"


class DCPTests(models.Model):
    """اختبار معمل + اختبار أرضية (والإجمالي بيتحسب)."""

    shift_entry = models.OneToOneField(
        ShiftEntry, on_delete=models.CASCADE, related_name="dcp_tests"
    )
    lab_test = models.PositiveIntegerField("اختبار معمل", default=0)
    floor_test = models.PositiveIntegerField("اختبار أرضية", default=0)

    @property
    def total_tests(self):
        return self.lab_test + self.floor_test

    def __str__(self):
        return f"Tests - {self.shift_entry}"


class PALineItem(models.Model):
    shift_entry = models.ForeignKey(
        ShiftEntry, on_delete=models.CASCADE, related_name="pa_line_items"
    )
    jc_43 = models.DecimalField("JC 43", max_digits=10, decimal_places=2, default=0)
    jc_62 = models.DecimalField("JC 62", max_digits=10, decimal_places=2, default=0)
    cube_43 = models.DecimalField("Cube 43", max_digits=10, decimal_places=2, default=0)
    cube_61 = models.DecimalField("Cube 61", max_digits=10, decimal_places=2, default=0)

    class Meta:
        ordering = ["id"]

    @property
    def total(self):
        return self.jc_43 + self.jc_62 + self.cube_43 + self.cube_61

    def __str__(self):
        return f"PA - {self.shift_entry}"


class SALineItem(models.Model):
    shift_entry = models.ForeignKey(
        ShiftEntry, on_delete=models.CASCADE, related_name="sa_line_items"
    )
    jc = models.DecimalField("JC", max_digits=10, decimal_places=2, default=0)

    class Meta:
        ordering = ["id"]

    def __str__(self):
        return f"SA - {self.shift_entry}"


class GCCLineItem(models.Model):
    shift_entry = models.ForeignKey(
        ShiftEntry, on_delete=models.CASCADE, related_name="gcc_line_items"
    )
    package_type = models.CharField("نوع العبوة", max_length=10, choices=PackageType.choices)
    green = models.PositiveIntegerField("أخضر", default=0)
    yellow = models.PositiveIntegerField("أصفر", default=0)
    white = models.PositiveIntegerField("أبيض", default=0)
    blue = models.PositiveIntegerField("أزرق", default=0)
    nc = models.DecimalField("NC", max_digits=10, decimal_places=2, default=0)
    defect_reason = models.CharField("سبب العيب", max_length=100, blank=True)
    notes = models.TextField("ملاحظات", blank=True)

    class Meta:
        ordering = ["package_type"]

    @property
    def total(self):
        return self.green + self.yellow + self.white + self.blue

    def __str__(self):
        return f"{self.shift_entry} - {self.get_package_type_display()}"


SOP_BULK_UNITS = {"SOP_A", "SOP_B", "SOP_C", "SOP_D"}


class BulkLog(models.Model):
    shift_entry = models.OneToOneField(
        ShiftEntry, on_delete=models.CASCADE, related_name="bulk_log"
    )
    exp_trucks = models.PositiveIntegerField("EXP trucks", null=True, blank=True)
    dom_trucks = models.PositiveIntegerField("DOM trucks", null=True, blank=True)
    std_trucks = models.PositiveIntegerField("STD trucks", null=True, blank=True)
    nc_trucks = models.PositiveIntegerField("NC trucks", null=True, blank=True)

    class Meta:
        verbose_name = "BULK trucks log"

    @property
    def total_trucks(self):
        return sum(
            v
            for v in (self.exp_trucks, self.dom_trucks, self.std_trucks, self.nc_trucks)
            if v
        )

    def __str__(self):
        return f"BULK - {self.shift_entry}"


class LoadingLineItem(models.Model):
    shift_entry = models.ForeignKey(
        ShiftEntry, on_delete=models.CASCADE, related_name="loading_line_items"
    )
    product_type = models.CharField(
        "نوع المنتج", max_length=10, choices=LoadingProductType.choices
    )
    exp = models.DecimalField("EXP", max_digits=10, decimal_places=2, default=0)
    dom = models.DecimalField("DOM", max_digits=10, decimal_places=2, default=0)

    class Meta:
        ordering = ["product_type"]

    @property
    def total(self):
        return self.exp + self.dom

    def __str__(self):
        return f"{self.shift_entry} - {self.get_product_type_display()}"
