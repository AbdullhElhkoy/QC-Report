import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/reports_repository.dart';
import '../../main.dart';
import '../../widgets/app_scaffold.dart';

/// شاشة التقرير اليومي (مدير فقط): ملخص JSON + تحميل PDF/Excel.
class DailyReportScreen extends StatefulWidget {
  const DailyReportScreen({super.key});

  @override
  State<DailyReportScreen> createState() => _DailyReportScreenState();
}

class _DailyReportScreenState extends State<DailyReportScreen> {
  final _reports = ReportsRepository();
  DateTime _date = DateTime.now();
  Map<String, dynamic>? _report;
  bool _loading = true;
  bool _downloading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rep = await _reports.daily(_date);
      if (!mounted) return;
      setState(() {
        _report = rep;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (d != null) {
      _date = d;
      _load();
    }
  }

  Future<void> _download(Future<void> Function() fn, String okMsg) async {
    setState(() => _downloading = true);
    try {
      await fn();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(okMsg)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: Colors.red, content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  /// هل القيمة "فاضية" فعلاً (عشان نعرض "لا توجد بيانات" لما يستحق الأمر فقط)؟
  bool _isEmptyValue(dynamic value) {
    if (value == null) return true;
    if (value is Map) return value.isEmpty;
    if (value is List) return value.isEmpty;
    if (value is String) return value.isEmpty;
    return false;
  }

  /// صف واحد key: value بسيط، مع إزاحة حسب العمق.
  /// عمود اسم الحقل بعرض ثابت والقيمة جنبه على طول (مش ممدودة لآخر الكارت)
  /// عشان يطلع شكل جدول مضغوط زي المعتاد بدل حقول متناثرة.
  Widget _kvRow(String label, dynamic value, int depth) {
    return Padding(
      padding: EdgeInsets.only(right: depth * 12.0, top: 3, bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label,
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text("$value",
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  /// صندوق فرعي بعنوان وحدود خفيفة، عشان يبقى واضح بصريًا إن دول عناصر
  /// تابعة لبعض (زي products > S.B > product_type/exp/dom...) بدل ما يبانوا
  /// سطور متتالية مالهاش علاقة ببعض.
  Widget _groupBox(String label, List<Widget> children, int depth) {
    return Container(
      margin: EdgeInsets.only(right: depth * 10.0, top: 6, bottom: 2),
      padding: const EdgeInsets.only(right: 10, top: 4, bottom: 4, left: 4),
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: Colors.blueGrey.shade200, width: 2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey.shade700)),
          const SizedBox(height: 2),
          ...children,
        ],
      ),
    );
  }

  /// عرض أي قيمة (scalar / Map / List) بشكل متداخل بدل ما نتجاهلها.
  /// ده الفرق الأساسي عن الكود القديم اللي كان بيفلتر ويشيل أي Map/List،
  /// وده اللي كان بيخلي أغلب أقسام التقرير (sop/dcp/gcc/loading) تظهر فاضية.
  List<Widget> _renderNode(String label, dynamic value, int depth) {
    if (_isEmptyValue(value)) {
      return [_kvRow(label, "—", depth)];
    }

    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      final children = [
        for (final e in map.entries) ..._renderNode(e.key, e.value, 1),
      ];
      return [_groupBox(label, children, depth)];
    }

    if (value is List) {
      if (value.every((e) => e is num || e is String || e is bool)) {
        // قائمة قيم بسيطة: نعرضها في صف واحد مفصولة بفاصلة
        return [_kvRow(label, value.join("، "), depth)];
      }
      // قائمة عناصر مركبة (Map غالبًا): كل عنصر بند مرقّم جوه صندوق فرعي خاص بيه
      final children = <Widget>[];
      for (var i = 0; i < value.length; i++) {
        final item = value[i];
        if (item is Map) {
          final map = Map<String, dynamic>.from(item);
          // لو فيه اسم/تسمية واضحة نستخدمها كعنوان بدل الرقم فقط
          final itemLabel = (map["label"] ?? map["name"] ?? map["product_type"] ?? map["unit"])
                  ?.toString() ??
              "#${i + 1}";
          final itemChildren = [
            for (final e in map.entries)
              if (e.key != "label" && e.key != "name")
                ..._renderNode(e.key, e.value, 1),
          ];
          children.add(_groupBox(itemLabel, itemChildren, 1));
        } else {
          children.add(_kvRow("#${i + 1}", item, 1));
        }
      }
      return [_groupBox(label, children, depth)];
    }

    // قيمة عادية (num/String/bool)
    return [_kvRow(label, value, depth)];
  }

  /// data ممكن تيجي Map (أغلب الأقسام) أو List (زي GCC اللي بيرجع كـ list
  /// من الأساس) - النسختين لازم يتعرضوا كاملين من غير فقد أي بيانات.
  Widget _section(String title, dynamic data) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 6),
            if (_isEmptyValue(data))
              const Text("— لا توجد بيانات —",
                  style: TextStyle(color: Colors.grey))
            else if (data is Map)
              for (final e in Map<String, dynamic>.from(data).entries)
                ..._renderNode(e.key, e.value, 0)
            else if (data is List)
              for (var i = 0; i < data.length; i++)
                ..._renderNode("#${i + 1}", data[i], 0)
            else
              Text("$data"),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: "التقرير اليومي",
      actions: [
        IconButton(icon: const Icon(Icons.calendar_month), onPressed: _pickDate),
      ],
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : ListView(
                  children: [
                    FilledButton.icon(
                      icon: const Icon(Icons.open_in_new),
                      label: const Text("عرض التقرير الكامل (الويب)"),
                      style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52)),
                      onPressed: () {
                        final d = _date;
                        final dateStr =
                            "${d.year.toString().padLeft(4, "0")}-${d.month.toString().padLeft(2, "0")}-${d.day.toString().padLeft(2, "0")}";
                        launchUrl(
                          Uri.parse("$kApiBaseUrl/report/?date=$dateStr"),
                          mode: LaunchMode.externalApplication,
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.picture_as_pdf),
                            label: const Text("تحميل PDF"),
                            onPressed: _downloading
                                ? null
                                : () => _download(
                                    () => _reports.downloadDailyPdf(_date),
                                    "تم تنزيل الـ PDF ✅"),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.table_view),
                            label: const Text("تحميل Excel"),
                            onPressed: _downloading
                                ? null
                                : () => _download(
                                    () => _reports.downloadExcel(
                                        _date, _date, null),
                                    "تم تنزيل الإكسل ✅"),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _section("SOP", _report?["sop"]),
                    _section("DCP", _report?["dcp"]),
                    _section("GCC", _report?["gcc"]),
                    _section("Loading", _report?["loading"]),
                  ],
                ),
    );
  }
}