from django.contrib import admin
from django.urls import include, path, register_converter

from qc_report.converters import DateConverter

register_converter(DateConverter, "date")

urlpatterns = [
    path("admin/", admin.site.urls),
    path("accounts/", include("django.contrib.auth.urls")),
    path("", include("qc_report.urls")),
]
