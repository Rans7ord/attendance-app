import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../core/utils/responsive.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/services/api_service.dart';
import 'attendance_history_screen.dart';
import 'package:dio/dio.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  bool _clockedIn = false;
  String _status = 'Not clocked in';

  Future<bool> _verifyIdentity() async {
    if (kIsWeb) {
      // No local_auth support in the browser — placeholder pass so the
      // rest of the flow (API call, UI state) is testable in Chrome.
      // Swap for the real local_auth check once running on a device.
      await Future.delayed(const Duration(milliseconds: 300));
      return true;
    }
    // TODO: real local_auth.authenticate() call goes here on device.
    return true;
  }

  final _api = ApiService(); // add as a field

  Future<void> _clockInOut() async {
    final verified = await _verifyIdentity();
    if (!verified) { setState(() => _status = 'Identity check failed'); return; }

    try {
      final permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _status = 'Location permission denied');
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
        _status = _clockedIn ? 'Clocked in' : 'Clocked out';
      });
    } on DioException catch (e) {
      if (e.response?.statusCode == 422) {
        final message = e.response?.data['message'] ?? 'You are outside the allowed area.';
        final distance = e.response?.data['distance_m'];
        setState(() => _status = distance != null
            ? '$message (${distance}m away)'
            : message);
      } else {
        setState(() => _status = 'Something went wrong — try again');
      }
    } catch (e) {
      setState(() => _status = 'Something went wrong — try again');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = Responsive.isDesktop(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Attendance')),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isWide ? 480 : double.infinity),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_status, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _clockInOut,
                  icon: Icon(_clockedIn ? Icons.logout : Icons.login),
                  label: Text(_clockedIn ? 'Clock Out' : 'Clock In'),
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AttendanceHistoryScreen()),
                  ),
                  icon: const Icon(Icons.history),
                  label: const Text('View History'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}