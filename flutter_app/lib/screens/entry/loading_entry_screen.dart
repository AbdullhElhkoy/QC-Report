import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../api/auth_repository.dart';
import '../../api/entries_repository.dart';
import '../../theme.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/number_field.dart';

const List<String> kLoadingProducts = [
  "SOP", "GSOP", "GCC", "DCP", "PA", "SA", "HCL"
];

class LoadingEntryScreen extends StatefulWidget {
  final int? editId;
  const LoadingEntryScreen({super.key, this.editId});

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
  String? _userName;
  String? _date;
  String? _shiftLabel;
  String? _error;

  bool get _editing => widget.editId != null;

  void _prefill(Map<String, dynamic> vals) {
    final rows = Map<String, dynamic>.from(vals["rows"] as Map? ?? {});
    for (final pt in kLoadingProducts) {
      final row = Map<String, dynamic>.from(rows[pt] as Map? ?? {});
      _fields[pt]!["exp"]!.controller.text =
          "${row["exp"] ?? 0}".replaceFirst(RegExp(r"\.0+$"), "");
      _fields[pt]!["dom"]!.controller.text =
          "${row["dom"] ?? 0}".replaceFirst(RegExp(r"\.0+$"), "");
    }
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
        AuthRepository().entryStatus("LOADING"),
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
      final rows = {
        for (final pt in kLoadingProducts)
          pt: {for (final e in _fields[pt]!.entries) e.key: e.value.value()},
      };
      if (_editing) {
        await _entries.updateEntry(widget.editId!, {"rows": rows});
      } else {
        await _entries.createLoading(rows);
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
            _headerCell("الوحدة", "LOADING"),
            _headerCell("التاريخ", _date ?? _status?.date ?? "-"),
            _headerCell("الوردية", _shiftLabel ?? _status?.shiftLabel ?? "-"),
          ],
        ),
      ),
    );
  }

  Widget _productsTable() {
    final table = Table(
      border: TableBorder.all(color: AppColors.border),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      columnWidths: const {
        0: FixedColumnWidth(140),
        1: FlexColumnWidth(),
        2: FlexColumnWidth(),
      },
      children: [
        TableRow(
          decoration: const BoxDecoration(color: AppColors.primarySoft),
          children: const [
            _HeadCell("نوع المنتج"),
            _HeadCell("EXP"),
            _HeadCell("DOM"),
          ],
        ),
        for (final pt in kLoadingProducts)
          TableRow(
            children: [
              _LabelCell(pt),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: _fields[pt]!["exp"]!,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: _fields[pt]!["dom"]!,
              ),
            ],
          ),
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
      title: _editing ? "Loading — تعديل" : "Loading — إدخال",
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
                        const Text("التحميل — كمية الوحدات المصنّعة الموردة للتحميل",
                            style: TextStyle(
                                color: AppColors.textMuted, fontSize: 12)),
                        const SizedBox(height: 4),
                        _productsTable(),
                        const SizedBox(height: 12),
                        SaveButton(onPressed: _saving ? null : _save),
                      ],
                    ),
    );
  }
}

class _HeadCell extends StatelessWidget {
  final String text;
  const _HeadCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(text,
          style: const TextStyle(
              fontWeight: FontWeight.w700, color: AppColors.primaryStrong)),
    );
  }
}

class _LabelCell extends StatelessWidget {
  final String text;
  const _LabelCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 10),
      color: AppColors.surface2,
      child: Text(text,
          style: const TextStyle(
              fontWeight: FontWeight.w700, color: AppColors.text)),
    );
  }
}