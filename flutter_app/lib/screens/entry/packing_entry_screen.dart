import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../api/auth_repository.dart';
import '../../api/entries_repository.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/number_field.dart';

/// PA / SA: جدولين جنب بعض — الأنواع ديناميكية من الإعدادات.
class PackingEntryScreen extends StatefulWidget {
  final String unit; // PA / SA

  const PackingEntryScreen({super.key, required this.unit});

  @override
  State<PackingEntryScreen> createState() => _PackingEntryScreenState();
}

class _PackingEntryScreenState extends State<PackingEntryScreen> {
  final _entries = EntriesRepository();
  Map<int, (String name, NumberField field)>? _types;
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
      final st = await AuthRepository().entryStatus(widget.unit);
      final types = await _entries.packingTypes(widget.unit);
      if (!mounted) return;
      setState(() {
        _status = st;
        _types = {
          for (final t in types)
            (t["id"] as int): (
              t["name"] as String,
              NumberField.zero(label: t["name"], allowDecimal: true)
            )
        };
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
      await _entries.createPacking(widget.unit, {
        for (final e in _types!.entries) e.key.toString(): e.value.$2.value(),
      });
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

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: "${widget.unit} — إدخال",
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
                        Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("جدول $widget.unit",
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(height: 8),
                                GridView.count(
                                  crossAxisCount: 3,
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  childAspectRatio: 1.6,
                                  mainAxisSpacing: 8,
                                  crossAxisSpacing: 8,
                                  children: [
                                    for (final t in _types!.values) t.$2
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
