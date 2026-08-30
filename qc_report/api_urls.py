from django.urls import path
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView

from . import api_views

urlpatterns = [
    # ---- Auth ----
    path("token/", TokenObtainPairView.as_view(), name="api_token_obtain"),
    path("token/refresh/", TokenRefreshView.as_view(), name="api_token_refresh"),
    # ---- User / units ----
    path("me/", api_views.MeAPIView.as_view(), name="api_me"),
    path("units/", api_views.UnitsAPIView.as_view(), name="api_units"),
    path("entry-status/<str:unit>/", api_views.EntryStatusAPIView.as_view(), name="api_entry_status"),
    # ---- Entry creation (unit-type specific) ----
    path("entries/sop/<str:unit>/", api_views.SOPEntryCreateAPIView.as_view(), name="api_entry_sop"),
    path("entries/gcc/<str:unit>/", api_views.GCCEntryCreateAPIView.as_view(), name="api_entry_gcc"),
    path("entries/loading/", api_views.LoadingEntryCreateAPIView.as_view(), name="api_entry_loading"),
    path("entries/dcp/", api_views.DCPEntryCreateAPIView.as_view(), name="api_entry_dcp"),
    path("entries/packing/<str:unit>/", api_views.PackingEntryCreateAPIView.as_view(), name="api_entry_packing"),
    # ---- Lookup endpoints for dynamic dropdowns ----
    path("dcp-reasons/", api_views.DCPReasonsAPIView.as_view(), name="api_dcp_reasons"),
    path("packing-types/<str:factory>/", api_views.PackingTypesAPIView.as_view(), name="api_packing_types"),
    # ---- Entry detail (generic, any unit) + قائمة السجل ----
    path("entries/", api_views.EntriesListAPIView.as_view(), name="api_entries"),
    path("entries/<int:pk>/", api_views.EntryDetailAPIView.as_view(), name="api_entry_detail"),
    # ---- Reports ----
    path("reports/daily/<date:date>/", api_views.DailyReportAPIView.as_view(), name="api_report_daily"),
    path("reports/shift/<date:date>/<str:shift>/", api_views.ShiftReportAPIView.as_view(), name="api_report_shift"),
]
