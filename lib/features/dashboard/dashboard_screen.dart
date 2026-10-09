import 'package:flutter/material.dart';
import '../../core/utils/responsive.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_theme.dart';
import '../attendance/attendance_screen.dart';
import '../attendance/attendance_history_screen.dart';
import '../attendance/today_attendance_screen.dart';
import '../attendance/calendar_screen.dart';
import '../admin/branches_screen.dart';
import '../admin/join_code_screen.dart';
import '../auth/login_screen.dart';
import '../admin/members_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _api = ApiService();
  bool _isAdmin = false;
  bool _isSupervisor = false;
  bool _isManager = false;
  String _role = 'member';

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final role = await _api.getRole();
    setState(() {
      _role = role;
      _isAdmin = role == 'admin' || role == 'super_admin';
      _isSupervisor = role == 'supervisor';
      _isManager = role == 'manager';
    });
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You\'ll need to sign in again to clock in or out.'),  
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _api.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = Responsive.isDesktop(context);
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Log out',
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isWide ? 640 : double.infinity),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xl),
              children: [
                _GreetingHeader(role: _role),
                const SizedBox(height: AppSpacing.xl),
                // Admins oversee the company and don't clock in themselves,
                // so the personal clock-in cards are for everyone else.
                if (!_isAdmin) ...[
                  Text('Quick Actions', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  _DashboardCard(
                    icon: Icons.fingerprint_rounded,
                    iconColor: AppColors.primary,
                    iconBg: AppColors.primary.withValues(alpha: 0.10),
                    title: 'Clock In / Out',
                    subtitle: "Record today's attendance",
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AttendanceScreen()),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _DashboardCard(
                    icon: Icons.history_rounded,
                    iconColor: AppColors.accent,
                    iconBg: AppColors.accentSoft,
                    title: 'Attendance History',
                    subtitle: 'View your past records',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AttendanceHistoryScreen()),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _DashboardCard(
                    icon: Icons.calendar_month_rounded,
                    iconColor: AppColors.primary,
                    iconBg: AppColors.primary.withValues(alpha: 0.10),
                    title: 'My Calendar',
                    subtitle: 'See your month at a glance',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CalendarScreen()),
                    ),
                  ),
                ],
                if (_isSupervisor) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text('My Branch', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  _DashboardCard(
                    icon: Icons.groups_rounded,
                    iconColor: AppColors.info,
                    iconBg: AppColors.infoSoft,
                    title: 'Today\'s Attendance',
                    subtitle: 'See who\'s in, late, or absent',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const TodayAttendanceScreen()),
                    ),
                  ),
                ],
                if (_isManager) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text('Management', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  _DashboardCard(
                    icon: Icons.groups_rounded,
                    iconColor: AppColors.info,
                    iconBg: AppColors.infoSoft,
                    title: 'Today\'s Attendance',
                    subtitle: 'See who\'s in, late, or absent — all branches',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const TodayAttendanceScreen()),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _DashboardCard(
                    icon: Icons.groups_2_rounded,
                    iconColor: AppColors.primary,
                    iconBg: AppColors.primary.withValues(alpha: 0.10),
                    title: 'All Members',
                    subtitle: 'Roster and branches at a glance',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const MembersScreen()),
                    ),
                  ),
                ],
                if (_isAdmin) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text('Admin Tools', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  _DashboardCard(
                    icon: Icons.groups_rounded,
                    iconColor: AppColors.info,
                    iconBg: AppColors.infoSoft,
                    title: 'Today\'s Attendance',
                    subtitle: 'See who\'s in, late, or absent — all branches',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const TodayAttendanceScreen()),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _DashboardCard(
                    icon: Icons.business_rounded,
                    iconColor: AppColors.warning,
                    iconBg: AppColors.warningSoft,
                    title: 'Manage Branches',
                    subtitle: 'Set locations and geofence radius',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const BranchesScreen()),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _DashboardCard(
                    icon: Icons.qr_code_2_rounded,
                    iconColor: AppColors.info,
                    iconBg: AppColors.infoSoft,
                    title: 'Join Code & Invites',
                    subtitle: 'Bring new members onto the platform',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const JoinCodeScreen()),
                    ),
                  ),
                  _DashboardCard(
                    icon: Icons.groups_2_rounded,
                    iconColor: AppColors.primary,
                    iconBg: AppColors.primary.withValues(alpha: 0.10),
                    title: 'All Members',
                    subtitle: 'Roster, roles, and branches at a glance',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const MembersScreen()),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Gradient hero header greeting the user and showing their role.
class _GreetingHeader extends StatelessWidget {
  final String role;
  const _GreetingHeader({required this.role});

  String get _roleLabel {
    switch (role) {
      case 'super_admin':
        return 'Super Admin';
      case 'admin':
        return 'Admin';
      case 'manager':
        return 'Manager';
      case 'supervisor':
        return 'Supervisor';
      default:
        return 'Member';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: AppGradients.brand,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              _roleLabel,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12.5),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Welcome back 👋',
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            "Here's your dashboard for today",
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _DashboardCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceCard,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(AppRadius.sm)),
                child: Icon(icon, size: 26, color: iconColor),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
