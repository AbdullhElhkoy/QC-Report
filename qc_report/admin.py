from django.contrib import admin

from .models import (
    BulkLog,
    DCPASRow,
    DCPBBRow,
    DCPReason,
    DCPTests,
    DCPSBRow,
    EntryRevision,
    GCCLineItem,
    LoadingLineItem,
    PackingLineItem,
    PackingType,
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


@admin.register(PackingType)
class PackingTypeAdmin(admin.ModelAdmin):
    list_display = ("factory", "name", "order", "is_active")
    list_filter = ("factory", "is_active")
    list_editable = ("order", "is_active")


class PackingLineItemInline(admin.TabularInline):
    model = PackingLineItem
    extra = 0


@admin.register(DCPReason)
class DCPReasonAdmin(admin.ModelAdmin):
    list_display = ("name", "category", "order", "is_active")
    list_filter = ("category", "is_active")
    list_editable = ("order", "is_active")


class PALineItemInline(admin.TabularInline):
    model = PackingLineItem
    extra = 0
    verbose_name = "بند PA"


class SALineItemInline(admin.TabularInline):
    model = PackingLineItem
    extra = 0
    verbose_name = "بند SA"


class GCCLineItemInline(admin.TabularInline):
    model = GCCLineItem
    extra = 0


class LoadingLineItemInline(admin.TabularInline):
    model = LoadingLineItem
    extra = 0


class EntryRevisionInline(admin.TabularInline):
    model = EntryRevision
    extra = 0
    max_num = 0
    can_delete = False
    fields = ("edited_by", "edited_at")
    readonly_fields = ("edited_by", "edited_at")
    verbose_name = "سجل تعديل"
    verbose_name_plural = "سجلات التعديل (التفاصيل في صفحة السجل)"


@admin.register(ShiftEntry)
class ShiftEntryAdmin(admin.ModelAdmin):
    list_display = ("unit", "entry_date", "shift", "submitted_by", "submitted_at")
    list_filter = ("unit", "shift", "entry_date")
    search_fields = ("submitted_by__username",)
    date_hierarchy = "entry_date"

    def get_inlines(self, request, obj):
        base = self._unit_inlines(obj)
        if obj is not None and obj.revisions.exists():
            return base + [EntryRevisionInline]
        return base

    def _unit_inlines(self, obj):
        if obj is None:
            return []
        unit = obj.unit
        if unit in ("SOP_A", "SOP_B", "SOP_C", "SOP_D", "G_SOP", "C_PACKING"):
            inlines = [SOPLineItemInline]
            if unit in ("SOP_A", "SOP_B", "SOP_C", "SOP_D"):
                inlines.append(BulkLogInline)
            return inlines
        if unit == "DCP":
            return [DCPBBRowInline, DCPSBRowInline, DCPASRowInline, DCPTestsInline]
        if unit in ("PA", "SA"):
            return [PackingLineItemInline]
        if unit in ("GCC1", "GCC2"):
            return [GCCLineItemInline]
        if unit == "LOADING":
            return [LoadingLineItemInline]
        return []


@admin.register(EntryRevision)
class EntryRevisionAdmin(admin.ModelAdmin):
    list_display = ("shift_entry", "edited_by", "edited_at")
    list_filter = ("shift_entry__unit", "shift_entry__shift")
    search_fields = ("shift_entry__unit",)
    readonly_fields = ("shift_entry", "edited_by", "edited_at", "data")

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False


admin.site.site_header = "QC Report - الإدارة"
admin.site.site_title = "QC Report"
admin.site.index_title = "إدارة تقرير مراقبة الجودة"
