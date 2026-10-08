import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/services/api_service.dart';
import '../../core/utils/responsive.dart';
import '../../core/theme/app_theme.dart';

class JoinCodeScreen extends StatefulWidget {
  const JoinCodeScreen({super.key});

  @override
  State<JoinCodeScreen> createState() => _JoinCodeScreenState();
}

class _JoinCodeScreenState extends State<JoinCodeScreen> {
  final _api = ApiService();
  Map<String, dynamic>? _company;
  List<dynamic> _invites = [];
  List<dynamic> _branches = [];
  bool _loading = true;
  bool _savingSelfieSetting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([_api.getCompany(), _api.getInvites(), _api.getBranches()]);
      setState(() {
        _company = results[0] as Map<String, dynamic>;
        _invites = results[1] as List<dynamic>;
        _branches = results[2] as List<dynamic>;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load join code / invites')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toggleRequireSelfie(bool value) async {
    setState(() => _savingSelfieSetting = true);
    try {
      await _api.updateCompanySettings(requireSelfieOnJoin: value);
      setState(() => _company?['require_selfie_on_join'] = value);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update that setting')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingSelfieSetting = false);
    }
  }

  void _copyJoinCode() {
    final code = _company?['join_code'];
    if (code == null) return;
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Join code copied')),
    );
  }

  void _openRegenerateDialog() async {
    final expiresController = TextEditingController();
    final maxUsesController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Join Code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This replaces the current code — anyone with the old one won\'t be able to use it.'),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: expiresController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Expires after (days, optional)',
                prefixIcon: Icon(Icons.event_outlined),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: maxUsesController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Max uses (optional)',
                prefixIcon: Icon(Icons.people_outline),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Generate')),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _api.regenerateJoinCode(
        expiresInDays: int.tryParse(expiresController.text),
        maxUses: int.tryParse(maxUsesController.text),
      );
      _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not regenerate the code')),
        );
      }
    }
  }

  void _openInviteDialog() async {
    final emailController = TextEditingController();
    final expiresController = TextEditingController(text: '7');
    String role = 'member';
    int? branchId = _branches.isNotEmpty ? _branches.first['id'] as int : null;
    String? branchError;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Invite by Email'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email address',
                    prefixIcon: Icon(Icons.mail_outline_rounded),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: const [
                    DropdownMenuItem(value: 'member', child: Text('Member')),
                    DropdownMenuItem(value: 'supervisor', child: Text('Supervisor')),
                  ],
                  onChanged: (v) => setDialogState(() => role = v ?? 'member'),
                ),
                const SizedBox(height: AppSpacing.sm),
                DropdownButtonFormField<int>(
                  initialValue: branchId,
                  decoration: InputDecoration(
                    labelText: 'Branch',
                    errorText: branchError,
                  ),
                  items: _branches
                      .map<DropdownMenuItem<int>>((b) => DropdownMenuItem(
                            value: b['id'] as int,
                            child: Text(b['name'] ?? 'Branch'),
                          ))
                      .toList(),
                  onChanged: (v) => setDialogState(() {
                    branchId = v;
                    branchError = null;
                  }),
                ),
                if (_branches.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'No branches yet — create one first under Manage Branches.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: expiresController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Expires after (days)',
                    prefixIcon: Icon(Icons.event_outlined),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'This creates a link but doesn\'t send an email yet — copy the token and share it yourself for now.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (branchId == null) {
                  setDialogState(() => branchError = 'A branch is required');
                  return;
                }
                Navigator.pop(context, true);
              },
              child: const Text('Create Invite'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || emailController.text.isEmpty) return;

    try {
      final result = await _api.createInvite(
        email: emailController.text,
        role: role,
        branchId: branchId,
        expiresInDays: int.tryParse(expiresController.text),
      );
      _load();
      if (!mounted) return;
      _showTokenDialog(result['token']);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not create the invite')),
        );
      }
    }
  }

  void _showTokenDialog(String token) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Invite Created'),
        content: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: SelectableText(token, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copy'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: token));
              Navigator.pop(context);
            },
          ),
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
        ],
      ),
    );
  }

  void _revokeInvite(int id) async {
    try {
      await _api.revokeInvite(id);
      _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not revoke that invite')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Join Code & Invites')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                      maxWidth: Responsive.isDesktop(context) ? 700 : double.infinity),
                  child: ListView(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    children: [
                      _JoinCodeCard(
                        code: _company?['join_code'] ?? '—',
                        subtitle: _joinCodeSubtitle(),
                        onCopy: _copyJoinCode,
                        onRegenerate: _openRegenerateDialog,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceCard,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
                          title: const Text('Require selfie to join'),
                          subtitle: const Text(
                            'Off if your members genuinely can\'t take one — attendance is harder to trust without it.',
                          ),
                          activeThumbColor: AppColors.primary,
                          value: _company?['require_selfie_on_join'] ?? true,
                          onChanged: _savingSelfieSetting ? null : _toggleRequireSelfie,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        children: [
                          Text('Email Invites', style: Theme.of(context).textTheme.titleMedium),
                          const Spacer(),
                          TextButton.icon(
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('New Invite'),
                            onPressed: _openInviteDialog,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      if (_invites.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                          child: Center(
                            child: Text(
                              'No invites yet',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        )
                      else
                        ..._invites.map((invite) => Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                              child: _InviteCard(
                                email: invite['email'] ?? '',
                                role: invite['role'] ?? 'member',
                                accepted: invite['used_at'] != null,
                                statusText: _inviteStatus(invite),
                                onRevoke: invite['used_at'] == null ? () => _revokeInvite(invite['id']) : null,
                              ),
                            )),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  String _joinCodeSubtitle() {
    if (_company == null) return '';
    final parts = <String>[];
    final maxUses = _company!['join_code_max_uses'];
    final usesCount = _company!['join_code_uses_count'] ?? 0;
    final expiresAt = _company!['join_code_expires_at'];

    parts.add(maxUses != null ? '$usesCount / $maxUses used' : '$usesCount used, no limit');
    parts.add(expiresAt != null ? 'expires $expiresAt' : 'never expires');

    return parts.join(' • ');
  }

  String _inviteStatus(Map invite) {
    if (invite['used_at'] != null) return 'Accepted';
    return 'Pending — expires ${invite['expires_at']}';
  }
}

/// Hero card showing the company join code in large, letter-spaced,
/// copyable text on a brand gradient background.
class _JoinCodeCard extends StatelessWidget {
  final String code;
  final String subtitle;
  final VoidCallback onCopy;
  final VoidCallback onRegenerate;

  const _JoinCodeCard({
    required this.code,
    required this.subtitle,
    required this.onCopy,
    required this.onRegenerate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: AppGradients.brand,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [
          BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Join Code', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  code,
                  style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: 6),
                ),
              ),
              IconButton(
                onPressed: onCopy,
                icon: const Icon(Icons.copy_rounded, color: Colors.white),
                style: IconButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.16)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            label: const Text('Generate New Code', style: TextStyle(color: Colors.white)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.white54),
              minimumSize: const Size.fromHeight(46),
            ),
            onPressed: onRegenerate,
          ),
        ],
      ),
    );
  }
}

class _InviteCard extends StatelessWidget {
  final String email;
  final String role;
  final bool accepted;
  final String statusText;
  final VoidCallback? onRevoke;

  const _InviteCard({
    required this.email,
    required this.role,
    required this.accepted,
    required this.statusText,
    required this.onRevoke,
  });

  String get _roleLabel {
    switch (role) {
      case 'supervisor':
        return 'Supervisor';
      case 'admin':
        return 'Admin';
      default:
        return 'Member';
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = accepted ? AppColors.success : AppColors.info;
    final Color accentBg = accepted ? AppColors.successSoft : AppColors.infoSoft;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: accentBg, borderRadius: BorderRadius.circular(AppRadius.sm)),
            child: Icon(
              accepted ? Icons.check_circle_rounded : Icons.schedule_rounded,
              size: 22,
              color: accent,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(email, style: Theme.of(context).textTheme.titleSmall)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        _roleLabel,
                        style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(statusText, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          if (onRevoke != null)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
              onPressed: onRevoke,
            ),
        ],
      ),
    );
  }
}