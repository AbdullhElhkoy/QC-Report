import 'package:flutter/material.dart';

/// Scaffold موحّد: هيدر فيه اسم التطبيق + المستخدم + وحدته + زر خروج.
class AppScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final String? userName;
  final String? unitLabel;
  final VoidCallback? onLogout;
  final List<Widget>? actions;

  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.userName,
    this.unitLabel,
    this.onLogout,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        centerTitle: true,
        actions: [
          if (userName != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: Text(
                  unitLabel == null ? userName! : "$userName — $unitLabel",
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ...?actions,
          if (onLogout != null)
            IconButton(
              tooltip: "خروج",
              icon: const Icon(Icons.logout),
              onPressed: onLogout,
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: body,
      ),
    );
  }
}

/// زر الحفظ الرئيسي بحجم كبير.
class SaveButton extends StatelessWidget {
  final Future<void> Function()? onPressed;
  final String label;

  const SaveButton({super.key, required this.onPressed, this.label = "حفظ"});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: onPressed,
        child: Text(label, style: const TextStyle(fontSize: 18)),
      ),
    );
  }
}
