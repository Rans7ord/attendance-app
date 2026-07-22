import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/utils/responsive.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  State<AttendanceHistoryScreen> createState() => _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
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
      final data = await _api.getAttendanceHistory();
      setState(() {
        _records = data;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not load attendance history';
        _loading = false;
      });
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
      appBar: AppBar(title: const Text('Attendance History')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!))
                : _records.isEmpty
                    ? const Center(child: Text('No attendance records yet'))
                    : Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                              maxWidth: Responsive.isDesktop(context) ? 700 : double.infinity),
                          child: ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _records.length,
                            separatorBuilder: (_, __) => const Divider(),
                            itemBuilder: (context, index) {
                              final r = _records[index];
                              return ListTile(
                                leading: Icon(
                                  r['clock_out'] == null ? Icons.login : Icons.check_circle_outline,
                                  color: r['clock_out'] == null ? Colors.orange : Colors.green,
                                ),
                                title: Text('Clock in: ${_formatDateTime(r['clock_in'])}'),
                                subtitle: Text(
                                  r['clock_out'] == null
                                      ? 'Still clocked in'
                                      : 'Clock out: ${_formatDateTime(r['clock_out'])}',
                                ),
                                trailing: Text(r['status'] ?? ''),
                              );
                            },
                          ),
                        ),
                      ),
      ),
    );
  }
}