import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../api/auth_repository.dart';
import '../../api/entries_repository.dart';
import '../../theme.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/number_field.dart';

/// أنواع المنتجات لكل وحدة SOP — مطابقة لـ SOP_PRODUCT_TYPES في الباك إند.
const Map<String, List<String>> kSopProducts = {
  "SOP_A": ["S_B", "B_B", "BULK"],
  "SOP_B": ["S_B", "B_B", "BULK"],
  "SOP_C": ["S_B", "B_B", "BULK"],
  "SOP_D": ["S_B", "B_B", "BULK"],
  "G_SOP": ["S_B", "B_B"],
  "C_PACKING": ["O_M", "VA", "B_B"],
};

const Map<String, String> kProductLabels = {
  "S_B": "S.B",
  "B_B": "B.B",
  "BULK": "BULK",
  "O_M": "O.M",
  "VA": "V.A",
};

const List<String> kBulkUnits = ["SOP_A", "SOP_B", "SOP_C", "SOP_D"];

class SopEntryScreen extends StatefulWidget {
  final String unit;
  final String unitLabel;
  final int? editId;

  const SopEntryScreen(
      {super.key, required this.unit, required this.unitLabel, this.editId});

  @override
  State<SopEntryScreen> createState() => _SopEntryScreenState();
}

class _SopEntryScreenState extends State<SopEntryScreen> {
  final _entries = EntriesRepository();
  late final List<String> _products = kSopProducts[widget.unit]!;

  /// كل منتج ليه: exp/dom/std/nc (رقمي) + cause/note (نص، مش لو G_SOP) +
  /// defect_reason/notes (نص) + car_number/car_weight (رقمي، صف BULK بس)
  /// — بالظبط نفس الحقول العشرة اللي الـ API بتستناها (راجع api_views.py).
  late final Map<String, Map<String, dynamic>> _fields = {
    for (final pt in _products)
      pt: {
        "exp": NumberField.zero(label: "EXP"),
        "dom": NumberField.zero(label: "DOM"),
        "std": NumberField.zero(label: "STD"),
        "nc": NumberField.zero(label: "NC"),
        if (widget.unit != "G_SOP") "cause": TextEditingController(),
        if (widget.unit != "G_SOP") "note": TextEditingController(),
        "defect_reason": TextEditingController(),
        "notes": TextEditingController(),
        if (pt == "BULK") "car_number": NumberField.zero(label: "رقم العربية"),
        if (pt == "BULK")
          "car_weight": NumberField.zero(label: "وزن العربية", allowDecimal: true),
      }
  };
  late final Map<String, NumberField> _bulk = {
    "exp_trucks": NumberField.zero(label: "عربيات EXP"),
    "dom_trucks": NumberField.zero(label: "عربيات DOM"),
    "std_trucks": NumberField.zero(label: "عربيات STD"),
    "nc_trucks": NumberField.zero(label: "عربيات NC"),
  };
  final _generalNotes = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  EntryStatus? _status;
  String? _userName;
  String? _date;
  String? _shiftLabel;
  String? _error;

  bool get _editing => widget.editId != null;

  void _prefill(Map<String, dynamic> vals) {
    final rows = Map<String, dynamic>.from(vals["rows"] as Map? ?? {});
    for (final pt in _products) {
      final row = Map<String, dynamic>.from(rows[pt] as Map? ?? {});
      final f = _fields[pt]!;
      for (final key in ["exp", "dom", "std", "nc"]) {
        final v = row[key];
        if (v != null && f[key] is NumberField) {
          (f[key] as NumberField).controller.text =
              "$v".replaceFirst(RegExp(r"\.0+$"), "");
        }
      }
      for (final key in ["cause", "note", "defect_reason", "notes"]) {
        final v = row[key];
        if (v != null && f[key] is TextEditingController) {
          (f[key] as TextEditingController).text = "$v";
        }
      }
      for (final key in ["car_number", "car_weight"]) {
        final v = row[key];
        if (v != null && f[key] is NumberField) {
          (f[key] as NumberField).controller.text =
              "$v".replaceFirst(RegExp(r"\.0+$"), "");
        }
      }
    }
    final bulk = Map<String, dynamic>.from(vals["bulk_log"] as Map? ?? {});
    for (final e in _bulk.entries) {
      final v = bulk[e.key];
      if (v != null) e.value.controller.text = "$v";
    }
    _generalNotes.text = "${vals["general_notes"] ?? ""}";
  }

  @override
  void initState() {
    super.initState();
    _load();
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

  num _numVal(dynamic field) =>
      field is NumberField ? field.value() : 0;

  String _textVal(dynamic field) =>
      field is TextEditingController ? field.text.trim() : "";

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final rows = <String, Map<String, dynamic>>{};
      for (final pt in _products) {
        final f = _fields[pt]!;
        rows[pt] = {
          "exp": _numVal(f["exp"]),
          "dom": _numVal(f["dom"]),
          "std": _numVal(f["std"]),
          "nc": _numVal(f["nc"]),
          if (widget.unit != "G_SOP") "cause": _textVal(f["cause"]),
          if (widget.unit != "G_SOP") "note": _textVal(f["note"]),
          "defect_reason": _textVal(f["defect_reason"]),
          "notes": _textVal(f["notes"]),
          if (pt == "BULK") "car_number": _numVal(f["car_number"]),
          if (pt == "BULK") "car_weight": _numVal(f["car_weight"]),
        };
      }
      if (_editing) {
        await _entries.updateEntry(widget.editId!, {
          "general_notes": _generalNotes.text.trim(),
          "rows": rows,
          if (kBulkUnits.contains(widget.unit))
            "bulk_log": {for (final e in _bulk.entries) e.key: e.value.value()},
        });
      } else {
        await _entries.createSop(
          widget.unit,
          rows,
          generalNotes: _generalNotes.text.trim(),
          bulkLog: kBulkUnits.contains(widget.unit)
              ? {for (final e in _bulk.entries) e.key: e.value.value()}
              : null,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("تم الحفظ ✅ — سجل الوردية اللي بعدها أو ارجع.")));
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

  /// هيدر الوردية: الموظف / الوحدة / التاريخ / الوردية — زي partials/shift_fields.html
  Widget _shiftHeader() {
    Widget cell(String label, String value) => Expanded(
          child: Column(
            children: [
              Text(label,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              const SizedBox(height: 2),
              Text(value,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        );
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            cell("الموظف", _userName ?? "-"),
            cell("الوحدة", widget.unitLabel),
            cell("التاريخ", _date ?? _status?.date ?? "-"),
            cell("الوردية", _shiftLabel ?? _status?.shiftLabel ?? "-"),
          ],
        ),
      ),
    );
  }

  Widget _denseNumber(NumberField f) => SizedBox(width: 72, child: f);

  Widget _denseText(TextEditingController c, {double width = 110}) => SizedBox(
        width: width,
        child: TextFormField(
          controller: c,
          style: const TextStyle(fontSize: 13),
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 10),
            border: OutlineInputBorder(),
          ),
        ),
      );

  Widget _disabledCell() => const SizedBox(
        width: 72,
        child: Center(child: Text("—", style: TextStyle(color: Colors.grey))),
      );

  /// جدول الإدخال بشكل Excel-grid: صف لكل منتج وعمود لكل حقل — بالظبط زي
  /// templates/entry_sop.html بدل ما كل منتج يبقى كارت منفصل غير مكتمل.
  Widget _productsTable() {
    final showCauseNote = widget.unit != "G_SOP";
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowHeight: 40,
            headingTextStyle: const TextStyle(
                fontWeight: FontWeight.w700, color: AppColors.primaryStrong),
            headingRowColor: WidgetStatePropertyAll(AppColors.primarySoft),
            dataRowMinHeight: 56,
            dataRowMaxHeight: 64,
            columnSpacing: 10,
            dividerThickness: 1,
            columns: [
              const DataColumn(label: Text("المنتج")),
              const DataColumn(label: Text("EXP")),
              const DataColumn(label: Text("DOM")),
              const DataColumn(label: Text("STD")),
              const DataColumn(label: Text("NC")),
              if (showCauseNote) const DataColumn(label: Text("Cause")),
              if (showCauseNote) const DataColumn(label: Text("Note")),
              const DataColumn(label: Text("سبب العيب")),
              const DataColumn(label: Text("ملاحظات")),
              const DataColumn(label: Text("رقم العربية")),
              const DataColumn(label: Text("وزن العربية")),
            ],
            rows: [
              for (final pt in _products)
                DataRow(cells: [
                  DataCell(
                    SizedBox(
                      width: 74,
                      child: Center(
                        child: Text(kProductLabels[pt] ?? pt,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.text)),
                      ),
                    ),
                  ),
                  DataCell(_denseNumber(_fields[pt]!["exp"])),
                  DataCell(_denseNumber(_fields[pt]!["dom"])),
                  DataCell(_denseNumber(_fields[pt]!["std"])),
                  DataCell(_denseNumber(_fields[pt]!["nc"])),
                  if (showCauseNote)
                    DataCell(_denseText(_fields[pt]!["cause"])),
                  if (showCauseNote)
                    DataCell(_denseText(_fields[pt]!["note"])),
                  DataCell(_denseText(_fields[pt]!["defect_reason"])),
                  DataCell(_denseText(_fields[pt]!["notes"])),
                  DataCell(pt == "BULK"
                      ? _denseNumber(_fields[pt]!["car_number"])
                      : _disabledCell()),
                  DataCell(pt == "BULK"
                      ? _denseNumber(_fields[pt]!["car_weight"])
                      : _disabledCell()),
                ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bulkTrucksCard() {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("عربيات BULK",
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 4),
            const Text("أدخل أعداد العربيات الموزعة على الأنواع.",
                style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SizedBox(width: 150, child: _bulk["exp_trucks"]),
                SizedBox(width: 150, child: _bulk["dom_trucks"]),
                SizedBox(width: 150, child: _bulk["std_trucks"]),
                SizedBox(width: 150, child: _bulk["nc_trucks"]),
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
      title: _editing
          ? "${widget.unitLabel} — تعديل"
          : "${widget.unitLabel} — إدخال",
      body: _loading
          ? const Center(child: CircularProgressIndicator())
: _status != null && _status!.allShiftsDoneToday
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
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
                        const Text("ملاحظات عامة",
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        TextFormField(
                          controller: _generalNotes,
                          minLines: 1,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _productsTable(),
                        if (kBulkUnits.contains(widget.unit)) _bulkTrucksCard(),
                        const SizedBox(height: 12),
                        SaveButton(onPressed: _saving ? null : _save),
                      ],
                    ),
    );
  }
}