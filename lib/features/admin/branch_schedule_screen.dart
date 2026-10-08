import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_theme.dart';

class BranchScheduleScreen extends StatefulWidget {
  final int branchId;
  final String branchName;

  const BranchScheduleScreen({super.key, required this.branchId, required this.branchName});

  @override
  State<BranchScheduleScreen> createState() => _BranchScheduleScreenState();
}

class _DaySchedule {
  bool isWorking;
  TimeOfDay startTime;
  final TextEditingController graceController;

  _DaySchedule({required this.isWorking, required this.startTime, required int grace})
      : graceController = TextEditingController(text: grace.toString());
}

class _BranchScheduleScreenState extends State<BranchScheduleScreen> {
  final _api = ApiService();
  bool _loading = true;
  bool _saving = false;
  bool _wasConfigured = false;

  static const _dayOrder = [
    'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday',
  ];
  static const _dayLabels = {
    'monday': 'Monday', 'tuesday': 'Tuesday', 'wednesday': 'Wednesday',
    'thursday': 'Thursday', 'friday': 'Friday', 'saturday': 'Saturday', 'sunday': 'Sunday',
  };

  final Map<String, _DaySchedule> _days = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final d in _days.values) {
      d.graceController.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await _api.getBranchSchedule(widget.branchId);
      final daysData = data['days'] as List<dynamic>;
      setState(() {
        for (final d in daysData) {
          final parts = (d['start_time'] as String).split(':');
          _days[d['day']] = _DaySchedule(
            isWorking: d['is_working'] as bool,
            startTime: TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])),
            grace: d['grace_minutes'] ?? 15,
          );
        }
        _wasConfigured = data['configured'] == true;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load this branch\'s schedule')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickTime(String day) async {
    final current = _days[day]!;
    final picked = await showTimePicker(context: context, initialTime: current.startTime);
    if (picked != null) setState(() => current.startTime = picked);
  }

  Future<void> _save() async {
    final payload = <Map<String, dynamic>>[];

    for (final day in _dayOrder) {
      final d = _days[day]!;
      final grace = int.tryParse(d.graceController.text);
      if (grace == null || grace < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Enter a valid grace period for ${_dayLabels[day]}')),
        );
        return;
      }
      payload.add({
        'day': day,
        'is_working': d.isWorking,
        'start_time':
            '${d.startTime.hour.toString().padLeft(2, '0')}:${d.startTime.minute.toString().padLeft(2, '0')}',
        'grace_minutes': grace,
      });
    }

    setState(() => _saving = true);
    try {
      await _api.updateBranchSchedule(branchId: widget.branchId, days: payload);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Schedule saved')),
      );
      setState(() => _wasConfigured = true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save the schedule')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: Text('${widget.branchName} Schedule')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                if (!_wasConfigured)
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.infoSoft,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: const Text(
                      'This branch has no schedule set yet — these are the defaults. Save to apply them.',
                      style: TextStyle(fontSize: 12.5),
                    ),
                  ),
                Text(
                  'Each day can have its own hours — useful for a shorter Saturday shift or a different weekend start time.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.md),
                ..._dayOrder.map((day) => _DayCard(
                      label: _dayLabels[day]!,
                      schedule: _days[day]!,
                      onToggle: (v) => setState(() => _days[day]!.isWorking = v),
                      onPickTime: () => _pickTime(day),
                    )),
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Save Schedule'),
                ),
              ],
            ),
    );
  }
}

class _DayCard extends StatelessWidget {
  final String label;
  final _DaySchedule schedule;
  final ValueChanged<bool> onToggle;
  final VoidCallback onPickTime;

  const _DayCard({
    required this.label,
    required this.schedule,
    required this.onToggle,
    required this.onPickTime,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
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
                child: Text(label, style: Theme.of(context).textTheme.titleSmall),
              ),
              Switch(
                activeThumbColor: AppColors.primary,
                value: schedule.isWorking,
                onChanged: onToggle,
              ),
            ],
          ),
          if (schedule.isWorking) ...[
            const Divider(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: const Icon(Icons.schedule_rounded, color: AppColors.primary, size: 20),
                    title: const Text('Start time', style: TextStyle(fontSize: 12.5)),
                    subtitle: Text(schedule.startTime.format(context)),
                    onTap: onPickTime,
                  ),
                ),
                SizedBox(
                  width: 90,
                  child: TextField(
                    controller: schedule.graceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Grace (min)',
                      isDense: true,
                    ),
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