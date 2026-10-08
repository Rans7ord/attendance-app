import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/utils/responsive.dart';
import '../../core/theme/app_theme.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  State<AttendanceHistoryScreen> createState() => _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  final _api = ApiService();
  List<dynamic> _records = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _api.getAttendanceHistory();
      setState(() {
        _records = data;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not load attendance history';
        _loading = false;
      });
    }
  }

  String _formatDateTime(String? raw) {
    if (raw == null) return '—';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    return '${dt.day}/${dt.month}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String? _formatDuration(String? inRaw, String? outRaw) {
    if (inRaw == null || outRaw == null) return null;
    final start = DateTime.tryParse(inRaw);
    final end = DateTime.tryParse(outRaw);
    if (start == null || end == null) return null;
    final diff = end.difference(start);
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    return '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Attendance History')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorState(message: _error!, onRetry: _load)
                : _records.isEmpty
                    ? const _EmptyState()
                    : Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                              maxWidth: Responsive.isDesktop(context) ? 700 : double.infinity),
                          child: ListView.separated(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            itemCount: _records.length,
                            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                            itemBuilder: (context, index) {
                              final r = _records[index];
                              final stillIn = r['clock_out'] == null;
                              return _RecordCard(
                                clockIn: _formatDateTime(r['clock_in']),
                                clockOut: stillIn ? null : _formatDateTime(r['clock_out']),
                                duration: _formatDuration(r['clock_in'], r['clock_out']),
                                status: r['status'] ?? (stillIn ? 'In progress' : 'present'),
                                stillIn: stillIn,
                              );
                            },
                          ),
                        ),
                      ),
      ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  final String clockIn;
  final String? clockOut;
  final String? duration;
  final String status;
  final bool stillIn;

  const _RecordCard({
    required this.clockIn,
    required this.clockOut,
    required this.duration,
    required this.status,
    required this.stillIn,
  });

  @override
  Widget build(BuildContext context) {
    final Color accent = stillIn ? AppColors.warning : AppColors.success;
    final Color accentBg = stillIn ? AppColors.warningSoft : AppColors.successSoft;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: accentBg, borderRadius: BorderRadius.circular(AppRadius.sm)),
            child: Icon(
              stillIn ? Icons.timelapse_rounded : Icons.check_circle_rounded,
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text('In: $clockIn', style: Theme.of(context).textTheme.titleSmall),
                    ),
                    _StatusChip(label: stillIn ? 'Still in' : status, color: accent, bg: accentBg),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  clockOut != null ? 'Out: $clockOut' : 'Still clocked in',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (duration != null) ...[
                  const SizedBox(height: 4),
                  Text('Duration: $duration', style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;

  const _StatusChip({required this.label, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11.5),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
              child: const Icon(Icons.event_note_rounded, size: 38, color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('No attendance records yet', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Your clock-ins will show up here',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(color: AppColors.dangerSoft, shape: BoxShape.circle),
              child: const Icon(Icons.wifi_off_rounded, size: 38, color: AppColors.danger),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(message, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}