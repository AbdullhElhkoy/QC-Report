# -*- coding: utf-8 -*-
"""بذر أسباب الأبيض والأحمر الافتراضية."""
from django.db import migrations

WHITE = ["Mc", "P2O5", "F", "IM", "OVER", "COLOR"]
NC = ["Mc", "P2O5", "F", "Cl", "IM", "OVER", "COLOR"]


def seed(apps, schema_editor):
    DCPReason = apps.get_model("qc_report", "DCPReason")
    for i, name in enumerate(WHITE):
        DCPReason.objects.get_or_create(
            category="WHITE", name=name, defaults={"order": i}
        )
    for i, name in enumerate(NC):
        DCPReason.objects.get_or_create(
            category="NC", name=name, defaults={"order": i}
        )


def unseed(apps, schema_editor):
    DCPReason = apps.get_model("qc_report", "DCPReason")
    DCPReason.objects.filter(category__in=["WHITE", "NC"]).delete()


class Migration(migrations.Migration):

    dependencies = [
        ("qc_report", "0005_remove_dcprework_shift_entry_and_more"),
    ]

    operations = [
        migrations.RunPython(seed, unseed),
    ]
