from django.contrib import admin

from .models import (
    BulkLog,
    DCPASRow,
    DCPBBRow,
    DCPReason,
    DCPTests,
    DCPSBRow,
    GCCLineItem,
    LoadingLineItem,
    PALineItem,
    SALineItem,
    ShiftEntry,
    SOPLineItem,
    User,
)


@admin.register(User)
class UserAdmin(admin.ModelAdmin):
    list_display = ("username", "first_name", "assigned_unit", "is_staff", "is_active")
    list_filter = ("assigned_unit", "is_staff", "is_active")
    search_fields = ("username", "first_name", "last_name")
    fieldsets = (
        (None, {"fields": ("username", "password")}),
        ("معلومات شخصية", {"fields": ("first_name", "last_name", "email")}),
        (
            "الصلاحيات",
            {
                "fields": (
                    "is_active",
                    "is_staff",
                    "is_superuser",
                    "groups",
                    "user_permissions",
                )
            },
        ),
        ("الوحدة", {"fields": ("assigned_unit",)}),
        ("تواريخ مهمة", {"fields": ("last_login", "date_joined")}),
    )


class SOPLineItemInline(admin.TabularInline):
    model = SOPLineItem
    extra = 0


class BulkLogInline(admin.StackedInline):
    model = BulkLog
    extra = 0
    max_num = 1


class DCPBBRowInline(admin.StackedInline):
    model = DCPBBRow
    extra = 0
    max_num = 1


class DCPSBRowInline(admin.StackedInline):
    model = DCPSBRow
    extra = 0
    max_num = 1


class DCPASRowInline(admin.StackedInline):
    model = DCPASRow
    extra = 0
    max_num = 1


class DCPTestsInline(admin.StackedInline):
    model = DCPTests
    extra = 0
    max_num = 1


@admin.register(DCPReason)
class DCPReasonAdmin(admin.ModelAdmin):
    list_display = ("name", "category", "order", "is_active")
    list_filter = ("category", "is_active")
    list_editable = ("order", "is_active")


class PALineItemInline(admin.TabularInline):
    model = PALineItem
    extra = 0


class SALineItemInline(admin.TabularInline):
    model = SALineItem
    extra = 0


class GCCLineItemInline(admin.TabularInline):
    model = GCCLineItem
    extra = 0


class LoadingLineItemInline(admin.TabularInline):
    model = LoadingLineItem
    extra = 0


@admin.register(ShiftEntry)
class ShiftEntryAdmin(admin.ModelAdmin):
    list_display = ("unit", "entry_date", "shift", "submitted_by", "submitted_at")
    list_filter = ("unit", "shift", "entry_date")
    search_fields = ("submitted_by__username",)
    date_hierarchy = "entry_date"

    def get_inlines(self, request, obj):
        if obj is None:
            return []
        unit = obj.unit
        if unit in ("SOP_A", "SOP_B", "SOP_C", "SOP_D", "G_SOP", "C_PACKING"):
            inlines = [SOPLineItemInline]
            if unit in ("SOP_A", "SOP_B", "SOP_C", "SOP_D"):
                inlines.append(BulkLogInline)
            return inlines
        if unit == "DCP":
            return [
                DCPBBRowInline,
                DCPSBRowInline,
                DCPASRowInline,
                DCPTestsInline,
            ]
        if unit == "PA":
            return [PALineItemInline]
        if unit == "SA":
            return [SALineItemInline]
        if unit in ("GCC1", "GCC2"):
            return [GCCLineItemInline]
        if unit == "LOADING":
            return [LoadingLineItemInline]
        return []


admin.site.site_header = "QC Report - الإدارة"
admin.site.site_title = "QC Report"
admin.site.index_title = "إدارة تقرير مراقبة الجودة"
