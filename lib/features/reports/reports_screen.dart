import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart' show SharePlus, ShareParams;
import '../../core/services/api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/api_error.dart';
import '../../shared/attendance_status.dart';
import '../../shared/date_format.dart';
import 'report_member_screen.dart';

/// Attendance summary for a date range, for admins and managers.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _api = ApiService();

  late DateTime _from;
  late DateTime _to;
  String _preset = 'month';
  int? _branchId;
  bool _includeInactive = false;

  bool _loading = true;
  bool _exporting = false;
  String? _error;
  Map<String, dynamic>? _data;
  List<dynamic> _branches = [];

  @override
  void initState() {
    super.initState();
    _applyPreset('month', reload: false);
    _loadBranches();
    _load();
  }

  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  void _applyPreset(String preset, {bool reload = true}) {
    final today = _today;
    setState(() {
      _preset = preset;
      switch (preset) {
        case 'week':
          _from = today.subtract(const Duration(days: 6));
          _to = today;
        case 'last_month':
          _from = DateTime(today.year, today.month - 1, 1);
          _to = DateTime(today.year, today.month, 0);
        default:
          _from = DateTime(today.year, today.month, 1);
          _to = today;
      }
    });
    if (reload) _load();
  }

  Future<void> _pickCustom() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: _today,
      initialDateRange: DateTimeRange(start: _from, end: _to),
    );
    if (picked == null) return;
    setState(() {
      _preset = 'custom';
      _from = picked.start;
      _to = picked.end;
    });
    _load();
  }

  Future<void> _loadBranches() async {
    try {
      final branches = await _api.getBranches();
      if (mounted) setState(() => _branches = branches);
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _api.getReportSummary(
        from: dateParam(_from),
        to: dateParam(_to),
        branchId: _branchId,
        includeInactive: _includeInactive,
      );
      if (mounted) setState(() => _data = data);
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(e, fallback: 'Could not load the report'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _export(String group) async {
    setState(() => _exporting = true);
    try {
      final from = dateParam(_from);
      final to = dateParam(_to);
      final bytes = await _api.exportReportCsv(
        from: from,
        to: to,
        group: group,
        branchId: _branchId,
        includeInactive: _includeInactive,
      );
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/attendance-$group-$from-to-$to.csv');
      await file.writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path, mimeType: 'text/csv')], text: 'Attendance report $from to $to'),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(e, fallback: 'Could not export the report'))),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          if (_exporting)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            PopupMenuButton<String>(
              tooltip: 'Export CSV',
              icon: const Icon(Icons.ios_share_rounded),
              onSelected: _export,
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'member', child: Text('Export by member')),
                PopupMenuItem(value: 'branch', child: Text('Export by branch')),
                PopupMenuItem(value: 'daily', child: Text('Export daily log')),
              ],
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            _buildFilters(context),
            const SizedBox(height: AppSpacing.md),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: AppSpacing.xl),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xl),
                child: Center(child: Text(_error!, style: Theme.of(context).textTheme.bodyMedium)),
              )
            else if (_data != null)
              ..._buildReport(context, _data!),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters(BuildContext context) {
    Widget chip(String value, String label, VoidCallback onTap) => ChoiceChip(
          label: Text(label),
          selected: _preset == value,
          onSelected: (_) => onTap(),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            chip('month', 'This month', () => _applyPreset('month')),
            chip('week', 'Last 7 days', () => _applyPreset('week')),
            chip('last_month', 'Last month', () => _applyPreset('last_month')),
            chip('custom', 'Custom', _pickCustom),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '${prettyDate(dateParam(_from))} – ${prettyDate(dateParam(_to))}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (_branches.length > 1) ...[
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<int?>(
            initialValue: _branchId,
            decoration: const InputDecoration(labelText: 'Branch', isDense: true),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('All branches')),
              for (final b in _branches) DropdownMenuItem<int?>(value: b['id'] as int, child: Text(b['name'] ?? '')),
            ],
            onChanged: (v) {
              setState(() => _branchId = v);
              _load();
            },
          ),
        ],
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: const Text('Include inactive members', style: TextStyle(fontSize: 13)),
          value: _includeInactive,
          activeThumbColor: AppColors.primary,
          onChanged: (v) {
            setState(() => _includeInactive = v);
            _load();
          },
        ),
      ],
    );
  }

  List<Widget> _buildReport(BuildContext context, Map<String, dynamic> data) {
    final totals = data['totals'] as Map<String, dynamic>;
    final byBranch = (data['by_branch'] as List).cast<Map<String, dynamic>>();
    final byMember = (data['by_member'] as List).cast<Map<String, dynamic>>();
    final rate = totals['attendance_rate'];

    const counted = ['present', 'late', 'half_day', 'absent', 'leave', 'day_off', 'incomplete'];

    return [
      // Headline: attendance rate and hours.
      Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          gradient: AppGradients.brand,
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Attendance rate', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(
                    rate == null ? '—' : '$rate%',
                    style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${totals['member_count']} people',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('${totals['hours_worked']} h worked',
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final key in counted) _CountChip(status: key, count: (totals[key] ?? 0) as int),
        ],
      ),
      if (byBranch.length > 1) ...[
        const SizedBox(height: AppSpacing.lg),
        Text('By branch', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        for (final b in byBranch)
          _SummaryRow(
            title: b['branch_name'] ?? 'No branch',
            subtitle: '${b['member_count']} people · ${b['present']} present · ${b['late']} late · ${b['absent']} absent',
            rate: b['attendance_rate'],
          ),
      ],
      const SizedBox(height: AppSpacing.lg),
      Text('By person', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: AppSpacing.sm),
      if (byMember.isEmpty)
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Center(child: Text('No one to report on', style: Theme.of(context).textTheme.bodyMedium)),
        )
      else
        for (final m in byMember)
          _SummaryRow(
            title: m['name'] ?? '',
            subtitle:
                '${m['branch_name'] ?? 'No branch'} · ${m['present']} present · ${m['late']} late · ${m['absent']} absent',
            rate: m['attendance_rate'],
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ReportMemberScreen(
                  memberId: m['member_id'] as int,
                  memberName: m['name'] ?? 'Member',
                  from: dateParam(_from),
                  to: dateParam(_to),
                ),
              ),
            ),
          ),
      const SizedBox(height: AppSpacing.xl),
    ];
  }
}

class _CountChip extends StatelessWidget {
  final String status;
  final int count;
  const _CountChip({required this.status, required this.count});

  @override
  Widget build(BuildContext context) {
    final style = statusStyle(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: style.soft,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 15, color: style.color),
          const SizedBox(width: 6),
          Text('$count', style: TextStyle(color: style.color, fontWeight: FontWeight.w800)),
          const SizedBox(width: 4),
          Text(style.label, style: TextStyle(color: style.color, fontSize: 12)),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final dynamic rate;
  final VoidCallback? onTap;

  const _SummaryRow({required this.title, required this.subtitle, required this.rate, this.onTap});

  @override
  Widget build(BuildContext context) {
    final value = rate is num ? (rate as num).toDouble() : null;
    final color = value == null
        ? AppColors.textMuted
        : value >= 90
            ? AppColors.success
            : value >= 75
                ? AppColors.warning
                : AppColors.danger;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 2),
                      Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  value == null ? '—' : '${value.toStringAsFixed(value % 1 == 0 ? 0 : 1)}%',
                  style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 16),
                ),
                if (onTap != null) const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}