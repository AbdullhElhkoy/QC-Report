from django import forms

from .models import (
    BulkLog,
    DCPASRow,
    DCPBBRow,
    DCPReason,
    DCPReasonLine,
    DCPTests,
    DCPSBRow,
    GCCColorRow,
    GCCSummary,
    LoadingLineItem,
    PackingType,
    ShiftEntry,
    SOPLineItem,
)

DECIMAL_ATTRS = {"type": "number", "step": "0.01", "min": "0", "class": "form-control form-control-sm num-input"}
INTEGER_ATTRS = {"type": "number", "step": "1", "min": "0", "class": "form-control form-control-sm num-input"}


class ShiftEntryForm(forms.ModelForm):
    class Meta:
        model = ShiftEntry
        fields = ["general_notes"]
        widgets = {
            "general_notes": forms.Textarea(attrs={"rows": 2, "class": "form-control"}),
        }


def _number_field(form, name):
    field = form.fields[name]
    if isinstance(field, forms.DecimalField):
        field.widget.attrs.update(DECIMAL_ATTRS)
    else:
        field.widget.attrs.update(INTEGER_ATTRS)


class ZeroDefaultMixin:
    zero_fields = ()

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        for name in self.zero_fields:
            if name in self.fields:
                self.fields[name].required = False
                _number_field(self, name)

    def clean(self):
        cleaned = super().clean()
        for name in self.zero_fields:
            if cleaned.get(name) is None:
                cleaned[name] = 0
        return cleaned


class SOPLineItemForm(ZeroDefaultMixin, forms.ModelForm):
    zero_fields = ("exp", "dom", "std", "nc", "car_number", "car_weight")

    class Meta:
        model = SOPLineItem
        fields = [
            "exp", "dom", "std", "nc",
            "cause", "note",
            "defect_reason", "notes", "car_number", "car_weight",
        ]
        widgets = {
            "notes": forms.Textarea(attrs={"rows": 1, "class": "form-control form-control-sm"}),
            "defect_reason": forms.TextInput(
                attrs={"class": "form-control form-control-sm"}
            ),
            "cause": forms.TextInput(attrs={"class": "form-control form-control-sm"}),
            "note": forms.TextInput(attrs={"class": "form-control form-control-sm"}),
        }


class BulkLogForm(forms.ModelForm):
    class Meta:
        model = BulkLog
        fields = ["exp_trucks", "dom_trucks", "std_trucks", "nc_trucks"]
        widgets = {
            f: forms.NumberInput(
                attrs={"class": "form-control form-control-sm bulk-count", "min": 0, "data-col": f.replace("_trucks", "")}
            )
            for f in ("exp_trucks", "dom_trucks", "std_trucks", "nc_trucks")
        }


class DCPBBRowForm(ZeroDefaultMixin, forms.ModelForm):
    zero_fields = ("green", "yellow", "green_yellow", "blue", "white", "red")

    class Meta:
        model = DCPBBRow
        fields = ["green", "yellow", "green_yellow", "blue", "white", "red", "note"]
        widgets = {
            "note": forms.TextInput(attrs={"class": "form-control form-control-sm"}),
        }


class DCPSBRowForm(ZeroDefaultMixin, forms.ModelForm):
    zero_fields = ("exp", "dom", "sb_white")

    class Meta:
        model = DCPSBRow
        fields = ["exp", "dom", "sb_white", "note"]
        widgets = {
            "note": forms.TextInput(attrs={"class": "form-control form-control-sm"}),
        }


class DCPASRowForm(ZeroDefaultMixin, forms.ModelForm):
    zero_fields = ("exp", "dom", "sb_white")

    class Meta:
        model = DCPASRow
        fields = ["exp", "dom", "sb_white", "note"]
        widgets = {
            "note": forms.TextInput(attrs={"class": "form-control form-control-sm"}),
        }


class DCPTestsForm(ZeroDefaultMixin, forms.ModelForm):
    zero_fields = ("lab_test", "floor_test")

    class Meta:
        model = DCPTests
        fields = ["lab_test", "floor_test"]


def build_dcp_reason_line_form(category, data=None, prefix=""):
    """فورم سطر سبب مع قائمة منسدلة من إعدادات الأسباب حسب النوع."""
    form = DCPReasonLineForm(data, prefix=prefix)
    qs = DCPReason.objects.filter(category=category, is_active=True)
    form.fields["reason"].queryset = qs
    return form


class DCPReasonLineForm(forms.ModelForm):
    class Meta:
        model = DCPReasonLine
        fields = ["reason", "qty"]
        widgets = {
            "qty": forms.NumberInput(
                attrs={
                    "type": "number",
                    "min": 0,
                    "class": "form-control form-control-sm reason-qty",
                }
            )
        }


class PackingTableForm(forms.Form):
    """جدول ديناميكي لأنواع التعبئة — الحقول بتتبني حسب الأنواع المسجلة في الإعدادات.

    بيتبنى لوحدة معينة (PA أو SA): خانة تحت كل نوع تعبئة، افتراضيها صفر.
    """

    def __init__(self, factory, data=None, entry=None, prefix="pack"):
        super().__init__(data=data, prefix=prefix)
        self.factory = factory
        self.types = list(
            PackingType.objects.filter(factory=factory, is_active=True).order_by(
                "order", "id"
            )
        )
        saved = {}
        if entry is not None:
            saved = {
                li.packing_type_id: li.value
                for li in entry.packing_items.filter(packing_type__factory=factory)
            }
        for t in self.types:
            self.fields[f"type_{t.pk}"] = forms.DecimalField(
                required=False,
                min_value=0,
                max_digits=10,
                decimal_places=2,
                initial=saved.get(t.pk),
                label=t.name,
                widget=forms.NumberInput(
                    attrs={
                        "type": "number",
                        "step": "any",
                        "min": "0",
                        "class": "form-control form-control-sm text-center pack-input",
                    }
                ),
            )

    def clean(self):
        cleaned = super().clean()
        for name, value in list(cleaned.items()):
            if value is None:
                cleaned[name] = 0
        return cleaned


class GCCSummaryForm(ZeroDefaultMixin, forms.ModelForm):
    zero_fields = ("sb", "nc")

    class Meta:
        model = GCCSummary
        fields = ["sb", "nc"]
        widgets = {
            "sb": forms.NumberInput(
                attrs={"type": "number", "step": "any", "min": "0",
                       "class": "form-control form-control-sm text-center gcc-sb"}
            ),
            "nc": forms.NumberInput(
                attrs={"type": "number", "step": "any", "min": "0",
                       "class": "form-control form-control-sm text-center"}
            ),
        }


def gcc_color_form(color, data=None, entry=None):
    """فورم صف لون واحد لجدول GCC."""
    instance = None
    if entry is not None:
        instance = entry.gcc_rows.filter(color=color).first()
    form = GCCColorRowForm(data, instance=instance, prefix=f"gcc_{color.lower()}")
    return form


class GCCColorRowForm(ZeroDefaultMixin, forms.ModelForm):
    zero_fields = ("bb",)

    class Meta:
        model = GCCColorRow
        fields = ["bb", "defect_reason", "note"]
        widgets = {
            "bb": forms.NumberInput(
                attrs={"type": "number", "step": "1", "min": "0",
                       "class": "form-control form-control-sm text-center gcc-bb"}
            ),
            "defect_reason": forms.TextInput(
                attrs={"class": "form-control form-control-sm"}
            ),
            "note": forms.TextInput(attrs={"class": "form-control form-control-sm"}),
        }


class LoadingLineItemForm(ZeroDefaultMixin, forms.ModelForm):
    zero_fields = ("exp", "dom")

    class Meta:
        model = LoadingLineItem
        fields = ["exp", "dom"]
