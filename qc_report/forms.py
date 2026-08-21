from django import forms

from .models import (
    DCPColorGrading,
    DCPRework,
    DCPSummary,
    DCPUnderTest,
    DCPWhiteQuality,
    GCCLineItem,
    LoadingLineItem,
    PALineItem,
    SALineItem,
    ShiftEntry,
    SOPLineItem,
)

DECIMAL_ATTRS = {"type": "number", "step": "0.01", "min": "0", "class": "form-control form-control-sm num-input"}
INTEGER_ATTRS = {"type": "number", "step": "1", "min": "0", "class": "form-control form-control-sm num-input"}


class ShiftEntryForm(forms.ModelForm):
    class Meta:
        model = ShiftEntry
        fields = ["entry_date", "shift", "general_notes"]
        widgets = {
            "entry_date": forms.DateInput(attrs={"type": "date", "class": "form-control"}),
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
        fields = ["exp", "dom", "std", "nc", "defect_reason", "notes", "car_number", "car_weight"]
        widgets = {
            "notes": forms.Textarea(attrs={"rows": 1, "class": "form-control form-control-sm"}),
            "defect_reason": forms.TextInput(
                attrs={"class": "form-control form-control-sm"}
            ),
        }


class DCPSummaryForm(ZeroDefaultMixin, forms.ModelForm):
    zero_fields = (
        "bb_total",
        "as_sb_total",
        "total_1",
        "total_2",
        "lab_test_count",
        "yesterday_test_count",
        "unlabeled_value",
    )

    class Meta:
        model = DCPSummary
        fields = [
            "bb_total",
            "as_sb_total",
            "total_1",
            "total_2",
            "lab_test_count",
            "yesterday_test_count",
            "unlabeled_value",
        ]


class DCPColorGradingForm(ZeroDefaultMixin, forms.ModelForm):
    zero_fields = ("green", "yellow", "green_yellow", "blue", "white", "red")

    class Meta:
        model = DCPColorGrading
        fields = ["green", "yellow", "green_yellow", "blue", "white", "red"]


class DCPUnderTestForm(ZeroDefaultMixin, forms.ModelForm):
    zero_fields = ("quantity",)

    class Meta:
        model = DCPUnderTest
        fields = ["quantity"]


class DCPWhiteQualityForm(ZeroDefaultMixin, forms.ModelForm):
    zero_fields = ("im", "over", "color", "p2o5", "mc", "nc_count")

    class Meta:
        model = DCPWhiteQuality
        fields = ["im", "over", "color", "p2o5", "mc", "nc_count"]


class DCPReworkForm(ZeroDefaultMixin, forms.ModelForm):
    zero_fields = ("total", "green_yellow", "yellow", "green")

    class Meta:
        model = DCPRework
        fields = ["total", "green_yellow", "yellow", "green"]


class PALineItemForm(ZeroDefaultMixin, forms.ModelForm):
    zero_fields = ("jc_43", "jc_62", "cube_43", "cube_61")

    class Meta:
        model = PALineItem
        fields = ["jc_43", "jc_62", "cube_43", "cube_61"]


class SALineItemForm(ZeroDefaultMixin, forms.ModelForm):
    zero_fields = ("jc",)

    class Meta:
        model = SALineItem
        fields = ["jc"]


class GCCLineItemForm(ZeroDefaultMixin, forms.ModelForm):
    zero_fields = ("green", "yellow", "white", "blue", "nc")

    class Meta:
        model = GCCLineItem
        fields = ["green", "yellow", "white", "blue", "nc", "defect_reason", "notes"]
        widgets = {
            "notes": forms.Textarea(attrs={"rows": 1, "class": "form-control form-control-sm"}),
            "defect_reason": forms.TextInput(
                attrs={"class": "form-control form-control-sm"}
            ),
        }


class LoadingLineItemForm(ZeroDefaultMixin, forms.ModelForm):
    zero_fields = ("exp", "dom")

    class Meta:
        model = LoadingLineItem
        fields = ["exp", "dom"]
