import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../api/auth_repository.dart';
import '../../api/entries_repository.dart';
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
    "green": NumberField.zero(label: "Green"),
    "yellow": NumberField.zero(label: "Yellow"),
    "green_yellow": NumberField.zero(label: "G & Y"),
    "blue": NumberField.zero(label: "Blue"),
    "white": NumberField.zero(label: "White"),
    "red": NumberField.zero(label: "Red"),
  };
  final _bbNote = TextEditingController();
  late final Map<String, NumberField> _sb = {
    "exp": NumberField.zero(label: "EXP"),
    "dom": NumberField.zero(label: "DOM"),
    "sb_white": NumberField.zero(label: "S.B White"),
  };
  late final Map<String, NumberField> _asRow = {
    "exp": NumberField.zero(label: "EXP"),
    "dom": NumberField.zero(label: "DOM"),
    "sb_white": NumberField.zero(label: "S.B White"),
  };
  late final Map<String, NumberField> _tests = {
    "lab_test": NumberField.zero(label: "Lab Test"),
    "floor_test": NumberField.zero(label: "Floor Test"),
  };

  List<_ReasonPick>? _whiteReasons;
  List<_ReasonPick>? _ncReasons;
  bool _loading = true;
  bool _saving = false;
  EntryStatus? _status;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final st = await AuthRepository().entryStatus("DCP");
      final white = await _entries.dcpReasons("white");
      final nc = await _entries.dcpReasons("nc");
      if (!mounted) return;
      setState(() {
        _status = st;
        _whiteReasons =
            [for (final r in white) _ReasonPick(id: r["id"], name: r["name"])];
        _ncReasons =
            [for (final r in nc) _ReasonPick(id: r["id"], name: r["name"])];
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
      await _entries.createDcp(
        bb: {for (final e in _bb.entries) e.key: e.value.value()}
          ..["note"] = _bbNote.text.trim(),
        sb: {for (final e in _sb.entries) e.key: e.value.value()},
        asRow: {for (final e in _asRow.entries) e.key: e.value.value()},
        tests: {for (final e in _tests.entries) e.key: e.value.value()},
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
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("تم الحفظ ✅")));
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: Colors.red,
          content: Text(ApiClient.extractErrorFromException(e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _reasonSection(String title, List<_ReasonPick>? picks, Color color) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: color == Colors.red ? Colors.red : Colors.black)),
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
                            width: 90,
                            child: TextFormField(
                              controller: r.qty,
                              keyboardType:
                                  const TextInputType.numberWithOptions(),
                              decoration: const InputDecoration(
                                  labelText: "الرقم"),
                              onChanged: (t) {
                                if (t.trim().isEmpty) r.qty.text = "0";
                              },
                            )),
                      ],
                    ),
                  )),
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
                      Icon(Icons.task_alt, size: 64, color: Colors.green),
                      SizedBox(height: 12),
                      Text("الورديات الثلاثة اتسجلت بالفعل اليوم."),
                    ],
                  ),
                )
              : _error != null
                  ? Center(child: Text(_error!))
                  : ListView(
                      children: [
                        Card(
                          color: const Color(0xFFD9EAD3),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Text(
                                "الوردية المتاحة: ${_status?.shiftLabel ?? "-"}",
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        // B.B table
                        Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("جدول B.B",
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(height: 8),
                                GridView.count(
                                  crossAxisCount: 3,
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  childAspectRatio: 2.6,
                                  mainAxisSpacing: 8,
                                  crossAxisSpacing: 8,
                                  children: [for (final f in _bb.values) f],
                                ),
                                TextField(
                                    controller: _bbNote,
                                    decoration:
                                        const InputDecoration(labelText: "ملاحظة")),
                              ],
                            ),
                          ),
                        ),
                        // S.B + AS side by side
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Column(children: [
                                    const Text("S.B",
                                        style: TextStyle(fontWeight: FontWeight.bold)),
                                    ...[for (final f in _sb.values) f],
                                  ]),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Column(children: [
                                    const Text("AS",
                                        style: TextStyle(fontWeight: FontWeight.bold)),
                                    ...[for (final f in _asRow.values) f],
                                  ]),
                                ),
                              ),
                            ),
                          ],
                        ),
                        _reasonSection("أسباب العيوب — الأبيض", _whiteReasons, Colors.black),
                        _reasonSection("أسباب العيوب — الأحمر (NC)", _ncReasons, Colors.red),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("اختبارات الوردية",
                                    style: TextStyle(fontWeight: FontWeight.bold)),
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
                        const SizedBox(height: 12),
                        SaveButton(onPressed: _saving ? null : _save),
                      ],
                    ),
    );
  }
}
