import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/api_error.dart';
import '../../shared/date_format.dart';

/// The logged-in person's own leave: their requests (with a form to make a
/// new one) and the upcoming days off that apply to them.
class LeaveScreen extends StatefulWidget {
  const LeaveScreen({super.key});

  @override
  State<LeaveScreen> createState() => _LeaveScreenState();
}

class _LeaveScreenState extends State<LeaveScreen> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;
  List<dynamic> _leave = [];
  List<dynamic> _daysOff = [];

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
      final leave = await _api.getMyLeave();
      final daysOff = await _api.getMyDaysOff();
      if (!mounted) return;
      setState(() {
        _leave = leave;
        _daysOff = daysOff;
      });
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(e, fallback: 'Could not load your leave'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openRequestForm() async {
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _RequestSheet(),
    );
    if (sent == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Leave request sent')),
      );
      _load();
    }
  }

  bool _canCancel(Map<String, dynamic> leave) {
    final status = leave['status'];
    if (status == 'pending') return true;
    if (status == 'approved') {
      final end = leave['end_date'] as String?;
      return end != null && end.compareTo(dateParam(DateTime.now())) >= 0;
    }
    return false;
  }

  Future<void> _cancel(Map<String, dynamic> leave) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this request?'),
        content: Text(
          leave['status'] == 'approved'
              ? 'This leave is already approved. Cancelling it means you will be expected at work on those days.'
              : 'Your request will be withdrawn.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Keep it')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Cancel request')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _api.cancelLeave(leave['id'] as int);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request cancelled')));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          title: const Text('My Leave'),
          bottom: const TabBar(
            tabs: [Tab(text: 'My requests'), Tab(text: 'Days off')],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _openRequestForm,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Request leave'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(children: [
                      const SizedBox(height: AppSpacing.xl),
                      Center(child: Text(_error!, style: Theme.of(context).textTheme.bodyMedium)),
                    ]),
                  )
                : TabBarView(
                    children: [
                      _buildRequests(context),
                      _buildDaysOff(context),
                    ],
                  ),
      ),
    );
  }

  Widget _buildRequests(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: _leave.isEmpty
          ? ListView(children: [
              const SizedBox(height: AppSpacing.xl),
              Center(child: Text('No leave requests yet', style: Theme.of(context).textTheme.bodyMedium)),
            ])
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 96),
              itemCount: _leave.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, i) {
                final leave = _leave[i] as Map<String, dynamic>;
                return _LeaveCard(
                  leave: leave,
                  onCancel: _canCancel(leave) ? () => _cancel(leave) : null,
                );
              },
            ),
    );
  }

  Widget _buildDaysOff(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: _daysOff.isEmpty
          ? ListView(children: [
              const SizedBox(height: AppSpacing.xl),
              Center(child: Text('No upcoming days off', style: Theme.of(context).textTheme.bodyMedium)),
            ])
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 96),
              itemCount: _daysOff.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, i) {
                final off = _daysOff[i] as Map<String, dynamic>;
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
                        decoration: BoxDecoration(
                          color: AppColors.infoSoft,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: const Icon(Icons.celebration_rounded, color: AppColors.info),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(off['title'] ?? 'Day off', style: Theme.of(context).textTheme.titleSmall),
                            const SizedBox(height: 2),
                            Text(
                              '${dayOffKindLabel(off['kind'])} · ${prettyRange(off['start_date'], off['end_date'])}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

/// Shared label for a day off's kind (also used by the admin screen).
String dayOffKindLabel(String? kind) {
  switch (kind) {
    case 'holiday':
      return 'Holiday';
    case 'break':
      return 'Short break';
    case 'closure':
      return 'Closure';
    default:
      return 'Day off';
  }
}

/// Colours and label for a leave request's status.
(Color, Color, String) leaveStatusStyle(String? status) {
  switch (status) {
    case 'approved':
      return (AppColors.success, AppColors.successSoft, 'Approved');
    case 'rejected':
      return (AppColors.danger, AppColors.dangerSoft, 'Rejected');
    case 'cancelled':
      return (AppColors.textMuted, AppColors.surface, 'Cancelled');
    default:
      return (AppColors.warning, AppColors.warningSoft, 'Pending');
  }
}

class _LeaveCard extends StatelessWidget {
  final Map<String, dynamic> leave;
  final VoidCallback? onCancel;

  const _LeaveCard({required this.leave, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final (color, soft, label) = leaveStatusStyle(leave['status']);
    final isHalf = leave['type'] == 'half_day';
    final note = leave['review_note'] as String?;

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
              Expanded(
                child: Text(
                  prettyRange(leave['start_date'], leave['end_date']),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(AppRadius.pill)),
                child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11.5)),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(isHalf ? 'Half day' : 'Full day', style: Theme.of(context).textTheme.bodySmall),
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
              child: Text('Reviewer: $note', style: const TextStyle(fontSize: 12.5)),
            ),
          ],
          if (onCancel != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: onCancel, child: const Text('Cancel request')),
            ),
          ],
        ],
      ),
    );
  }
}

class _RequestSheet extends StatefulWidget {
  const _RequestSheet();

  @override
  State<_RequestSheet> createState() => _RequestSheetState();
}

class _RequestSheetState extends State<_RequestSheet> {
  final _api = ApiService();
  final _reason = TextEditingController();
  late final DateTime _today;
  String _type = 'full_day';
  late DateTime _start;
  DateTime? _end;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _today = DateTime(now.year, now.month, now.day);
    _start = _today;
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: _today,
      lastDate: _today.add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      _start = picked;
      if (_end != null && _end!.isBefore(_start)) _end = _start;
    });
  }

  Future<void> _pickEnd() async {
    final initial = _end ?? _start;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: _start,
      lastDate: _today.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _end = picked);
  }

  Future<void> _submit() async {
    final reason = _reason.text.trim();
    if (reason.isEmpty) {
      setState(() => _error = 'Please give a reason');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final end = _type == 'half_day' ? _start : (_end ?? _start);
      await _api.requestLeave(
        type: _type,
        startDate: dateParam(_start),
        endDate: dateParam(end),
        reason: reason,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isHalf = _type == 'half_day';

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Request leave', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'full_day', label: Text('Full day')),
                  ButtonSegment(value: 'half_day', label: Text('Half day')),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() {
                  _type = s.first;
                  if (_type == 'half_day') _end = null;
                }),
              ),
            ),
            if (isHalf) ...[
              const SizedBox(height: AppSpacing.xs),
              Text('A half day covers a single date.', style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickStart,
                    icon: const Icon(Icons.event_rounded, size: 18),
                    label: Text(isHalf ? prettyDate(dateParam(_start)) : 'From ${prettyDate(dateParam(_start))}'),
                  ),
                ),
                if (!isHalf) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickEnd,
                      icon: const Icon(Icons.event_available_rounded, size: 18),
                      label: Text('To ${prettyDate(dateParam(_end ?? _start))}'),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _reason,
              maxLength: 500,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Reason'),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12.5)),
            ],
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Send request'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}