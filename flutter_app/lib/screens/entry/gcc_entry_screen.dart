import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../api/auth_repository.dart';
import '../../api/entries_repository.dart';
import '../../theme.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/number_field.dart';

class GccEntryScreen extends StatefulWidget {
  final String unit; // GCC1 / GCC2
  final int? editId;

  const GccEntryScreen({super.key, required this.unit, this.editId});

  @override
  State<GccEntryScreen> createState() => _GccEntryScreenState();
}

const List<(String, Color)> kGccColors = [
  ("GREEN", Color(0xFFB6D7A8)),
  ("YELLOW", Color(0xFFFFE599)),
  ("BLUE", Color(0xFF9FC5E8)),
  ("WHITE", Colors.white),
];

class _GccEntryScreenState extends State<GccEntryScreen> {
  final _entries = EntriesRepository();
  late final Map<String, NumberField> _bb = {
    for (final c in kGccColors) c.$1: NumberField.zero(label: c.$1)
  };
  final Map<String, TextEditingController> _reasons = {
    for (final c in kGccColors) c.$1: TextEditingController()
  };
  final Map<String, TextEditingController> _notes = {
    for (final c in kGccColors) c.$1: TextEditingController()
  };
  late final NumberField _sb =
      NumberField.zero(label: "SB", allowDecimal: true);
  late final NumberField _nc =
      NumberField.zero(label: "NC", allowDecimal: true);
  String _total = "0";

  bool _loading = true;
  bool _saving = false;
  EntryStatus? _status;
  String? _userName;
  String? _date;
  String? _shiftLabel;
  String? _error;

  bool get _editing => widget.editId != null;

  void _prefill(Map<String, dynamic> vals) {
    final colors = (vals["colors"] as Map? ?? {});
    for (final c in kGccColors) {
      final row = Map<String, dynamic>.from(colors[c.$1] as Map? ?? {});
      _bb[c.$1]!.controller.text = "${row["bb"] ?? 0}";
      _reasons[c.$1]!.text = "${row["defect_reason"] ?? ""}";
      _notes[c.$1]!.text = "${row["note"] ?? ""}";
    }
    _sb.controller.text = "${vals["sb"] ?? 0}";
    _nc.controller.text = "${vals["nc"] ?? 0}";
  }

  @override
  void initState() {
    super.initState();
    _load();
    for (final f in _bb.values) {
      f.controller.addListener(_calc);
    }
    _sb.controller.addListener(_calc);
  }

  void _calc() {
    num t = _sb.value();
    for (final f in _bb.values) {
      t += f.value();
    }
    setState(() => _total =
        (t == t.roundToDouble() ? t.toInt().toString() : t.toStringAsFixed(2)));
  }

  Future<void> _load() async {
    if (widget.editId != null) {
      try {
        final d = await _entries.entryDetail(widget.editId!);
        if (!mounted) return;
        _prefill(Map<String, dynamic>.from(d["values"] as Map? ?? {}));
        setState(() {
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
      ]);
      if (!mounted) return;
      setState(() {
        _status = results[0] as EntryStatus;
        _userName = (results[1] as UserModel).fullName;
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
      final colors = <String, Map<String, dynamic>>{
        for (final c in kGccColors)
          c.$1: {
            "bb": _bb[c.$1]!.value(),
            "defect_reason": _reasons[c.$1]!.text.trim(),
            "note": _notes[c.$1]!.text.trim(),
          }
      };
      if (_editing) {
        await _entries.updateEntry(widget.editId!, {
          "colors": colors,
          "sb": _sb.value(),
          "nc": _nc.value(),
        });
      } else {
        await _entries.createGcc(widget.unit, colors,
            sb: _sb.value(), nc: _nc.value());
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("تم الحفظ ✅")));
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
                        Card(
                          color: const Color(0xFF274E13),
                          child: const Padding(
                            padding: EdgeInsets.all(10),
                            child: Center(
                              child: Text("GCC",
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18)),
                            ),
                          ),
                        ),
                        Table(
                          border: TableBorder.all(color: Colors.grey),
                          defaultVerticalAlignment:
                              TableCellVerticalAlignment.middle,
                          children: [
                            TableRow(
                              decoration:
                                  const BoxDecoration(color: Color(0xFF9FC5E8)),
                              children: const [
                                Padding(padding: EdgeInsets.all(6), child: Text("UNIT", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
                                Padding(padding: EdgeInsets.all(6), child: Text("BB", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
                                Padding(padding: EdgeInsets.all(6), child: Text("SB", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
                                Padding(padding: EdgeInsets.all(6), child: Text("NC", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
                                Padding(padding: EdgeInsets.all(6), child: Text("Defect Reason", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
                                Padding(padding: EdgeInsets.all(6), child: Text("TOTAL", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
                                Padding(padding: EdgeInsets.all(6), child: Text("NOTES", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
                              ],
                            ),
                            for (final c in kGccColors)
                              TableRow(children: [
                                Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: Container(
                                        color: c.$2,
                                        padding: const EdgeInsets.symmetric(vertical: 6),
                                        child: Text(c.$1, textAlign: TextAlign.center))),
                                Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: _bb[c.$1]!),
                                if (c.$1 == "GREEN")
                                  TableCell(
                                      verticalAlignment:
                                          TableCellVerticalAlignment.fill,
                                      child: Padding(
                                          padding: const EdgeInsets.all(4),
                                          child: _sb)),
                                if (c.$1 == "GREEN")
                                  TableCell(
                                      verticalAlignment:
                                          TableCellVerticalAlignment.fill,
                                      child: Padding(
                                          padding: const EdgeInsets.all(4),
                                          child: _nc)),
                                Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: TextField(
                                        controller: _reasons[c.$1])),
                                if (c.$1 == "GREEN")
                                  TableCell(
                                      verticalAlignment:
                                          TableCellVerticalAlignment.fill,
                                      child: Center(
                                          child: Text(_total,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 20,
                                                  color: Colors.blue)))),
                                Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: TextField(controller: _notes[c.$1])),
                              ]),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SaveButton(onPressed: _saving ? null : _save),
                      ],
                    ),
    );
  }
}
