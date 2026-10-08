import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_theme.dart';
import 'member_attendance_screen.dart';

class CalendarScreen extends StatefulWidget {
  final int? memberId; // null = the logged-in user's own calendar
  final String memberName;

  const CalendarScreen({super.key, this.memberId, this.memberName = 'My Calendar'});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final _api = ApiService();
  late DateTime _month;
  bool _loading = true;
  String? _error;
  List<dynamic> _days = [];

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _load();
  }

  String get _monthParam =>
      '${_month.year.toString().padLeft(4, '0')}-${_month.month.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = widget.memberId != null
          ? await _api.getMemberCalendar(widget.memberId!, month: _monthParam)
          : await _api.getMyCalendar(month: _monthParam);
      setState(() => _days = data['days'] as List<dynamic>);
    } catch (_) {
      setState(() => _error = 'Could not load the calendar');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _changeMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
    _load();
  }

  (Color, Color, String) _style(String status) {
    switch (status) {
      case 'present':
        return (Colors.white, AppColors.success, 'Present');
      case 'late':
        return (Colors.white, AppColors.warning, 'Late');
      case 'open':
        return (Colors.white, AppColors.info, 'Clocked in');
      case 'incomplete':
        return (Colors.white, AppColors.accent, 'No clock-out');
      case 'absent':
        return (Colors.white, AppColors.danger, 'Absent');
      case 'closed':
        return (AppColors.textMuted, AppColors.surface, 'Day off');
      case 'upcoming':
        return (AppColors.textSecondary, AppColors.surfaceCard, 'Upcoming');
      case 'not_joined':
        return (AppColors.textMuted, Colors.transparent, 'Not joined yet');
      default:
        return (AppColors.textMuted, AppColors.surface, 'No schedule');
    }
  }

  String _formatTime(String raw) {
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  void _showDayDetail(Map<String, dynamic> day) {
    final (_, color, label) = _style(day['status']);
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(day['date'], style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(AppRadius.pill)),
              child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
            if (day['clock_in'] != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text('Clock in: ${_formatTime(day['clock_in'])}'),
            ],
            if (day['clock_out'] != null) ...[
              const SizedBox(height: 4),
              Text('Clock out: ${_formatTime(day['clock_out'])}'),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(widget.memberName),
        actions: [
          if (widget.memberId != null)
            IconButton(
              icon: const Icon(Icons.list_alt_rounded),
              tooltip: 'Full history',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MemberAttendanceScreen(
                    memberId: widget.memberId!,
                    memberName: widget.memberName,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: Theme.of(context).textTheme.bodyMedium))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(icon: const Icon(Icons.chevron_left_rounded), onPressed: () => _changeMonth(-1)),
                          Text(
                            '${_monthNames[_month.month - 1]} ${_month.year}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          IconButton(icon: const Icon(Icons.chevron_right_rounded), onPressed: () => _changeMonth(1)),
                        ],
                      ),
                    ),
                    Expanded(child: _buildGrid(context)),
                    _buildLegend(context),
                  ],
                ),
    );
  }

  Widget _buildGrid(BuildContext context) {
    if (_days.isEmpty) return const SizedBox.shrink();

    final firstDate = DateTime.parse(_days.first['date']);
    // DateTime.weekday: Monday = 1 ... Sunday = 7
    final leadingBlanks = firstDate.weekday - 1;
    final todayString = DateTime.now().toIso8601String().substring(0, 10);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        children: [
          Row(
            children: const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                .map((d) => Expanded(
                      child: Center(
                        child: Text(
                          d,
                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: GridView.builder(
              itemCount: leadingBlanks + _days.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
              ),
              itemBuilder: (context, index) {
                if (index < leadingBlanks) return const SizedBox.shrink();
                final day = _days[index - leadingBlanks] as Map<String, dynamic>;
                final (textColor, bg, _) = _style(day['status']);
                final dayNum = DateTime.parse(day['date']).day;
                final isToday = day['date'] == todayString;

                return InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  onTap: () => _showDayDetail(day),
                  child: Container(
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: isToday ? Border.all(color: AppColors.primary, width: 2) : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$dayNum',
                      style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(BuildContext context) {
    const items = [
      ('present', 'Present'),
      ('late', 'Late'),
      ('absent', 'Absent'),
      ('open', 'Clocked in'),
      ('incomplete', 'No clock-out'),
      ('closed', 'Day off'),
      ('upcoming', 'Upcoming'),
    ];

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: 6,
        children: items.map((item) {
          final (_, color, label) = _style(item.$1);
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 4),
              Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ],
          );
        }).toList(),
      ),
    );
  }
}