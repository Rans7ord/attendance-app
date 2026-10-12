import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/api_error.dart';
import '../../shared/attendance_status.dart';
import '../../shared/date_format.dart';

/// One person's attendance for a date range, day by day.
class ReportMemberScreen extends StatefulWidget {
  final int memberId;
  final String memberName;
  final String from; // YYYY-MM-DD
  final String to; // YYYY-MM-DD

  const ReportMemberScreen({
    super.key,
    required this.memberId,
    required this.memberName,
    required this.from,
    required this.to,
  });

  @override
  State<ReportMemberScreen> createState() => _ReportMemberScreenState();
}

class _ReportMemberScreenState extends State<ReportMemberScreen> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _member;
  List<dynamic> _days = [];

  // Days that carry no information for a report: don't list them.
  static const _hidden = {'closed', 'unscheduled', 'upcoming'};

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
      final data = await _api.getMemberReport(widget.memberId, from: widget.from, to: widget.to);
      if (!mounted) return;
      setState(() {
        _member = data['member'] as Map<String, dynamic>;
        _days = (data['days'] as List).where((d) => !_hidden.contains(d['status'])).toList().reversed.toList();
      });
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(e, fallback: 'Could not load this report'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: Text(widget.memberName)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(children: [
                    const SizedBox(height: AppSpacing.xl),
                    Center(child: Text(_error!, style: Theme.of(context).textTheme.bodyMedium)),
                  ])
                : ListView(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    children: [
                      Text(
                        '${prettyDate(widget.from)} – ${prettyDate(widget.to)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      if (_member != null) _buildTotals(_member!),
                      const SizedBox(height: AppSpacing.md),
                      if (_days.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Center(
                            child: Text('No attendance days in this range',
                                style: Theme.of(context).textTheme.bodyMedium),
                          ),
                        )
                      else
                        for (final d in _days) _DayRow(day: d as Map<String, dynamic>),
                    ],
                  ),
      ),
    );
  }

  Widget _buildTotals(Map<String, dynamic> m) {
    const keys = ['present', 'late', 'half_day', 'absent', 'leave', 'day_off', 'incomplete'];
    final rate = m['attendance_rate'];

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
                  rate == null ? 'No expected days yet' : 'Attendance rate: $rate%',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text('${m['hours_worked']} h', style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              for (final k in keys)
                if (((m[k] ?? 0) as int) > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: statusStyle(k).soft,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      '${m[k]} ${statusStyle(k).label}',
                      style: TextStyle(color: statusStyle(k).color, fontWeight: FontWeight.w700, fontSize: 11.5),
                    ),
                  ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  final Map<String, dynamic> day;
  const _DayRow({required this.day});

  @override
  Widget build(BuildContext context) {
    final style = statusStyle(day['status'] ?? 'unscheduled');
    final clockIn = day['clock_in'] as String?;
    final clockOut = day['clock_out'] as String?;
    final note = day['note'] as String?;
    final incomplete = day['incomplete'] == true;

    final details = <String>[
      if (clockIn != null) 'In $clockIn',
      if (clockOut != null) 'Out $clockOut',
      if (day['hours'] != null) '${day['hours']} h',
      if (incomplete) 'No clock-out',
      if (note != null && note.isNotEmpty) note,
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(prettyDate(day['date']), style: Theme.of(context).textTheme.titleSmall),
                  if (details.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(details.join(' · '), style: Theme.of(context).textTheme.bodySmall),
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
          ],
        ),
      ),
    );
  }
}