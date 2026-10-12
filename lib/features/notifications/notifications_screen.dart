import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/api_error.dart';
import '../../shared/date_format.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _api = ApiService();
  bool _loading = true;
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
      final data = await _api.getNotifications();
      if (mounted) setState(() => _items = data['notifications'] as List<dynamic>);
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(e, fallback: 'Could not load notifications'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _hasUnread => _items.any((n) => n['read_at'] == null);

  Future<void> _markRead(Map<String, dynamic> n) async {
    if (n['read_at'] != null) return;
    // Optimistic: flip it locally, then tell the server.
    setState(() => n['read_at'] = DateTime.now().toIso8601String());
    try {
      await _api.markNotificationRead(n['id'] as int);
    } catch (_) {
      if (mounted) setState(() => n['read_at'] = null);
    }
  }

  Future<void> _markAllRead() async {
    try {
      await _api.markAllNotificationsRead();
      if (!mounted) return;
      setState(() {
        final now = DateTime.now().toIso8601String();
        for (final n in _items) {
          n['read_at'] ??= now;
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    }
  }

  (IconData, Color, Color) _iconFor(String? type) {
    final t = type ?? '';
    if (t.contains('approved')) return (Icons.check_circle_rounded, AppColors.success, AppColors.successSoft);
    if (t.contains('rejected')) return (Icons.cancel_rounded, AppColors.danger, AppColors.dangerSoft);
    if (t.contains('leave')) return (Icons.beach_access_rounded, AppColors.primary, AppColors.infoSoft);
    if (t.contains('day_off')) return (Icons.celebration_rounded, AppColors.info, AppColors.infoSoft);
    if (t.contains('absent')) return (Icons.person_off_rounded, AppColors.warning, AppColors.warningSoft);
    return (Icons.notifications_rounded, AppColors.primary, AppColors.infoSoft);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (_hasUnread)
            TextButton(onPressed: _markAllRead, child: const Text('Mark all read')),
        ],
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
                        Center(child: Text('You are all caught up', style: Theme.of(context).textTheme.bodyMedium)),
                      ])
                    : ListView.separated(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, i) {
                          final n = _items[i] as Map<String, dynamic>;
                          final unread = n['read_at'] == null;
                          final (icon, color, soft) = _iconFor(n['type'] as String?);
                          final body = n['body'] as String?;

                          return Material(
                            color: unread ? AppColors.infoSoft.withValues(alpha: 0.45) : AppColors.surfaceCard,
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              onTap: () => _markRead(n),
                              child: Container(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(AppRadius.lg),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(color: soft, shape: BoxShape.circle),
                                      child: Icon(icon, color: color, size: 20),
                                    ),
                                    const SizedBox(width: AppSpacing.md),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            n['title'] ?? '',
                                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                                  fontWeight: unread ? FontWeight.w700 : FontWeight.w600,
                                                ),
                                          ),
                                          if (body != null && body.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(body, style: Theme.of(context).textTheme.bodyMedium),
                                          ],
                                          const SizedBox(height: 4),
                                          Text(timeAgo(n['created_at'] as String?),
                                              style: Theme.of(context).textTheme.bodySmall),
                                        ],
                                      ),
                                    ),
                                    if (unread)
                                      Container(
                                        margin: const EdgeInsets.only(left: AppSpacing.sm, top: 4),
                                        width: 10,
                                        height: 10,
                                        decoration: const BoxDecoration(
                                          color: AppColors.primary,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}