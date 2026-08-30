import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/reports_repository.dart';
import '../../main.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/report_tree.dart';

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
                    reportSection("SOP", _report?["sop"]),
                    reportSection("DCP", _report?["dcp"]),
                    reportSection("GCC", _report?["gcc"]),
                    reportSection("Loading", _report?["loading"]),
                  ],
                ),
    );
  }
}