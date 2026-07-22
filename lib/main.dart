import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/login_screen.dart';

void main() {
  runApp(const LogonAttendanceApp());
}

class LogonAttendanceApp extends StatelessWidget {
  const LogonAttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Logon Attendance',
      theme: AppTheme.light,
      home: const LoginScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}