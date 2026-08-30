import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/entries_repository.dart';
import '../theme.dart';
import '../widgets/app_scaffold.dart';
import 'records_screen.dart';

/// عرض تفاصيل إدخال (قراءة فقط) — نفس شاشة الويب record_detail.html.
class RecordDetailScreen extends StatefulWidget {
  final int id;
  const RecordDetailScreen({super.key, required this.id});

  @override
  State<RecordDetailScreen> createState() => _RecordDetailScreenState();
}

class _RecordDetailScreenState extends State<RecordDetailScreen> {
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
      final d = await _entries.entryDetail(widget.id);
      if (!mounted) return;
      setState(() => _data = d);
    } catch (e) {
      setState(() => _error = ApiClient.extractErrorFromException(e));
    }
  }

  Widget _infoCell(String label, String value) => Expanded(
        child: Column(
          children: [
            Text(label,
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 12)),
            const SizedBox(height: 2),
            Text(value,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      );

  Widget _sectionCard(Map<String, dynamic> sec) {
    final title = sec["title"] as String? ?? "";
    final headers = (sec["headers"] as List?)?.cast<String>() ?? [];
    final rows = (sec["rows"] as List?) ?? [];
    final pairs = (sec["pairs"] as List?)?.cast<Map<String, dynamic>>();
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 8),
            if (pairs != null && pairs.isNotEmpty)
              for (final p in pairs)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 130,
                        child: Text("${p["label"]}",
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMuted)),
                      ),
                      Expanded(child: Text("${p["value"]}")),
                    ],
                  ),
                )
            else ...[
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
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
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
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              child: Text("$cell"),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    return AppScaffold(
      title: d == null ? "التفاصيل" : "${d["unit_label"]} — عرض",
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
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 4),
                        child: Row(
                          children: [
                            _infoCell("الوحدة", "${d["unit_label"]}"),
                            _infoCell("التاريخ", "${d["entry_date"]}"),
                            _infoCell("الوردية", "${d["shift_label"]}"),
                            _infoCell("أدخلها", "${d["submitted_by"]}"),
                          ],
                        ),
                      ),
                    ),
                    if ("${d["general_notes"] ?? ""}".isNotEmpty)
                      Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("ملاحظات عامة",
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 4),
                              Text("${d["general_notes"]}"),
                            ],
                          ),
                        ),
                      ),
                    for (final sec in (d["sections"] as List? ?? const []))
                      _sectionCard(Map<String, dynamic>.from(sec as Map)),
                    const SizedBox(height: 4),
                    if (d["can_edit"] == true)
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              icon: const Icon(Icons.edit_outlined),
                              label: const Text("تعديل"),
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => openEntryScreen(
                                        "${d["unit"]}", "${d["unit_label"]}",
                                        editId: widget.id),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
    );
  }
}