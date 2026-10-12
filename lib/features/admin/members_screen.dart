import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/api_error.dart';
import '../attendance/calendar_screen.dart';

class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  final _api = ApiService();
  bool _loading = true;
  bool _isAdmin = false;
  String? _error;
  List<dynamic> _members = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final role = await _api.getRole();
    if (mounted) setState(() => _isAdmin = role == 'admin' || role == 'super_admin');
    await _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _api.getMembers();
      if (mounted) setState(() => _members = data);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load members — pull down to retry');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _nameOf(Map<String, dynamic> m) {
    final name = '${m['first_name'] ?? ''} ${m['last_name'] ?? ''}'.trim();
    return name.isEmpty ? '(no name)' : name;
  }

  // ---- Actions (admin only) ----

  Future<void> _changeRole(Map<String, dynamic> m) async {
    List<dynamic> branches;
    try {
      branches = await _api.getBranches();
    } catch (e) {
      if (mounted) _toast(apiErrorMessage(e));
      return;
    }
    if (!mounted) return;

    final currentRole = m['role'] as String?;
    final choice = await showDialog<(String, int?)>(
      context: context,
      builder: (_) => _RoleDialog(
        name: _nameOf(m),
        currentRole: currentRole,
        currentBranchId: m['branch_id'] as int?,
        branches: branches,
      ),
    );
    if (choice == null) return;

    final (role, branchId) = choice;
    try {
      await _api.updateMemberRole(m['id'] as int, role, branchId: branchId);
      if (!mounted) return;
      _toast('${_nameOf(m)} is now ${_roleLabel(role)}');
      _load();
    } catch (e) {
      if (mounted) _toast(apiErrorMessage(e));
    }
  }

  Future<void> _setActive(Map<String, dynamic> m, {required bool active}) async {
    if (!active) {
      final confirmed = await _confirm(
        title: 'Deactivate ${_nameOf(m)}?',
        message: 'They will be signed out and unable to log in or clock in. '
            'Their attendance history stays intact. You can reactivate them later.',
        action: 'Deactivate',
        destructive: true,
      );
      if (!confirmed) return;
    }

    try {
      if (active) {
        await _api.reactivateMember(m['id'] as int);
      } else {
        await _api.deactivateMember(m['id'] as int);
      }
      if (!mounted) return;
      _toast(active ? '${_nameOf(m)} reactivated' : '${_nameOf(m)} deactivated');
      _load();
    } catch (e) {
      if (mounted) _toast(apiErrorMessage(e));
    }
  }

  Future<void> _delete(Map<String, dynamic> m) async {
    final confirmed = await _confirm(
      title: 'Delete ${_nameOf(m)}?',
      message: 'This permanently removes them and cannot be undone. '
          'It only works for people with no attendance or leave history — '
          'otherwise deactivate them instead.',
      action: 'Delete',
      destructive: true,
    );
    if (!confirmed) return;

    try {
      await _api.deleteMember(m['id'] as int);
      if (!mounted) return;
      _toast('${_nameOf(m)} deleted');
      _load();
    } catch (e) {
      if (mounted) _toast(apiErrorMessage(e));
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String action,
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(
            style: destructive ? FilledButton.styleFrom(backgroundColor: AppColors.danger) : null,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
    return result == true;
  }

  void _openCalendar(Map<String, dynamic> m) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CalendarScreen(
          memberId: m['id'] as int,
          memberName: _nameOf(m) == '(no name)' ? 'Member' : _nameOf(m),
        ),
      ),
    );
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
                          final active = m['status'] != 'inactive';
                          final hasAccount = m['role'] != null;
                          return _MemberRow(
                            name: _nameOf(m),
                            photoPath: m['photo_path'],
                            role: m['role'],
                            branchName: m['branch']?['name'],
                            active: active,
                            onTap: () => _openCalendar(m),
                            menu: _isAdmin
                                ? PopupMenuButton<String>(
                                    onSelected: (v) {
                                      switch (v) {
                                        case 'calendar':
                                          _openCalendar(m);
                                        case 'role':
                                          _changeRole(m);
                                        case 'deactivate':
                                          _setActive(m, active: false);
                                        case 'reactivate':
                                          _setActive(m, active: true);
                                        case 'delete':
                                          _delete(m);
                                      }
                                    },
                                    itemBuilder: (_) => [
                                      const PopupMenuItem(value: 'calendar', child: Text('View calendar')),
                                      if (hasAccount)
                                        const PopupMenuItem(value: 'role', child: Text('Change role')),
                                      if (active)
                                        const PopupMenuItem(value: 'deactivate', child: Text('Deactivate'))
                                      else
                                        const PopupMenuItem(value: 'reactivate', child: Text('Reactivate')),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Text('Delete', style: TextStyle(color: AppColors.danger)),
                                      ),
                                    ],
                                  )
                                : null,
                          );
                        },
                      ),
      ),
    );
  }
}

String _roleLabel(String? role) {
  switch (role) {
    case 'admin':
    case 'super_admin':
      return 'Admin';
    case 'manager':
      return 'Manager';
    case 'supervisor':
      return 'Supervisor';
    case 'member':
      return 'Member';
    default:
      return 'No account';
  }
}

class _RoleDialog extends StatefulWidget {
  final String name;
  final String? currentRole;
  final int? currentBranchId;
  final List<dynamic> branches;

  const _RoleDialog({
    required this.name,
    required this.currentRole,
    required this.currentBranchId,
    required this.branches,
  });

  @override
  State<_RoleDialog> createState() => _RoleDialogState();
}

class _RoleDialogState extends State<_RoleDialog> {
  static const _roles = ['member', 'supervisor', 'manager', 'admin'];
  late String _role;
  int? _branchId;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Start on a role different from the current one.
    _role = _roles.firstWhere((r) => r != widget.currentRole, orElse: () => 'member');
    final hasBranch = widget.branches.any((b) => b['id'] == widget.currentBranchId);
    _branchId = hasBranch ? widget.currentBranchId : null;
  }

  bool get _needsBranch => _role == 'member' || _role == 'supervisor';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Change role for ${widget.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Currently ${_roleLabel(widget.currentRole)}. Changing a role changes what they can see and do straight away.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<String>(
            initialValue: _role,
            decoration: const InputDecoration(labelText: 'New role'),
            items: [
              for (final r in _roles)
                if (r != widget.currentRole) DropdownMenuItem(value: r, child: Text(_roleLabel(r))),
            ],
            onChanged: (v) => setState(() {
              _role = v ?? _role;
              _error = null;
            }),
          ),
          if (_needsBranch) ...[
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<int>(
              initialValue: _branchId,
              decoration: const InputDecoration(labelText: 'Branch'),
              items: [
                for (final b in widget.branches)
                  DropdownMenuItem<int>(value: b['id'] as int, child: Text(b['name'] ?? '')),
              ],
              onChanged: (v) => setState(() {
                _branchId = v;
                _error = null;
              }),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12.5)),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (_needsBranch && _branchId == null) {
              setState(() => _error = 'Choose a branch');
              return;
            }
            Navigator.of(context).pop((_role, _needsBranch ? _branchId : null));
          },
          child: const Text('Change role'),
        ),
      ],
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
  final Widget? menu;

  const _MemberRow({
    required this.name,
    required this.photoPath,
    required this.role,
    required this.branchName,
    required this.active,
    required this.onTap,
    this.menu,
  });

  (Color, String) get _roleStyle {
    switch (role) {
      case 'admin':
      case 'super_admin':
        return (AppColors.warning, 'Admin');
      case 'manager':
        return (AppColors.accent, 'Manager');
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
          padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, menu == null ? AppSpacing.md : AppSpacing.xs, AppSpacing.md),
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
                        Flexible(child: Text(name, style: Theme.of(context).textTheme.titleSmall)),
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
              if (menu != null) menu!,
            ],
          ),
        ),
      ),
    );
  }
}