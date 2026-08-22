import 'package:flutter/material.dart';

import '../api/auth_repository.dart';
import '../widgets/app_scaffold.dart';
import 'entry/dcp_entry_screen.dart';
import 'entry/gcc_entry_screen.dart';
import 'entry/loading_entry_screen.dart';
import 'entry/packing_entry_screen.dart';
import 'entry/sop_entry_screen.dart';
import 'login_screen.dart';
import 'reports/daily_report_screen.dart';

class DashboardScreen extends StatelessWidget {
  final UserModel me;

  const DashboardScreen({super.key, required this.me});

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
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final authRepo = AuthRepository();
    return AppScaffold(
      title: "QC Report",
      userName: me.fullName,
      unitLabel: me.assignedUnitLabel,
      onLogout: () => _logout(context),
      body: FutureBuilder<List<UnitItem>>(
        future: authRepo.units(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || snap.data == null || snap.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(snap.hasError
                      ? "فشل تحميل الوحدات.\n${snap.error}"
                      : "لا توجد وحدات مسندة إليك."),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => _logout(context),
                    child: const Text("خروج"),
                  ),
                ],
              ),
            );
          }
          final units = snap.data!;
          return ListView(
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text("اختار الوحدة لتسجيل الوردية:",
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              ...units.map((u) => Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      leading: const Icon(Icons.factory_outlined),
                      title: Text(u.label,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      trailing: const Icon(Icons.chevron_left),
                      onTap: () => _open(context, u),
                    ),
                  )),
              // شاشة التقرير اليومي للمدير فقط
              if (me.isManager) ...[
                const SizedBox(height: 16),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.assessment_outlined),
                  label: const Text("التقرير اليومي"),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => DailyReportScreen()),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
