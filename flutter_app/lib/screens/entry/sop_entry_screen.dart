import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../api/auth_repository.dart';
import '../../api/entries_repository.dart';
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

  const SopEntryScreen(
      {super.key, required this.unit, required this.unitLabel});

  @override
  State<SopEntryScreen> createState() => _SopEntryScreenState();
}

class _SopEntryScreenState extends State<SopEntryScreen> {
  final _entries = EntriesRepository();
  late final List<String> _products = kSopProducts[widget.unit]!;
  late final Map<String, Map<String, NumberField>> _fields = {
    for (final pt in _products)
      pt: {
        for (final f in const ["exp", "dom", "std", "nc"])
          f: NumberField.zero(label: f.toUpperCase())
      }
  };
  late final Map<String, NumberField> _bulk = {
    "exp_trucks": NumberField.zero(label: "عربيات EXP"),
    "dom_trucks": NumberField.zero(label: "عربيات DOM"),
    "std_trucks": NumberField.zero(label: "عربيات STD"),
    "nc_trucks": NumberField.zero(label: "عربيات NC"),
  };
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
      final st =
          await AuthRepository().entryStatus(widget.unit);
      if (!mounted) return;
      setState(() {
        _status = st;
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
      final rows = <String, Map<String, dynamic>>{};
      for (final pt in _products) {
        rows[pt] = {for (final e in _fields[pt]!.entries) e.key: e.value.value()};
      }
      await _entries.createSop(
        widget.unit,
        rows,
        bulkLog: kBulkUnits.contains(widget.unit)
            ? {for (final e in _bulk.entries) e.key: e.value.value()}
            : null,
      );
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

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: "${widget.unitLabel} — إدخال",
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _status != null && _status!.allShiftsDoneToday
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.task_alt, size: 64, color: Colors.green),
                      const SizedBox(height: 12),
                      const Text("الورديات الثلاثة اتسجلت بالفعل اليوم."),
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
                        ..._products.map((pt) => Card(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(kProductLabels[pt] ?? pt,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16)),
                                    const SizedBox(height: 8),
                                    GridView.count(
                                      crossAxisCount: 4,
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      childAspectRatio: 2.2,
                                      mainAxisSpacing: 8,
                                      crossAxisSpacing: 8,
                                      children: [
                                        for (final e in _fields[pt]!.entries)
                                          e.value
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            )),
                        if (kBulkUnits.contains(widget.unit))
                          Card(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("العربيات (Bulk)",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16)),
                                  const SizedBox(height: 8),
                                  GridView.count(
                                    crossAxisCount: 2,
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    childAspectRatio: 3.5,
                                    mainAxisSpacing: 8,
                                    crossAxisSpacing: 8,
                                    children: [
                                      for (final b in _bulk.values) b
                                    ],
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
