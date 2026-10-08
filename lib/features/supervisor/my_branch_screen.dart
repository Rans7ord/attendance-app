import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_theme.dart';

class MyBranchScreen extends StatefulWidget {
  const MyBranchScreen({super.key});

  @override
  State<MyBranchScreen> createState() => _MyBranchScreenState();
}

class _MyBranchScreenState extends State<MyBranchScreen> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _branch;
  List<dynamic> _members = [];

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
      // Both calls are already scoped server-side to the supervisor's own
      // branch — no branch id is passed here, the API decides based on
      // who's asking.
      final branches = await _api.getBranches();
      final members = await _api.getMembers();
      setState(() {
        _branch = branches.isNotEmpty ? branches.first as Map<String, dynamic> : null;
        _members = members;
      });
    } catch (e) {
      setState(() => _error = 'Could not load your branch — pull down to retry');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('My Branch')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? ListView(
                      children: [
                        const SizedBox(height: AppSpacing.xl),
                        Center(child: Text(_error!, style: Theme.of(context).textTheme.bodyMedium)),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      children: [
                        if (_branch != null) _BranchCard(branch: _branch!),
                        const SizedBox(height: AppSpacing.lg),
                        Text('Members (${_members.length})', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: AppSpacing.sm),
                        if (_members.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                            child: Text('No members in this branch yet.', style: Theme.of(context).textTheme.bodyMedium),
                          )
                        else
                          ..._members.map((m) => _MemberTile(member: m as Map<String, dynamic>)),
                      ],
                    ),
        ),
      ),
    );
  }
}

class _BranchCard extends StatelessWidget {
  final Map<String, dynamic> branch;
  const _BranchCard({required this.branch});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
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
              const Icon(Icons.business_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(branch['name'] ?? 'Branch', style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          if (branch['address'] != null) ...[
            const SizedBox(height: 4),
            Text(branch['address'], style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: 4),
          Text(
            'Geofence radius: ${branch['geofence_radius_m']}m',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final Map<String, dynamic> member;
  const _MemberTile({required this.member});

  @override
  Widget build(BuildContext context) {
    final name = '${member['first_name'] ?? ''} ${member['last_name'] ?? ''}'.trim();
    final status = member['status'] ?? 'active';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name.isEmpty ? '(no name)' : name, style: Theme.of(context).textTheme.bodyMedium),
                Text(status, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}