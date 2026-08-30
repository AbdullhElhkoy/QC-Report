import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../api/auth_repository.dart';
import '../../api/entries_repository.dart';
import '../../theme.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/number_field.dart';

/// PA / SA: جدول ديناميكي — الأنواع من الإعدادات، TOTAL حي في الشاشة.
class PackingEntryScreen extends StatefulWidget {
  final String unit; // PA / SA
  final int? editId;

  const PackingEntryScreen({super.key, required this.unit, this.editId});

  @override
  State<PackingEntryScreen> createState() => _PackingEntryScreenState();
}

class _PackingEntryScreenState extends State<PackingEntryScreen> {
  final _entries = EntriesRepository();
  List<(int, String, NumberField)>? _types;
  bool _loading = true;
  bool _saving = false;
  EntryStatus? _status;
  String? _userName;
  String? _date;
  String? _shiftLabel;
  String? _error;

  bool get _editing => widget.editId != null;

  void _prefill(Map<String, dynamic> vals) {
    final saved = Map<String, dynamic>.from(vals["values"] as Map? ?? {});
    for (final t in _types ?? const <(int, String, NumberField)>[]) {
      final v = saved["${t.$1}"];
      if (v != null) {
        final s = "$v".replaceFirst(RegExp(r"\.0+$"), "");
        t.$3.controller.text = s;
      }
    }
  }

  void _recalc() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  num get _total {
    num t = 0;
    for (final (_, _, f) in _types ?? const <(int, String, NumberField)>[]) {
      t += f.value();
    }
    return t;
  }

  Future<void> _load() async {
    if (widget.editId != null) {
      try {
        final d = await _entries.entryDetail(widget.editId!);
        if (!mounted) return;
        final types = await _entries.packingTypes(widget.unit);
        if (!mounted) return;
        setState(() {
          _types = [
            for (final t in types)
              (
                t["id"] as int,
                t["name"] as String,
                NumberField.zero(
                    label: t["name"], allowDecimal: true, onChanged: _recalc)
              )
          ];
          _prefill(Map<String, dynamic>.from(d["values"] as Map? ?? {}));
          _date = d["entry_date"] as String?;
          _shiftLabel = d["shift_label"] as String?;
          _userName = d["submitted_by"] as String?;
          _loading = false;
        });
      } catch (e) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
      return;
    }
    try {
      final results = await Future.wait([
        AuthRepository().entryStatus(widget.unit),
        AuthRepository().me(),
        _entries.packingTypes(widget.unit),
      ]);
      if (!mounted) return;
      setState(() {
        _status = results[0] as EntryStatus;
        _userName = (results[1] as UserModel).fullName;
        _types = [
          for (final t in results[2] as List)
            (
              t["id"] as int,
              t["name"] as String,
              NumberField.zero(
                  label: t["name"], allowDecimal: true, onChanged: _recalc)
            )
        ];
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final values = {
        for (final (id, _, f) in _types!) id.toString(): f.value(),
      };
      if (_editing) {
        await _entries.updateEntry(widget.editId!, {"values": values});
      } else {
        await _entries.createPacking(widget.unit, values);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("تم الحفظ ✅")));
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: AppColors.danger,
          content: Text(ApiClient.extractErrorFromException(e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _headerCell(String label, String value, {bool bold = false}) =>
      Expanded(
        child: Column(
          children: [
            Text(label,
                style:
                    const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            const SizedBox(height: 2),
            Text(value,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
          ],
        ),
      );

  Widget _shiftHeader() {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            _headerCell("الموظف", _userName ?? "-"),
            _headerCell("الوحدة", widget.unit),
            _headerCell("التاريخ", _date ?? _status?.date ?? "-"),
            _headerCell("الوردية", _shiftLabel ?? _status?.shiftLabel ?? "-"),
          ],
        ),
      ),
    );
  }

  Widget _packingTable() {
    final types = _types ?? const <(int, String, NumberField)>[];
    const green = Color(0xFFD9EAD3);
    const greenText = Color(0xFF274E13);

    Widget headCell(String name) => Container(
          constraints: const BoxConstraints(minWidth: 84),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          color: green,
          child: Text(name,
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontWeight: FontWeight.w700, color: greenText)),
        );

    Widget labelCell(String lbl) => Container(
          width: 66,
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          color: const Color(0xFFF3F6F1),
          child: Text(lbl,
              style: const TextStyle(fontWeight: FontWeight.w700)),
        );

    Widget inputCell(NumberField f) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: f,
        );

    Widget totalCell() => Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          child: Text(
            (() {
              final t = _total;
              return t == t.roundToDouble()
                  ? "${t.toInt()}"
                  : t.toStringAsFixed(2);
            })(),
            style: TextStyle(
                fontWeight: FontWeight.w800, color: greenText, fontSize: 18),
          ),
        );

    Widget emptyCell() => Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          color: green,
        );

    final table = Table(
      border: TableBorder.all(color: AppColors.border),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(children: [
          labelCell(widget.unit),
          for (final (_, name, _) in types) headCell(name),
        ]),
        TableRow(children: [
          labelCell(""),
          for (final (_, _, f) in types) inputCell(f),
        ]),
        TableRow(children: [
          labelCell("TOTAL"),
          totalCell(),
          for (var i = 0; i < types.length - 1; i++) emptyCell(),
        ]),
      ],
    );

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: table,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: _editing ? "${widget.unit} — تعديل" : "${widget.unit} — إدخال",
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_status?.allShiftsDoneToday ?? false)
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.task_alt,
                          size: 64, color: AppColors.primary),
                      SizedBox(height: 12),
                      Text("الورديات الثلاثة اتسجلت بالفعل اليوم."),
                    ],
                  ),
                )
              : _error != null
                  ? Center(child: Text(_error!))
                  : ListView(
                      children: [
                        _shiftHeader(),
                        _packingTable(),
                        const SizedBox(height: 12),
                        SaveButton(onPressed: _saving ? null : _save),
                      ],
                    ),
    );
  }
}