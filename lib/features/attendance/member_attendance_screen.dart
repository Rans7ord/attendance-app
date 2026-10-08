import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_theme.dart';

class MemberAttendanceScreen extends StatefulWidget {
  final int memberId;
  final String memberName;

  const MemberAttendanceScreen({super.key, required this.memberId, required this.memberName});

  @override
  State<MemberAttendanceScreen> createState() => _MemberAttendanceScreenState();
}

class _MemberAttendanceScreenState extends State<MemberAttendanceScreen> {
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
      final data = await _api.getMemberAttendance(widget.memberId);
      setState(() => _records = data);
    } catch (_) {
      setState(() => _error = 'Could not load attendance for this person');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatDateTime(String? raw) {
    if (raw == null) return '—';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    return '${dt.day}/${dt.month}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
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
                : _records.isEmpty
                    ? ListView(children: [
                        const SizedBox(height: AppSpacing.xl),
                        Center(
                          child: Text('No attendance records yet', style: Theme.of(context).textTheme.bodyMedium),
                        ),
                      ])
                    : ListView.separated(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        itemCount: _records.length,
                        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, index) {
                          final r = _records[index];
                          final stillIn = r['clock_out'] == null;
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
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('In: ${_formatDateTime(r['clock_in'])}',
                                        style: Theme.of(context).textTheme.titleSmall),
                                    _StatusChip(status: stillIn ? 'open' : (r['status'] ?? 'present')),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  stillIn ? 'Still clocked in' : 'Out: ${_formatDateTime(r['clock_out'])}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, bg, label) = _style(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11.5)),
    );
  }

  (Color, Color, String) _style(String status) {
    switch (status) {
      case 'late':
        return (AppColors.warning, AppColors.warningSoft, 'Late');
      case 'open':
        return (AppColors.info, AppColors.infoSoft, 'Still in');
      default:
        return (AppColors.success, AppColors.successSoft, 'Present');
    }
  }
}