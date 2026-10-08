import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'core/services/api_service.dart';
import 'core/services/navigation_service.dart';
import 'features/auth/login_screen.dart';
import 'features/dashboard/dashboard_screen.dart';

void main() {
  // Whenever any API call comes back 401 (expired/invalid token), clear
  // the stored session and send the user back to login — from wherever
  // they were, without every screen needing its own error handling for it.
  ApiService.onUnauthorized = () {
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  };

  runApp(const LogonAttendanceApp());
}

class LogonAttendanceApp extends StatelessWidget {
  const LogonAttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Logon Attendance',
      theme: AppTheme.light,
      home: const _StartupScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

/// Shown briefly on launch while we check whether a session is already
/// stored, so a relaunch while logged in goes straight to the dashboard
/// instead of always showing the login screen.
class _StartupScreen extends StatefulWidget {
  const _StartupScreen();

  @override
  State<_StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<_StartupScreen> {
  final _api = ApiService();

  @override
  void initState() {
    super.initState();
    _decide();
  }

  Future<void> _decide() async {
    final hasToken = await _api.hasToken();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => hasToken ? const DashboardScreen() : const LoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}