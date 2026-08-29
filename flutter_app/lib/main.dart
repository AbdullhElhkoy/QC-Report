import 'package:flutter/material.dart';

import 'api/api_client.dart';
import 'api/auth_repository.dart';
import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'theme.dart';

/// عنوان الـ API بيتحدد وقت البناء:
/// flutter run --dart-define=API_BASE_URL=http://<ip>:8000
const String kApiBaseUrl = String.fromEnvironment(
  "API_BASE_URL",
  defaultValue: "http://127.0.0.1:8000",
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiClient.instance.initInterceptors();
  runApp(const QcReportApp());
}

class QcReportApp extends StatelessWidget {
  const QcReportApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "QC Report",
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      locale: const Locale("ar"),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child!,
      ),
      home: const BootstrapScreen(),
    );
  }
}

/// شاشة انتظار: لو فيه توكن محفوظ ندخل الداشبورد، وإلا تسجيل الدخول.
class BootstrapScreen extends StatefulWidget {
  const BootstrapScreen({super.key});

  @override
  State<BootstrapScreen> createState() => _BootstrapScreenState();
}

class _BootstrapScreenState extends State<BootstrapScreen> {
  @override
  void initState() {
    super.initState();
    _decide();
  }

  Future<void> _decide() async {
    final auth = AuthRepository();
    final token = await auth.readAccessToken();
    if (!mounted) return;
    if (token == null || token.isEmpty) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }
    try {
      // لو التوكن منتهي، أول طلب هيحصل 401 والـ interceptor هيعمل refresh تلقائي
      final me = await auth.me();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => DashboardScreen(me: me)),
      );
    } catch (_) {
      await auth.logout();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
