import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../api/auth_repository.dart';
import '../../api/entries_repository.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/number_field.dart';

const List<String> kLoadingProducts = [
  "SOP", "GSOP", "GCC", "DCP", "PA", "SA", "HCL"
];

class LoadingEntryScreen extends StatefulWidget {
  const LoadingEntryScreen({super.key});

  @override
  State<LoadingEntryScreen> createState() => _LoadingEntryScreenState();
}

class _LoadingEntryScreenState extends State<LoadingEntryScreen> {
  final _entries = EntriesRepository();
  late final Map<String, Map<String, NumberField>> _fields = {
    for (final pt in kLoadingProducts)
      pt: {
        "exp": NumberField.zero(label: "EXP"),
        "dom": NumberField.zero(label: "DOM"),
      }
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
      final st = await AuthRepository().entryStatus("LOADING");
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
      await _entries.createLoading({
        for (final pt in kLoadingProducts)
          pt: {for (final e in _fields[pt]!.entries) e.key: e.value.value()},
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
      title: "Loading — إدخال",
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
                                style:
                                    const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        // التحميلات بالعرض: أعمدة المنتجات وصفوف EXP/DOM
                        Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const SizedBox(
                                        width: 60, child: Text("", textAlign: TextAlign.center)),
                                    for (final pt in kLoadingProducts)
                                      SizedBox(
                                          width: 90,
                                          child: Text(pt,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold))),
                                  ],
                                ),
                                for (final field in const ["exp", "dom"])
                                  Row(
                                    children: [
                                      SizedBox(
                                          width: 60,
                                          child: Text(field.toUpperCase(),
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold))),
                                      for (final pt in kLoadingProducts)
                                        SizedBox(
                                            width: 90,
                                            child: Padding(
                                                padding:
                                                    const EdgeInsets.all(4),
                                                child: _fields[pt]![field]!)),
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
