import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import 'notifications_screen.dart';

/// App-bar bell with an unread badge. It checks the unread count every
/// 30 seconds (and whenever the app returns to the foreground) and shows a
/// pop-up the first time it sees something new.
class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> with WidgetsBindingObserver {
  final _api = ApiService();
  Timer? _timer;
  int _unread = 0;
  int? _lastSeen; // null until the first successful check
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _check());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    if (_checking) return;
    _checking = true;
    try {
      final count = await _api.getUnreadCount();
      if (!mounted) return;

      final previous = _lastSeen;
      setState(() => _unread = count);
      _lastSeen = count;

      // Pop up on the first look if there's something waiting, and again
      // whenever the count goes up. Reading things (count going down) is silent.
      final isNew = previous == null ? count > 0 : count > previous;
      if (isNew) await _showPopup(count - (previous ?? 0));
    } catch (_) {
      // Polling is best-effort: a dropped connection shouldn't show errors.
    } finally {
      _checking = false;
    }
  }

  Future<void> _showPopup(int newCount) async {
    String message = newCount == 1 ? 'You have a new notification' : 'You have $newCount new notifications';

    try {
      final data = await _api.getNotifications();
      final list = data['notifications'] as List<dynamic>;
      final latest = list.cast<Map<String, dynamic>>().where((n) => n['read_at'] == null).toList();
      if (latest.isNotEmpty) {
        final title = latest.first['title'] as String?;
        if (title != null && title.isNotEmpty) {
          message = newCount > 1 ? '$title (+${newCount - 1} more)' : title;
        }
      }
    } catch (_) {
      // Fall back to the generic message.
    }

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(label: 'View', onPressed: _open),
      ),
    );
  }

  Future<void> _open() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
    // Back from the list: things may have been read. Update the badge
    // quietly, without popping up about what's still unread.
    try {
      final count = await _api.getUnreadCount();
      _lastSeen = count;
      if (mounted) setState(() => _unread = count);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Notifications',
      onPressed: _open,
      icon: Badge(
        isLabelVisible: _unread > 0,
        label: Text(_unread > 99 ? '99+' : '$_unread'),
        child: const Icon(Icons.notifications_rounded),
      ),
    );
  }
}