import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_theme.dart';
import '../attendance/calendar_screen.dart';

class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;
  List<dynamic> _members = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _api.getMembers();
      setState(() => _members = data);
    } catch (_) {
      setState(() => _error = 'Could not load members — pull down to retry');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('All Members')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(children: [
                    const SizedBox(height: AppSpacing.xl),
                    Center(child: Text(_error!, style: Theme.of(context).textTheme.bodyMedium)),
                  ])
                : _members.isEmpty
                    ? ListView(children: [
                        const SizedBox(height: AppSpacing.xl),
                        Center(child: Text('No members yet', style: Theme.of(context).textTheme.bodyMedium)),
                      ])
                    : ListView.separated(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        itemCount: _members.length,
                        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, index) {
                          final m = _members[index] as Map<String, dynamic>;
                          final name = '${m['first_name'] ?? ''} ${m['last_name'] ?? ''}'.trim();
                          return _MemberRow(
                            name: name.isEmpty ? '(no name)' : name,
                            photoPath: m['photo_path'],
                            role: m['role'],
                            branchName: m['branch']?['name'],
                            active: m['status'] == 'active',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => CalendarScreen(
                                  memberId: m['id'] as int,
                                  memberName: name.isEmpty ? 'Member' : name,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  final String name;
  final String? photoPath;
  final String? role;
  final String? branchName;
  final bool active;
  final VoidCallback onTap;

  const _MemberRow({
    required this.name,
    required this.photoPath,
    required this.role,
    required this.branchName,
    required this.active,
    required this.onTap,
  });

  (Color, String) get _roleStyle {
    switch (role) {
      case 'admin':
      case 'super_admin':
        return (AppColors.warning, 'Admin');
      case 'supervisor':
        return (AppColors.info, 'Supervisor');
      case 'member':
        return (AppColors.primary, 'Member');
      default:
        return (AppColors.textMuted, 'No account');
    }
  }

  @override
  Widget build(BuildContext context) {
    final (roleColor, roleLabel) = _roleStyle;

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
              Opacity(
                opacity: active ? 1.0 : 0.4,
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  backgroundImage: photoPath != null
                      ? NetworkImage('https://attendance.logoninvoice.com/storage/$photoPath')
                      : null,
                  child: photoPath == null
                      ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700))
                      : null,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(name, style: Theme.of(context).textTheme.titleSmall)),
                        if (!active)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.dangerSoft,
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                            ),
                            child: const Text('Inactive',
                                style: TextStyle(fontSize: 10, color: AppColors.danger, fontWeight: FontWeight.w700)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(branchName ?? 'No branch', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: roleColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(roleLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: roleColor)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}