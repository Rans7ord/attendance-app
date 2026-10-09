import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/attendance_status.dart';
import 'calendar_screen.dart';

class TodayAttendanceScreen extends StatefulWidget {
  const TodayAttendanceScreen({super.key});

  @override
  State<TodayAttendanceScreen> createState() => _TodayAttendanceScreenState();
}

class _TodayAttendanceScreenState extends State<TodayAttendanceScreen> {
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
      final data = await _api.getTodayAttendance();
      setState(() => _members = data);
    } catch (_) {
      setState(() => _error = 'Could not load today\'s attendance — pull down to retry');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// If every member shares the same branch (the supervisor's case),
  /// surface that branch's name in the header instead of repeating it on
  /// every row. Admin's multi-branch view falls back to a plain title.
  String? get _singleBranchName {
    if (_members.isEmpty) return null;
    final ids = _members.map((m) => m['branch_id']).toSet();
    if (ids.length == 1 && _members.first['branch_name'] != null) {
      return _members.first['branch_name'];
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final branchName = _singleBranchName;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: Text(branchName != null ? '$branchName — Today' : "Today's Attendance")),
      body: SafeArea(
        child: RefreshIndicator(
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
                          Center(
                            child: Text('No members yet', style: Theme.of(context).textTheme.bodyMedium),
                          ),
                        ])
                      : ListView.separated(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          itemCount: _members.length,
                          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (context, index) {
                            final m = _members[index];
                            final name = '${m['first_name'] ?? ''} ${m['last_name'] ?? ''}'.trim();
                            return _MemberStatusTile(
                              name: name.isEmpty ? '(no name)' : name,
                              photoPath: m['photo_path'],
                              branchName: branchName == null ? m['branch_name'] : null,
                              note: m['note'],
                              status: m['status'] ?? 'unscheduled',
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => CalendarScreen(
                                    memberId: m['member_id'] as int,
                                    memberName: name.isEmpty ? 'Member' : name,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
        ),
      ),
    );
  }
}

class _MemberStatusTile extends StatelessWidget {
  final String name;
  final String? photoPath;
  final String? branchName;
  final String? note;
  final String status;
  final VoidCallback onTap;

  const _MemberStatusTile({
    required this.name,
    required this.photoPath,
    required this.branchName,
    required this.note,
    required this.status,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final style = statusStyle(status);
    final subtitle = [
      if (branchName != null) branchName!,
      if (note != null && note!.isNotEmpty) note!,
    ].join(' · ');

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
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                backgroundImage: photoPath != null
                    ? NetworkImage('https://attendance.logoninvoice.com/storage/$photoPath')
                    : null,
                child: photoPath == null
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                      )
                    : null,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: Theme.of(context).textTheme.titleSmall),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: style.soft, borderRadius: BorderRadius.circular(AppRadius.pill)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(style.icon, size: 13, color: style.color),
                    const SizedBox(width: 4),
                    Text(style.label,
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: style.color)),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}