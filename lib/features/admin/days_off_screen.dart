import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/api_error.dart';
import '../../shared/date_format.dart';
import '../leave/leave_screen.dart' show dayOffKindLabel;

/// Admins and managers create holidays, short breaks and closures here.
/// Days off count as neither absent nor late, and appear on calendars and
/// in reports.
class DaysOffScreen extends StatefulWidget {
  const DaysOffScreen({super.key});

  @override
  State<DaysOffScreen> createState() => _DaysOffScreenState();
}

class _DaysOffScreenState extends State<DaysOffScreen> {
  final _api = ApiService();
  bool _loading = true;
  bool _includePast = false;
  String? _error;
  List<dynamic> _items = [];

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
      final data = await _api.getDaysOff(includePast: _includePast);
      if (mounted) setState(() => _items = data);
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(e, fallback: 'Could not load days off'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openForm({Map<String, dynamic>? existing}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _DayOffForm(existing: existing),
    );
    if (saved == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(existing == null ? 'Day off added' : 'Day off updated')),
      );
      _load();
    }
  }

  Future<void> _delete(Map<String, dynamic> off) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this day off?'),
        content: Text(
          '"${off['title']}" will be removed and those dates become normal working days again. '
          'Anyone who does not clock in will count as absent.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _api.deleteDayOff(off['id'] as int);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Day off deleted')));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    }
  }

  String _scopeText(Map<String, dynamic> off) {
    switch (off['scope']) {
      case 'branch':
        return off['branch']?['name'] ?? 'One branch';
      case 'members':
        final count = (off['members'] as List?)?.length ?? 0;
        return count == 1 ? '1 person' : '$count people';
      default:
        return 'Everyone';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Days Off'),
        actions: [
          IconButton(
            tooltip: _includePast ? 'Hide past' : 'Show past',
            icon: Icon(_includePast ? Icons.history_toggle_off_rounded : Icons.history_rounded),
            onPressed: () {
              setState(() => _includePast = !_includePast);
              _load();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add day off'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(children: [
                    const SizedBox(height: AppSpacing.xl),
                    Center(child: Text(_error!, style: Theme.of(context).textTheme.bodyMedium)),
                  ])
                : _items.isEmpty
                    ? ListView(children: [
                        const SizedBox(height: AppSpacing.xl),
                        Center(
                          child: Text(
                            _includePast ? 'No days off yet' : 'No upcoming days off',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ])
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 96),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, i) {
                          final off = _items[i] as Map<String, dynamic>;
                          return Container(
                            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.xs, AppSpacing.md),
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
                                      Text(off['title'] ?? '', style: Theme.of(context).textTheme.titleSmall),
                                      const SizedBox(height: 2),
                                      Text(
                                        prettyRange(off['start_date'], off['end_date']),
                                        style: Theme.of(context).textTheme.bodyMedium,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${dayOffKindLabel(off['kind'])} · ${_scopeText(off)}',
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  onSelected: (v) {
                                    if (v == 'edit') _openForm(existing: off);
                                    if (v == 'delete') _delete(off);
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                                  ],
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

class _DayOffForm extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const _DayOffForm({this.existing});

  @override
  State<_DayOffForm> createState() => _DayOffFormState();
}

class _DayOffFormState extends State<_DayOffForm> {
  final _api = ApiService();
  final _title = TextEditingController();
  String _kind = 'holiday';
  String _scope = 'company';
  int? _branchId;
  Set<int> _memberIds = {};
  late DateTime _start;
  late DateTime _end;
  bool _saving = false;
  String? _error;

  List<dynamic> _branches = [];
  List<dynamic> _members = [];
  bool _loadingOptions = true;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _start = today;
    _end = today;

    final e = widget.existing;
    if (e != null) {
      _title.text = e['title'] ?? '';
      _kind = e['kind'] ?? 'holiday';
      _scope = e['scope'] ?? 'company';
      _branchId = e['branch_id'] as int?;
      _memberIds = ((e['members'] as List?) ?? []).map((m) => m['id'] as int).toSet();
      _start = DateTime.tryParse(e['start_date'] ?? '') ?? today;
      _end = DateTime.tryParse(e['end_date'] ?? '') ?? _start;
    }
    _loadOptions();
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    try {
      final branches = await _api.getBranches();
      final members = await _api.getMembers();
      if (!mounted) return;
      setState(() {
        _branches = branches;
        _members = members;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load branches and members');
    } finally {
      if (mounted) setState(() => _loadingOptions = false);
    }
  }

  Future<void> _pickStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked == null) return;
    setState(() {
      _start = picked;
      if (_end.isBefore(_start)) _end = _start;
    });
  }

  Future<void> _pickEnd() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _end.isBefore(_start) ? _start : _end,
      firstDate: _start,
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked != null) setState(() => _end = picked);
  }

  Future<void> _pickMembers() async {
    final selected = Set<int>.from(_memberIds);
    final result = await showDialog<Set<int>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Choose people'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final m in _members)
                  CheckboxListTile(
                    dense: true,
                    value: selected.contains(m['id'] as int),
                    title: Text('${m['first_name'] ?? ''} ${m['last_name'] ?? ''}'.trim()),
                    subtitle: Text(m['branch']?['name'] ?? 'No branch'),
                    onChanged: (v) => setLocal(() {
                      if (v == true) {
                        selected.add(m['id'] as int);
                      } else {
                        selected.remove(m['id'] as int);
                      }
                    }),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.of(ctx).pop(selected), child: const Text('Done')),
          ],
        ),
      ),
    );
    if (result != null) setState(() => _memberIds = result);
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Give this day off a title');
      return;
    }
    if (_scope == 'branch' && _branchId == null) {
      setState(() => _error = 'Choose a branch');
      return;
    }
    if (_scope == 'members' && _memberIds.isEmpty) {
      setState(() => _error = 'Choose at least one person');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final start = dateParam(_start);
      final end = dateParam(_end);
      final branchId = _scope == 'branch' ? _branchId : null;
      final memberIds = _scope == 'members' ? _memberIds.toList() : null;

      if (_editing) {
        await _api.updateDayOff(
          widget.existing!['id'] as int,
          title: title,
          kind: _kind,
          scope: _scope,
          startDate: start,
          endDate: end,
          branchId: branchId,
          memberIds: memberIds,
        );
      } else {
        await _api.createDayOff(
          title: title,
          kind: _kind,
          scope: _scope,
          startDate: start,
          endDate: end,
          branchId: branchId,
          memberIds: memberIds,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
            Text(_editing ? 'Edit day off' : 'Add day off', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _title,
              maxLength: 120,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Title (e.g. Independence Day)'),
            ),
            DropdownButtonFormField<String>(
              initialValue: _kind,
              decoration: const InputDecoration(labelText: 'Type'),
              items: const [
                DropdownMenuItem(value: 'holiday', child: Text('Holiday')),
                DropdownMenuItem(value: 'break', child: Text('Short break')),
                DropdownMenuItem(value: 'closure', child: Text('Closure')),
              ],
              onChanged: (v) => setState(() => _kind = v ?? 'holiday'),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickStart,
                    icon: const Icon(Icons.event_rounded, size: 18),
                    label: Text('From ${prettyDate(dateParam(_start))}'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickEnd,
                    icon: const Icon(Icons.event_available_rounded, size: 18),
                    label: Text('To ${prettyDate(dateParam(_end))}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: _scope,
              decoration: const InputDecoration(labelText: 'Who is off'),
              items: const [
                DropdownMenuItem(value: 'company', child: Text('Everyone')),
                DropdownMenuItem(value: 'branch', child: Text('One branch')),
                DropdownMenuItem(value: 'members', child: Text('Specific people')),
              ],
              onChanged: (v) => setState(() => _scope = v ?? 'company'),
            ),
            if (_scope == 'branch' && _loadingOptions) ...[
              const SizedBox(height: AppSpacing.sm),
              const LinearProgressIndicator(),
            ],
            if (_scope == 'branch' && !_loadingOptions) ...[
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<int>(
                initialValue: _branchId,
                decoration: const InputDecoration(labelText: 'Branch'),
                items: [
                  for (final b in _branches)
                    DropdownMenuItem<int>(value: b['id'] as int, child: Text(b['name'] ?? '')),
                ],
                onChanged: (v) => setState(() => _branchId = v),
              ),
            ],
            if (_scope == 'members') ...[
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: _loadingOptions ? null : _pickMembers,
                icon: const Icon(Icons.group_add_rounded, size: 18),
                label: Text(_memberIds.isEmpty ? 'Choose people' : '${_memberIds.length} selected'),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12.5)),
            ],
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(_editing ? 'Save changes' : 'Add day off'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}