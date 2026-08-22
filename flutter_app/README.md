# QC Report — Flutter Client

تطبيق موبايل + ويب + ويندوز لمشروع QC-Report (Django/DRF backend).

## التشغيل

1. شغّل الباك إند:
   ```
   python manage.py runserver
   ```

2. حدد عنوان الـ API وقت البناء:

   ```bash
   cd flutter_app
   flutter pub get

   # ويب
   flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000

   # ويندوز
   flutter run -d windows --dart-define=API_BASE_URL=http://127.0.0.1:8000

   # أندرويد (جهاز على نفس الشبكة — استخدم IP الجهاز مش localhost)
   flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000
   ```

## المميزات
- تسجيل دخول JWT مع تخزين آمن للتوكن + تجديد تلقائي عند انتهائه
- فورمات إدخال لكل الوحدات: SOP×6 / GCC1-2 / DCP / PA / SA / Loading
- الوردية المتاحة بتتحدد تلقائيًا، ولما الثلاثة يخلصوا بيرفض الإدخال
- الحقول الرقمية بتبدأ بصفر زي منطق السيرفر بالظبط
- رسائل أخطاء السيرفر بتظهر للمستخدم كما هي
- التقرير اليومي (للمدير) + تحميل PDF/Excel
- RTL كامل بالعربي
