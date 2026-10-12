import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/api_error.dart';
import '../../shared/date_format.dart';
import 'leave_screen.dart' show leaveStatusStyle;

/// Admins, managers and supervisors review leave requests here. The server
/// decides which requests each role may see and decide on.
class LeaveReviewScreen extends StatefulWidget {
  const LeaveReviewScreen({super.key});

  @override
  State<LeaveReviewScreen> createState() => _LeaveReviewScreenState();
}

class _LeaveReviewScreenState extends State<LeaveReviewScreen> {
  final _api = ApiService();
  static const _filters = [
    ('pending', 'Pending'),
    ('approved', 'Approved'),
    ('rejected', 'Rejected'),
    ('all', 'All'),
  ];

  String _status = 'pending';
  bool _loading = true;
  String? _error;
  List<dynamic> _requests = [];
  final Set<int> _busy = {};

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
      final data = await _api.getLeaveReview(status: _status);
      if (mounted) setState(() => _requests = data);
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(e, fallback: 'Could not load leave requests'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Asks for an optional note. Returns null if the dialog was dismissed,
  /// otherwise the note (possibly empty).
  Future<String?> _askNote({required String title, required String confirmLabel}) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLength: 500,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Note (optional)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  Future<void> _decide(Map<String, dynamic> leave, {required bool approve}) async {
    final note = await _askNote(
      title: approve ? 'Approve this request?' : 'Reject this request?',
      confirmLabel: approve ? 'Approve' : 'Reject',
    );
    if (note == null) return;

    final id = leave['id'] as int;
    setState(() => _busy.add(id));
    try {
      if (approve) {
        await _api.approveLeave(id, note: note);
      } else {
        await _api.rejectLeave(id, note: note);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(approve ? 'Request approved' : 'Request rejected')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Leave Requests')),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              children: [
                for (final (value, label) in _filters)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: _status == value,
                      onSelected: (_) {
                        if (_status == value) return;
                        setState(() => _status = value);
                        _load();
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? ListView(children: [
                          const SizedBox(height: AppSpacing.xl),
                          Center(child: Text(_error!, style: Theme.of(context).textTheme.bodyMedium)),
                        ])
                      : _requests.isEmpty
                          ? ListView(children: [
                              const SizedBox(height: AppSpacing.xl),
                              Center(
                                child: Text(
                                  _status == 'pending' ? 'Nothing waiting for review' : 'No requests here',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                            ])
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.xl),
                              itemCount: _requests.length,
                              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                              itemBuilder: (context, i) {
                                final leave = _requests[i] as Map<String, dynamic>;
                                final id = leave['id'] as int;
                                return _ReviewCard(
                                  leave: leave,
                                  busy: _busy.contains(id),
                                  onApprove: () => _decide(leave, approve: true),
                                  onReject: () => _decide(leave, approve: false),
                                );
                              },
                            ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final Map<String, dynamic> leave;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _ReviewCard({
    required this.leave,
    required this.busy,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final member = (leave['member'] as Map?) ?? const {};
    final name = '${member['first_name'] ?? ''} ${member['last_name'] ?? ''}'.trim();
    final (color, soft, label) = leaveStatusStyle(leave['status']);
    final isPending = leave['status'] == 'pending';
    final isHalf = leave['type'] == 'half_day';
    final note = leave['review_note'] as String?;
    final photo = member['photo_path'] as String?;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                backgroundImage:
                    photo != null ? NetworkImage('https://attendance.logoninvoice.com/storage/$photo') : null,
                child: photo == null
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
                    Text(name.isEmpty ? 'Unknown member' : name, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      '${isHalf ? 'Half day' : 'Full day'} · ${prettyRange(leave['start_date'], leave['end_date'])}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (!isPending)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(AppRadius.pill)),
                  child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11.5)),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(leave['reason'] ?? '', style: Theme.of(context).textTheme.bodyMedium),
          if (note != null && note.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text('Note: $note', style: const TextStyle(fontSize: 12.5)),
            ),
          ],
          if (isPending) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : onReject,
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton(
                    onPressed: busy ? null : onApprove,
                    child: busy
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Approve'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}