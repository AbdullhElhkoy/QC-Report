from django.urls import path

from . import views
from .converters import DateConverter

urlpatterns = [
    path("", views.dashboard, name="dashboard"),
    path("entry/<str:unit>/", views.entry_new, name="entry_new"),
    path("entry/<str:unit>/done/<int:pk>/", views.entry_done, name="entry_done"),
    path(
        "entry/<str:unit>/<date:entry_date>/<str:shift>/edit/",
        views.entry_edit,
        name="entry_edit",
    ),
    path("report/", views.daily_report, name="report_today"),
    path("report/<date:date>/", views.daily_report, name="report"),
    path("report/pdf/", views.daily_report_pdf, name="report_pdf_today"),
    path("report/pdf/<date:date>/", views.daily_report_pdf, name="report_pdf"),
    path("records/", views.records_list, name="records"),
    path("records/export/", views.records_export, name="records_export"),
    path("records/<int:pk>/", views.record_detail, name="record_detail"),
]
