import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/entries_repository.dart';
import '../theme.dart';
import '../widgets/app_scaffold.dart';

/// سجل التعديلات لبيان إدخال: يعرض نسخ ما قبل كل تعديل (جداول كاملة)
/// بنفس شكل صفحة الويب entry_history.html.
class EntryHistoryScreen extends StatefulWidget {
  final int id;
  final String unitLabel;
  const EntryHistoryScreen({super.key, required this.id, this.unitLabel = ""});

  @override
  State<EntryHistoryScreen> createState() => _EntryHistoryScreenState();
}

class _EntryHistoryScreenState extends State<EntryHistoryScreen> {
  final _entries = EntriesRepository();
  Map<String, dynamic>? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await _entries.entryHistory(widget.id);
      if (!mounted) return;
      setState(() => _data = d);
    } catch (e) {
      setState(() => _error = ApiClient.extractErrorFromException(e));
    }
  }

  Widget _table(String title, Map<String, dynamic> sec) {
    final headers = (sec["header"] as List?)?.cast<String>() ?? [];
    final rows = (sec["rows"] as List?) ?? [];
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Table(
              border: TableBorder.all(color: AppColors.border),
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  decoration: const BoxDecoration(color: AppColors.primarySoft),
                  children: [
                    for (final h in headers)
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        child: Text(h,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryStrong)),
                      ),
                  ],
                ),
                for (final row in rows)
                  TableRow(
                    children: [
                      for (final cell in row as List)
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          child: Text("$cell"),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _revisionCard(Map<String, dynamic> rev, int number) {
    final sections = (rev["sections"] as List? ?? const []);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text("نسخة قبل التعديل #$number",
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryStrong)),
                ),
                Text(
                  "بواسطة: ${rev["edited_by"]} | ${_fmtTime(rev["edited_at"])}",
                  textAlign: TextAlign.left,
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if ("${rev["notes"] ?? ""}".isNotEmpty) ...[
                  const Text("ملاحظات عامة",
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text("${rev["notes"]}"),
                ],
                for (final sec in sections)
                  _table(
                      "${(sec as Map)["title"]}", Map<String, dynamic>.from(sec)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmtTime(String raw) {
    if (raw.isEmpty) return "—";
    return raw.replaceFirst("T", " ").replaceFirst(RegExp(r"\.\d+"), "");
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    return AppScaffold(
      title: d == null ? "سجل التعديلات" : "سجل التعديلات — ${d["unit_label"]}",
      body: _error != null
          ? Center(
              child: Text(_error!,
                  style: const TextStyle(color: AppColors.danger)))
          : d == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("الوحدة: ${d["unit_label"]}",
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text("التاريخ: ${d["entry_date"]}"),
                            const SizedBox(height: 2),
                            Text("الوردية: ${d["shift_label"]}"),
                          ],
                        ),
                      ),
                    ),
                    if ((d["history"] as List? ?? const []).isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text("لا توجد تعديلات على هذا الإدخال."),
                        ),
                      )
                    else
                      for (var i = 0; i < (d["history"] as List).length; i++)
                        _revisionCard(
                          Map<String, dynamic>.from(
                              (d["history"] as List)[i] as Map),
                          (d["history"] as List).length - i,
                        ),
                  ],
                ),
    );
  }
}