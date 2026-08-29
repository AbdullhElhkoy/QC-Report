import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../api/auth_repository.dart';
import '../../api/entries_repository.dart';
import '../../theme.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/number_field.dart';

class _ReasonPick {
  final int id;
  final String name;
  final TextEditingController qty = TextEditingController(text: "0");
  _ReasonPick({required this.id, required this.name});
}

class DcpEntryScreen extends StatefulWidget {
  const DcpEntryScreen({super.key});

  @override
  State<DcpEntryScreen> createState() => _DcpEntryScreenState();
}

class _DcpEntryScreenState extends State<DcpEntryScreen> {
  final _entries = EntriesRepository();

  late final Map<String, NumberField> _bb = {
    "green": NumberField.zero(label: "Green", onChanged: _recalc),
    "yellow": NumberField.zero(label: "Yellow", onChanged: _recalc),
    "green_yellow": NumberField.zero(label: "G & Y", onChanged: _recalc),
    "blue": NumberField.zero(label: "Blue", onChanged: _recalc),
    "white": NumberField.zero(label: "White", onChanged: _recalc),
    "red": NumberField.zero(label: "Red", onChanged: _recalc),
  };
  final _bbNote = TextEditingController();
  late final Map<String, NumberField> _sb = {
    "exp": NumberField.zero(label: "EXP", onChanged: _recalc),
    "dom": NumberField.zero(label: "DOM", onChanged: _recalc),
    "sb_white": NumberField.zero(label: "S.B White", onChanged: _recalc),
  };
  final _sbNote = TextEditingController();
  late final Map<String, NumberField> _asRow = {
    "exp": NumberField.zero(label: "EXP", onChanged: _recalc),
    "dom": NumberField.zero(label: "DOM", onChanged: _recalc),
    "sb_white": NumberField.zero(label: "S.B White", onChanged: _recalc),
  };
  final _asNote = TextEditingController();
  late final Map<String, NumberField> _tests = {
    "lab_test": NumberField.zero(label: "Lab Test", onChanged: _recalc),
    "floor_test": NumberField.zero(label: "Floor Test", onChanged: _recalc),
  };

  List<_ReasonPick>? _whiteReasons;
  List<_ReasonPick>? _ncReasons;
  bool _loading = true;
  bool _saving = false;
  EntryStatus? _status;
  String? _userName;
  String? _error;

  num get _totalExp =>
      _bb["green"]!.value() +
      _bb["yellow"]!.value() +
      _bb["green_yellow"]!.value() +
      _bb["blue"]!.value();
  num get _totalDom => _bb["white"]!.value();
  num get _totalNc => _bb["red"]!.value();
  num get _asTotal => _asRow["exp"]!.value() +
      _asRow["dom"]!.value() +
      _asRow["sb_white"]!.value();
  num get _sbTotal =>
      _sb["exp"]!.value() + _sb["dom"]!.value() + _sb["sb_white"]!.value();
  num get _testTotal =>
      _tests["lab_test"]!.value() + _tests["floor_test"]!.value();

  void _recalc() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        AuthRepository().entryStatus("DCP"),
        AuthRepository().me(),
        _entries.dcpReasons("white"),
        _entries.dcpReasons("nc"),
      ]);
      if (!mounted) return;
      setState(() {
        _status = results[0] as EntryStatus;
        _userName = (results[1] as UserModel).fullName;
        _whiteReasons = [
          for (final r in results[2] as List) _ReasonPick(id: r["id"], name: r["name"])
        ];
        _ncReasons = [
          for (final r in results[3] as List) _ReasonPick(id: r["id"], name: r["name"])
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

  num _sumReasons(List<_ReasonPick>? picks) {
    var total = 0.0;
    for (final r in (picks ?? const <_ReasonPick>[])) {
      total += (num.tryParse(r.qty.text.trim()) ?? 0).toDouble();
    }
    return total;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _entries.createDcp(
        bb: ({for (final e in _bb.entries) e.key: e.value.value()})
          ..["note"] = _bbNote.text.trim(),
        sb: ({for (final e in _sb.entries) e.key: e.value.value()})
          ..["note"] = _sbNote.text.trim(),
        asRow: ({for (final e in _asRow.entries) e.key: e.value.value()})
          ..["note"] = _asNote.text.trim(),
        tests: ({for (final e in _tests.entries) e.key: e.value.value()}),
        whiteReasons: [
          for (final r in (_whiteReasons ?? <_ReasonPick>[]))
            if ((num.tryParse(r.qty.text.trim()) ?? 0) > 0)
              {"reason_id": r.id, "qty": num.parse(r.qty.text.trim())}
        ],
        ncReasons: [
          for (final r in (_ncReasons ?? <_ReasonPick>[]))
            if ((num.tryParse(r.qty.text.trim()) ?? 0) > 0)
              {"reason_id": r.id, "qty": num.parse(r.qty.text.trim())}
        ],
      );
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

  Widget _cardTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
    );
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
            _headerCell("الوحدة", "DCP"),
            _headerCell("التاريخ", _status?.date ?? "-"),
            _headerCell("الوردية", _status?.shiftLabel ?? "-"),
          ],
        ),
      ),
    );
  }

  Widget _totalsCell(String label, num value, {bool bold = false}) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: Border.all(color: AppColors.border),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            Text(label,
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 11)),
            const SizedBox(height: 2),
            Text("${value == value.roundToDouble() ? value.toInt() : value}",
                style: TextStyle(
                    fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _section(
      String title, List<Widget> cells, {Widget? trailing}) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cardTitle(title),
            ...cells,
            if (trailing != null) ...[
              const SizedBox(height: 4),
              trailing,
            ],
          ],
        ),
      ),
    );
  }

  Widget _rowHeader(String title) {
    return Text(title,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14));
  }

  Widget _reasonSection(
      {required String title,
      required String hint,
      required List<_ReasonPick>? picks,
      required num requiredTotal,
      required Color accent}) {
    final sum = _sumReasons(picks);
    final ok = sum == requiredTotal;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cardTitle(title),
            Text(hint,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            const SizedBox(height: 8),
            if (picks == null)
              const Center(child: CircularProgressIndicator())
            else
              ...picks.map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Expanded(child: Text(r.name)),
                        SizedBox(
                            width: 96,
                            child: TextFormField(
                              controller: r.qty,
                              keyboardType:
                                  const TextInputType.numberWithOptions(),
                              textAlign: TextAlign.center,
                              decoration: const InputDecoration(
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (t) {
                                if (t.trim().isEmpty) r.qty.text = "0";
                                _recalc();
                              },
                            )),
                      ],
                    ),
                  )),
            const Divider(height: 16),
            Row(
              children: [
                const Expanded(
                  child: Text("المجموع",
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
                Text(
                  "${sum == sum.roundToDouble() ? sum.toInt() : sum} / ${requiredTotal == requiredTotal.roundToDouble() ? requiredTotal.toInt() : requiredTotal}",
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: ok ? AppColors.primary : AppColors.danger,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: "DCP — إدخال",
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_status?.allShiftsDoneToday ?? false)
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.task_alt, size: 64, color: AppColors.primary),
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
                        _section(
                          "الإجماليات + الاختبار",
                          [
                            Row(
                              children: [
                                _totalsCell("TOTAL EXP", _totalExp),
                                const SizedBox(width: 4),
                                _totalsCell("TOTAL DOM", _totalDom),
                                const SizedBox(width: 4),
                                _totalsCell("TOTAL NC", _totalNc),
                                const SizedBox(width: 4),
                                _totalsCell("AS SB", _asTotal),
                                const SizedBox(width: 4),
                                _totalsCell("Total", _totalExp + _totalDom + _totalNc + _asTotal, bold: true),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                _totalsCell("S.B", _sbTotal),
                                const SizedBox(width: 4),
                                _totalsCell("TOTAL S.B", _sbTotal + _asTotal, bold: true),
                                const SizedBox(width: 4),
                                _totalsCell("اختبارات", _testTotal),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // الاختبار + BB
                        Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _cardTitle("B.B"),
                                GridView.count(
                                  crossAxisCount: 3,
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  childAspectRatio: 2.6,
                                  mainAxisSpacing: 8,
                                  crossAxisSpacing: 8,
                                  children: [for (final f in _bb.values) f],
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                    controller: _bbNote,
                                    decoration:
                                        const InputDecoration(labelText: "Note")),
                                const SizedBox(height: 16),
                                _rowHeader("الاختبار"),
                                const SizedBox(height: 8),
                                GridView.count(
                                  crossAxisCount: 2,
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  childAspectRatio: 3.5,
                                  mainAxisSpacing: 8,
                                  crossAxisSpacing: 8,
                                  children: [for (final f in _tests.values) f],
                                ),
                              ],
                            ),
                          ),
                        ),
                        // S.B | S.B AS
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _rowHeader("S.B"),
                                      const SizedBox(height: 8),
                                      ...[for (final f in _sb.values) f],
                                      const SizedBox(height: 8),
                                      TextField(
                                          controller: _sbNote,
                                          decoration: const InputDecoration(
                                              labelText: "Note")),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _rowHeader("S.B AS"),
                                      const SizedBox(height: 8),
                                      ...[for (final f in _asRow.values) f],
                                      const SizedBox(height: 8),
                                      TextField(
                                          controller: _asNote,
                                          decoration: const InputDecoration(
                                              labelText: "Note")),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        _reasonSection(
                          title: "DCP White",
                          hint:
                              "لازم يساوي الأبيض في B.B = ${_bb["white"]!.value().toInt()}",
                          picks: _whiteReasons,
                          requiredTotal: _bb["white"]!.value(),
                          accent: AppColors.primary,
                        ),
                        _reasonSection(
                          title: "DCP NC",
                          hint: "لازم يساوي الأحمر في B.B = ${_bb["red"]!.value().toInt()}",
                          picks: _ncReasons,
                          requiredTotal: _bb["red"]!.value(),
                          accent: AppColors.danger,
                        ),
                        const SizedBox(height: 12),
                        SaveButton(onPressed: _saving ? null : _save),
                      ],
                    ),
    );
  }
}