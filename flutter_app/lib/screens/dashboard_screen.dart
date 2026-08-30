import 'package:flutter/material.dart';

import '../api/auth_repository.dart';
import '../theme.dart';
import '../widgets/app_scaffold.dart';
import 'entry/dcp_entry_screen.dart';
import 'entry/gcc_entry_screen.dart';
import 'entry/loading_entry_screen.dart';
import 'entry/packing_entry_screen.dart';
import 'entry/sop_entry_screen.dart';
import 'login_screen.dart';
import 'records_screen.dart';
import 'reports/daily_report_screen.dart';
import 'reports/shift_report_screen.dart';

class DashboardScreen extends StatefulWidget {
  final UserModel me;
  const DashboardScreen({super.key, required this.me});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final Future<List<UnitItem>> _unitsFuture;
  late final Future<EntryStatus>? _statusFuture;

  @override
  void initState() {
    super.initState();
    final auth = AuthRepository();
    _unitsFuture = auth.units();
    _statusFuture = widget.me.isManager
        ? null
        : (widget.me.assignedUnit != null
            ? auth.entryStatus(widget.me.assignedUnit!)
            : null);
  }

  Future<void> _logout(BuildContext context) async {
    await AuthRepository().logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  void _open(BuildContext context, UnitItem u) {
    Widget screen = switch (u.value) {
      "DCP" => DcpEntryScreen(),
      "PA" || "SA" => PackingEntryScreen(unit: u.value),
      "GCC1" || "GCC2" => GccEntryScreen(unit: u.value),
      "LOADING" => LoadingEntryScreen(),
      _ => SopEntryScreen(unit: u.value, unitLabel: u.label),
    };
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  Widget _greeting() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              "مرحباً، ${widget.me.fullName}",
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
          const Text(
            "QC-CORE // BUILD 2050",
            style: TextStyle(
              fontFamily: "monospace",
              fontSize: 11,
              letterSpacing: 1,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Text(title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: "QC Report",
      userName: widget.me.fullName,
      unitLabel: widget.me.assignedUnitLabel,
      onLogout: () => _logout(context),
      body: ListView(
        children: [
          _greeting(),
          if (widget.me.isManager)
            ..._managerCards(context)
          else
            ..._operatorCards(context),
        ],
      ),
    );
  }

  List<Widget> _managerCards(BuildContext context) {
    return [
      Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _cardHeader("التقرير اليومي"),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text("عرض التقرير المجمع لكل الوحدات مع الرسوم البيانية.",
                      style: TextStyle(color: AppColors.textMuted)),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    icon: const Icon(Icons.assessment_outlined),
                    label: Text("تقرير اليوم (${DateTime.now().toString().substring(0, 10)})"),
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const DailyReportScreen()),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.nights_stay_outlined),
                    label: const Text("تقرير الوردية"),
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ShiftReportScreen()),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.settings_outlined),
                    label: const Text("إدارة المستخدمين والإدخالات"),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("الإدارة متاحة من النسخة الويب: /admin/")),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.list_alt_outlined),
                    label: const Text("سجل الإدخالات والتعديلات"),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const RecordsScreen()),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _cardHeader("إدخال بيانات وحدة معينة"),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FutureBuilder<List<UnitItem>>(
                future: _unitsFuture,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const SizedBox(
                        height: 60,
                        child: Center(child: CircularProgressIndicator()));
                  }
                  final units = snap.data ?? const <UnitItem>[];
                  if (snap.hasError || units.isEmpty) {
                    return const Text("تعذر تحميل الوحدات.",
                        style: TextStyle(color: AppColors.danger));
                  }
                  return GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 3.2,
                    children: [
                      for (final u in units)
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          onPressed: () => _open(context, u),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.circle,
                                  size: 8, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(u.label,
                                    overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _operatorCards(BuildContext context) {
    final unit = widget.me.assignedUnit;
    return [
      Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _cardHeader("وحدتك: ${widget.me.assignedUnitLabel ?? "-"}"),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text("إدخال بيانات وردية جديدة"),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                onPressed: unit == null
                    ? null
                    : () => _open(context,
                        UnitItem(value: unit, label: widget.me.assignedUnitLabel ?? unit)),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _cardHeader("السجل والتعديلات"),
            Padding(
              padding: const EdgeInsets.all(16),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.list_alt_outlined),
                label: const Text("سجل الإدخالات والتعديلات"),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RecordsScreen()),
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _cardHeader("إدخالات اليوم"),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FutureBuilder<EntryStatus?>(
                future: _statusFuture,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const SizedBox(
                        height: 60,
                        child: Center(child: CircularProgressIndicator()));
                  }
                  final st = snap.data;
                  final entries = st?.todayEntries ?? const <TodayEntry>[];
                  if (entries.isEmpty) {
                    return const Text("لم يتم إدخال أي وردية اليوم بعد.",
                        style: TextStyle(color: AppColors.textMuted));
                  }
                  return Column(
                    children: [
                      for (final e in entries)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.schedule,
                              color: AppColors.primary),
                          title: Text(e.shiftLabel,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          trailing: Text(e.submittedAt,
                              style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontFamily: "monospace")),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ];
  }
}