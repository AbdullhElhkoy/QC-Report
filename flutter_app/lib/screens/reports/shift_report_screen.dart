import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/reports_repository.dart';
import '../../main.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/report_tree.dart';

/// شاشة تقرير الوردية (مدير فقط): تقرير وردية واحدة لكل المصانع،
/// مع اختيار التاريخ والوردية والتنقل يوم قبل/بعد زي الويب.
class ShiftReportScreen extends StatefulWidget {
  const ShiftReportScreen({super.key});

  @override
  State<ShiftReportScreen> createState() => _ShiftReportScreenState();
}

class _ShiftReportScreenState extends State<ShiftReportScreen> {
  static const _shiftCodes = ["SHIFT_1", "SHIFT_2", "SHIFT_3"];
  static const _shiftLabels = ["الوردية الأولى", "الوردية الثانية", "الوردية الثالثة"];

  final _reports = ReportsRepository();
  DateTime _date = DateTime.now();
  int _shiftIndex = 0;
  Map<String, dynamic>? _report;
  bool _loading = true;
  String? _error;

  String get _shiftCode => _shiftCodes[_shiftIndex];

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
      final rep = await _reports.shiftReport(_date, _shiftCode);
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

  void _changeDay(int delta) {
    setState(() => _date = _date.add(Duration(days: delta)));
    _load();
  }

  void _openWeb() {
    final d = _date;
    final dateStr =
        "${d.year.toString().padLeft(4, "0")}-${d.month.toString().padLeft(2, "0")}-${d.day.toString().padLeft(2, "0")}";
    launchUrl(
      Uri.parse("$kApiBaseUrl/report/$dateStr/shift/$_shiftCode/"),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: "تقرير الوردية",
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_month, size: 18),
                    label: Text(_fmt(_date)),
                    onPressed: _pickDate,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _shiftIndex,
                    decoration: const InputDecoration(
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (var i = 0; i < _shiftLabels.length; i++)
                        DropdownMenuItem(value: i, child: Text(_shiftLabels[i])),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _shiftIndex = v);
                      _load();
                    },
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                OutlinedButton(
                  onPressed: () => _changeDay(-1),
                  child: const Text("اليوم السابق"),
                ),
                const Spacer(),
                OutlinedButton(
                  onPressed: () => _changeDay(1),
                  child: const Text("اليوم التالي"),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton.icon(
                                    icon: const Icon(Icons.open_in_new),
                                    label: const Text("عرض التقرير الكامل (الويب)"),
                                    style: FilledButton.styleFrom(
                                        minimumSize: const Size.fromHeight(46)),
                                    onPressed: _openWeb,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  children: [
                                    Text(
                                      "تقرير وردية لكل المصانع",
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _report?["period_label"]?.toString() ?? "",
                                      style: const TextStyle(
                                          color: Colors.black54),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            reportSection("SOP", _report?["sop"]),
                            reportSection("DCP", _report?["dcp"]),
                            reportSection("PA", _report?["pa"]),
                            reportSection("SA", _report?["sa"]),
                            reportSection("GCC", _report?["gcc"]),
                            reportSection("Loading", _report?["loading"]),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime d) =>
      "${d.year.toString().padLeft(4, "0")}-"
      "${d.month.toString().padLeft(2, "0")}-${d.day.toString().padLeft(2, "0")}";
}