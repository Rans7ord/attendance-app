import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../../core/utils/responsive.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_theme.dart';
import 'attendance_history_screen.dart';
import 'package:dio/dio.dart';
import '../../shared/widgets/live_clock_card.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  bool _checkingStatus = true;
  bool _clockedIn = false;
  bool _overdue = false;
  String _status = 'Not clocked in';
  bool _isError = false;
  bool _busy = false;
  final _localAuth = LocalAuthentication();
  final _api = ApiService();

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  /// Checks the real server-side state on open, instead of always
  /// assuming "not clocked in" — so reopening the app after clocking in
  /// correctly shows "Clock Out", not a stale "Clock In".
  Future<void> _loadStatus() async {
    try {
      final data = await _api.getAttendanceStatus();
      final clockedIn = data['clocked_in'] == true;
      final overdue = data['is_overdue'] == true;
      setState(() {
        _clockedIn = clockedIn;
        _overdue = overdue;
        _isError = overdue;
        _status = !clockedIn
            ? 'Not clocked in'
            : overdue
                ? 'Still clocked in from a previous day — clock out to start fresh'
                : 'Clocked in';
      });
    } catch (_) {
      // If the status check itself fails (e.g. no connection), fall back
      // to the previous "Not clocked in" assumption rather than blocking
      // the screen — the server still enforces the real rule either way.
    } finally {
      if (mounted) setState(() => _checkingStatus = false);
    }
  }

  Future<bool> _verifyIdentity() async {
    if (kIsWeb) {
      // No local_auth support in the browser — placeholder pass so the
      // rest of the flow (API call, UI state) is testable in Chrome.
      // Swap for the real local_auth check once running on a device.
      await Future.delayed(const Duration(milliseconds: 300));
      return true;
    }
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Confirm your identity to record attendance',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
    } on Exception {
      return false;
    }
  }

  Future<void> _clockInOut() async {
    setState(() => _busy = true);

    final verified = await _verifyIdentity();
    if (!verified) {
      setState(() {
        _status = 'Identity check failed';
        _isError = true;
        _busy = false;
      });
      return;
    }

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _status = 'Turn on Location services, then try again';
          _isError = true;
          _busy = false;
        });
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        setState(() {
          _status = 'Location permission denied';
          _isError = true;
          _busy = false;
        });
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _status = 'Enable location permission in the app settings';
          _isError = true;
          _busy = false;
        });
        return;
      }
      final pos = await Geolocator.getCurrentPosition();

      if (_clockedIn) {
        await _api.clockOut(pos.latitude, pos.longitude);
      } else {
        await _api.clockIn(pos.latitude, pos.longitude);
      }

      setState(() {
        _clockedIn = !_clockedIn;
        _overdue = false;
        _status = _clockedIn ? 'Clocked in' : 'Clocked out';
        _isError = false;
        _busy = false;
      });
    } on DioException catch (e) {
      if (e.response?.statusCode == 422) {
        final message = e.response?.data['message'] ?? 'You are outside the allowed area.';
        final distance = e.response?.data['distance_m'];
        setState(() {
          _status = distance != null ? '$message (${distance}m away)' : message;
          _isError = true;
          _busy = false;
        });
      } else if (e.response?.statusCode == 404) {
        // Clock-out called with no open record — local state had drifted
        // from the server. Re-sync rather than just showing an error.
        setState(() {
          _status = e.response?.data['message'] ?? 'You are not currently clocked in.';
          _isError = true;
          _busy = false;
        });
        _loadStatus();
      } else {
        setState(() {
          _status = 'Something went wrong — try again';
          _isError = true;
          _busy = false;
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Something went wrong — try again';
        _isError = true;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = Responsive.isDesktop(context);
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Attendance')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isWide ? 480 : double.infinity),
            child: _checkingStatus
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const LiveClockCard(),
                        const SizedBox(height: AppSpacing.md),
                        _StatusCard(
                          clockedIn: _clockedIn,
                          status: _status,
                          isError: _isError,
                          overdue: _overdue,
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        _ClockButton(
                          clockedIn: _clockedIn,
                          busy: _busy,
                          onPressed: _busy ? null : _clockInOut,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        TextButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const AttendanceHistoryScreen()),
                          ),
                          icon: const Icon(Icons.history_rounded),
                          label: const Text('View History'),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Large status card showing whether the user is currently clocked in,
/// with the live status message and a colored indicator dot.
class _StatusCard extends StatelessWidget {
  final bool clockedIn;
  final String status;
  final bool isError;
  final bool overdue;

  const _StatusCard({
    required this.clockedIn,
    required this.status,
    required this.isError,
    this.overdue = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color accent = overdue
        ? AppColors.warning
        : isError
            ? AppColors.danger
            : (clockedIn ? AppColors.success : AppColors.textMuted);
    final Color bg = overdue
        ? AppColors.warningSoft
        : isError
            ? AppColors.dangerSoft
            : (clockedIn ? AppColors.successSoft : AppColors.surfaceCard);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl, horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: clockedIn && !isError && !overdue ? AppGradients.card : null,
              color: clockedIn && !isError && !overdue ? null : Colors.white,
              boxShadow: [
                BoxShadow(color: accent.withValues(alpha: 0.18), blurRadius: 20, offset: const Offset(0, 8)),
              ],
            ),
            child: Icon(
              overdue
                  ? Icons.warning_amber_rounded
                  : isError
                      ? Icons.error_outline_rounded
                      : (clockedIn ? Icons.check_circle_rounded : Icons.schedule_rounded),
              size: 34,
              color: clockedIn && !isError && !overdue ? Colors.white : accent,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            status,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: overdue ? AppColors.warning : (isError ? AppColors.danger : AppColors.textPrimary),
                ),
          ),
        ],
      ),
    );
  }
}

/// The primary clock-in/out call to action — a full-width gradient
/// button when clocking in, and a neutral outline when clocking out.
class _ClockButton extends StatelessWidget {
  final bool clockedIn;
  final bool busy;
  final VoidCallback? onPressed;

  const _ClockButton({required this.clockedIn, required this.busy, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final child = busy
        ? const SizedBox(
            height: 22,
            width: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(clockedIn ? Icons.logout_rounded : Icons.fingerprint_rounded, color: Colors.white),
              const SizedBox(width: AppSpacing.sm),
              Text(
                clockedIn ? 'Clock Out' : 'Clock In',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ],
          );

    return Container(
      width: double.infinity,
      height: 58,
      decoration: BoxDecoration(
        gradient: clockedIn ? null : AppGradients.brand,
        color: clockedIn ? AppColors.textPrimary : null,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: [
          BoxShadow(
            color: (clockedIn ? AppColors.textPrimary : AppColors.primary).withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onPressed,
          child: Center(child: child),
        ),
      ),
    );
  }
}