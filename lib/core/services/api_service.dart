import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  // 10.0.2.2 for Android emulator; use your machine's LAN IP for a real phone.
  static const baseUrl = 'https://attendance.logoninvoice.com/api';

  final Dio _dio = Dio(BaseOptions(baseUrl: baseUrl));
  final _storage = const FlutterSecureStorage();

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await _dio.post('/login', data: {'email': email, 'password': password});
    await _storage.write(key: 'token', value: response.data['token']);
    await _storage.write(key: 'role', value: response.data['role'] ?? 'member');
    return response.data;
  }

  Future<String> getRole() async {
    return await _storage.read(key: 'role') ?? 'member';
  }

  Future<Map<String, dynamic>> clockIn(double lat, double lng) async {
    final token = await _storage.read(key: 'token');
    final response = await _dio.post('/clock-in',
        data: {'gps_lat': lat, 'gps_lng': lng},
        options: Options(headers: {'Authorization': 'Bearer $token'}));
    return response.data;
  }

  Future<Map<String, dynamic>> clockOut(double lat, double lng) async {
    final token = await _storage.read(key: 'token');
    final response = await _dio.post('/clock-out',
        data: {'gps_lat': lat, 'gps_lng': lng},
        options: Options(headers: {'Authorization': 'Bearer $token'}));
    return response.data;
  }

  Future<List<dynamic>> getAttendanceHistory() async {
    final token = await _storage.read(key: 'token');
    final response = await _dio.get('/attendance',
        options: Options(headers: {'Authorization': 'Bearer $token'}));
    return response.data;
  }

  Future<List<dynamic>> getBranches() async {
    final token = await _storage.read(key: 'token');
    final response = await _dio.get('/branches',
        options: Options(headers: {'Authorization': 'Bearer $token'}));
    return response.data;
  }

  Future<Map<String, dynamic>> createBranch({
    required String name,
    String? address,
    required double lat,
    required double lng,
    int radius = 150,
  }) async {
    final token = await _storage.read(key: 'token');
    final response = await _dio.post('/branches',
        data: {
          'name': name,
          'address': address,
          'gps_lat': lat,
          'gps_lng': lng,
          'geofence_radius_m': radius,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}));
    return response.data;
  }

}