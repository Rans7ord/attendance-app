import 'package:flutter/material.dart';
import '../../core/utils/responsive.dart';
import '../attendance/attendance_screen.dart';
import '../attendance/attendance_history_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isWide = Responsive.isDesktop(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isWide ? 600 : double.infinity),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Welcome back', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 24),
                _DashboardCard(
                  icon: Icons.login,
                  title: 'Clock In / Out',
                  subtitle: 'Record today\'s attendance',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AttendanceScreen()),
                  ),
                ),
                const SizedBox(height: 12),
                _DashboardCard(
                  icon: Icons.history,
                  title: 'Attendance History',
                  subtitle: 'View your past records',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AttendanceHistoryScreen()),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _DashboardCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Icon(icon, size: 32),
        title: Text(title, style: Theme.of(context).textTheme.titleMedium),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}