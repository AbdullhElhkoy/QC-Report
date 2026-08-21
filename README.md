# QC Report — تقرير مراقبة الجودة

نظام إدخال بيانات وردية وتقارير يومية لمراقبة الجودة (شركة Evergrow للأسمدة).
تطبيق ويب مستقل بالكامل — Django + Bootstrap 5 RTL + Chart.js، يعمل على الموبايل والكمبيوتر من نفس الواجهة.

## الوحدات المدعومة

SOP A / SOP B / SOP C / SOP D / G SOP / C.Packing / DCP / PA / SA / GCC1 / GCC2 / Loading

- كل مستخدم مرتبط بوحدة واحدة فقط (`assigned_unit`) ولا يستطيع فتح غير نموذج وحدته.
- كل وردية (الأولى/الثانية/الثالثة) تدخل بياناتها مرة واحدة لكل يوم لكل وحدة.
- النظام يجمع ورديات اليوم تلقائياً في التقرير اليومي مع 4 رسوم بيانية وزر طباعة/PDF.

## التشغيل محلياً

```bash
python -m venv .venv
# Windows
.venv\Scripts\activate
# Linux/macOS
source .venv/bin/activate

pip install -r requirements.txt
python manage.py migrate
python manage.py createsuperuser
python manage.py runserver
```

ثم افتح <http://127.0.0.1:8000/>

## التشغيل على GitHub Codespaces

1. من صفحة الريبو على GitHub اضغط **Code → Codespaces → Create codespace**.
2. الحاوية ستجهز نفسها تلقائياً (تثبيت المتطلبات + عمل migrations).
3. شغّل السيرفر:

```bash
python manage.py runserver
```

4. المنفذ 8000 سيُفتح تلقائياً في المتصفح.

## PostgreSQL (اختياري)

افتراضياً يستخدم المشروع SQLite. لتشغيله على PostgreSQL عرّف متغيرات البيئة:

```
POSTGRES_HOST=...
POSTGRES_DB=qc_report
POSTGRES_USER=...
POSTGRES_PASSWORD=...
```

وسطب مكتبة التعريف: `pip install psycopg2-binary`

## إنشاء حسابات المشغلين

من Django Admin (`/admin/`) أنشئ مستخدماً جديداً واختر له `الوحدة المسند إليها`.
اتركها فارغة للمديرين (يرون كل الوحدات والتقرير اليومي).

## تصدير PDF

زر **تصدير PDF** في صفحة التقرير اليومي يطلع ملف PDF بنفس تصميم التقرير الأصلي
(هيدر وفوتر ضبط جودة + جداول ملونة + صفحة رسوم بيانية).

- على Linux/Codespaces المكتبات المطلوبة بتتسطب تلقائياً مع الحاوية.
- على Windows محلياً محتاجة GTK Runtime — لو مش متسطب هيظهرلك رسالة وتقدر تستخدم طباعة المتصفح كبديل.

### شعارات التقرير

حط شعارتي الشركة في المجلد `static/qc_report/img/` بالأسماء دي:
`logo_evergrow_ar.png` و `logo_evergrow_en.png` — لو مش موجودة، مساحة الهيدر هتظهر فاضية.

## بنية المشروع

```
qc_project/     إعدادات Django
qc_report/      التطبيق الرئيسي (models, forms, views, aggregations, admin)
templates/      قوالب HTML (عربي RTL)
.devcontainer/  إعداد GitHub Codespaces
```
