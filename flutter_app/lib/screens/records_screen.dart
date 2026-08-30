import 'package:flutter/material.dart';

import '../api/auth_repository.dart';
import '../api/entries_repository.dart';
import '../theme.dart';
import '../widgets/app_scaffold.dart';
import 'entry/dcp_entry_screen.dart';
import 'entry/gcc_entry_screen.dart';
import 'entry/loading_entry_screen.dart';
import 'entry/packing_entry_screen.dart';
import 'entry/sop_entry_screen.dart';
import 'record_detail_screen.dart';

class RecordRow {
  final int id;
  final String date;
  final String shiftLabel;
  final String unit;
  final String unitLabel;
  final String submittedBy;
  final bool canEdit;
  const RecordRow({
    required this.id,
    required this.date,
    required this.shiftLabel,
    required this.unit,
    required this.unitLabel,
    required this.submittedBy,
    required this.canEdit,
  });
}

Widget openEntryScreen(String unit, String label, {int? editId}) {
  return switch (unit) {
    "DCP" => DcpEntryScreen(editId: editId),
    "PA" || "SA" => PackingEntryScreen(unit: unit, editId: editId),
    "GCC1" || "GCC2" => GccEntryScreen(unit: unit, editId: editId),
    "LOADING" => LoadingEntryScreen(editId: editId),
    _ => SopEntryScreen(unit: unit, unitLabel: label, editId: editId),
  };
}

class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key});

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  final _entries = EntriesRepository();
  List<RecordRow>? _rows;
  int _total = 0;
  String? _error;
  String _selUnit = "";
  String _from = "";
  String _to = "";
  List<UnitItem> _units = const [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      _units = await AuthRepository().units();
    } catch (_) {}
    await _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final data = await _entries.listEntries(
          unit: _selUnit, from: _from, to: _to);
      if (!mounted) return;
      setState(() {
        _rows = [
          for (final e in data["entries"] as List)
            RecordRow(
              id: e["id"],
              date: e["entry_date"],
              shiftLabel: e["shift_label"],
              unit: e["unit"],
              unitLabel: e["unit_label"],
              submittedBy: e["submitted_by"],
              canEdit: e["can_edit"] ?? false,
            ),
        ];
        _total = data["total"] ?? 0;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _pickDate({required bool from}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(from ? _from : _to) ?? now,
      firstDate: DateTime(2023),
      lastDate: now,
    );
    if (picked == null) return;
    final iso = picked.toIso8601String().substring(0, 10);
    setState(() {
      if (from) {
        _from = iso;
      } else {
        _to = iso;
      }
    });
    await _refresh();
  }

  Future<void> _delete(RecordRow r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("حذف الإدخال؟"),
        content: Text(
            "سيتم حذف إدخال ${r.unitLabel} ليوم ${r.date} (${r.shiftLabel}) نهائيًا."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("إلغاء")),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("حذف"),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _entries.deleteEntry(r.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("تم الحذف ✅")));
    await _refresh();
  }

  void _open(BuildContext context, RecordRow r, {bool edit = false}) {
    Widget screen;
    if (edit) {
      screen = openEntryScreen(r.unit, r.unitLabel, editId: r.id);
    } else {
      screen = RecordDetailScreen(id: r.id);
    }
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => screen))
        .then((_) => _refresh());
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: "سجل الإدخالات",
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text("سجل الإدخالات ($_total)",
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _selUnit.isEmpty ? null : _selUnit,
                    decoration: const InputDecoration(
                        labelText: "الوحدة",
                        isDense: true,
                        border: OutlineInputBorder()),
                    items: [
                      const DropdownMenuItem(value: "", child: Text("كل الوحدات")),
                      for (final u in _units)
                        DropdownMenuItem(value: u.value, child: Text(u.label)),
                    ],
                    onChanged: (v) {
                      _selUnit = v ?? "";
                      _refresh();
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _pickDate(from: true),
                          child: Text(_from.isEmpty ? "من تاريخ" : "من $_from"),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _pickDate(from: false),
                          child: Text(_to.isEmpty ? "إلى تاريخ" : "إلى $_to"),
                        ),
                      ),
                    ],
                  ),
                  if (_from.isNotEmpty || _to.isNotEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () {
                          setState(() {
                            _from = "";
                            _to = "";
                          });
                          _refresh();
                        },
                        child: const Text("مسح الفلتر"),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                  child: Text(_error!, style: const TextStyle(color: AppColors.danger))),
            )
          else if (_rows?.isEmpty ?? true)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                  child: Text("لا توجد إدخالات مطابقة.",
                      style: TextStyle(color: AppColors.textMuted))),
            )
          else
            for (final r in _rows!)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                                "${r.unitLabel} — ${r.shiftLabel}",
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 15)),
                          ),
                          Text(r.date,
                              style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontFamily: "monospace")),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(r.submittedBy,
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 13)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.visibility_outlined,
                                  size: 18),
                              label: const Text("عرض"),
                              onPressed: () => _open(context, r),
                            ),
                          ),
                          if (r.canEdit) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                label: const Text("تعديل"),
                                onPressed: () => _open(context, r, edit: true),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.danger,
                                ),
                                icon: const Icon(Icons.delete_outline, size: 18),
                                label: const Text("حذف"),
                                onPressed: () => _delete(r),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}