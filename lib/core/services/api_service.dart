import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';

class ApiService {
  // 10.0.2.2 for Android emulator; use your machine's LAN IP for a real phone.
  static const baseUrl = 'https://attendance.logoninvoice.com/api';

  /// Called whenever the server says the session is no longer usable:
  /// a 401 (expired/invalid/revoked token) or a 403 "account_inactive"
  /// (an admin deactivated this account). Set once in main.dart to
  /// redirect to login. Kept as a callback (rather than importing a
  /// screen here) so this service doesn't depend on the UI layer.
  static VoidCallback? onUnauthorized;

  final _storage = const FlutterSecureStorage();
  late final Dio _dio;

  ApiService() {
    _dio = Dio(BaseOptions(baseUrl: baseUrl));
    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) async {
          final status = error.response?.statusCode;
          final data = error.response?.data;
          final code = data is Map ? data['code'] : null;

          if (status == 401 || (status == 403 && code == 'account_inactive')) {
            await _storage.deleteAll();
            onUnauthorized?.call();
          }
          handler.next(error);
        },
      ),
    );
  }

  Future<Options> _authHeader() async {
    final token = await _storage.read(key: 'token');
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  /// Converts an XFile into a Dio MultipartFile using bytes — works on
  /// mobile, desktop, and web alike (unlike MultipartFile.fromFile, which
  /// needs dart:io and breaks on web).
  Future<MultipartFile> _multipartFromXFile(XFile file) async {
    final bytes = await file.readAsBytes();
    return MultipartFile.fromBytes(bytes, filename: file.name);
  }

  Future<bool> hasToken() async {
    final token = await _storage.read(key: 'token');
    return token != null && token.isNotEmpty;
  }

  /// Clears the stored session. Purely local — this API has no server-side
  /// token-revocation route today, so this doesn't invalidate the token
  /// on the server, only forgets it on this device.
  Future<void> logout() async {
    await _storage.deleteAll();
  }

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
    final response = await _dio.post('/clock-in',
        data: {'gps_lat': lat, 'gps_lng': lng}, options: await _authHeader());
    return response.data;
  }

  Future<Map<String, dynamic>> clockOut(double lat, double lng) async {
    final response = await _dio.post('/clock-out',
        data: {'gps_lat': lat, 'gps_lng': lng}, options: await _authHeader());
    return response.data;
  }

  /// Checks whether the logged-in member currently has an open shift —
  /// used on the attendance screen's load so the Clock In/Out button
  /// reflects reality even after the app was closed and reopened, instead
  /// of always starting back at "Clock In".
  Future<Map<String, dynamic>> getAttendanceStatus() async {
    final response = await _dio.get('/attendance/status', options: await _authHeader());
    return response.data;
  }

  Future<List<dynamic>> getAttendanceHistory() async {
    final response = await _dio.get('/attendance', options: await _authHeader());
    return response.data;
  }

  /// Admin/supervisor dashboard: every member in scope, with today's
  /// computed status (unscheduled/closed/upcoming/absent/open/present/
  /// late), photo, and branch name. Admin sees the whole company;
  /// supervisor sees only their own branch — enforced server-side.
  Future<List<dynamic>> getTodayAttendance() async {
    final response = await _dio.get('/attendance/today', options: await _authHeader());
    return response.data;
  }

  /// Admin/supervisor drill-down into one member's full attendance
  /// history. Supervisor is limited to members in their own branch.
  Future<List<dynamic>> getMemberAttendance(int memberId) async {
    final response = await _dio.get('/members/$memberId/attendance', options: await _authHeader());
    return response.data;
  }

  /// The logged-in user's own month calendar — works for any role, since
  /// every account has a Member record. [month] is "YYYY-MM"; omit it for
  /// the current month.
  Future<Map<String, dynamic>> getMyCalendar({String? month}) async {
    final response = await _dio.get(
      '/attendance/calendar',
      queryParameters: month != null ? {'month': month} : null,
      options: await _authHeader(),
    );
    return response.data;
  }

  /// Admin/supervisor viewing someone else's month calendar. Same
  /// branch-scoping as getMemberAttendance.
  Future<Map<String, dynamic>> getMemberCalendar(int memberId, {String? month}) async {
    final response = await _dio.get(
      '/members/$memberId/calendar',
      queryParameters: month != null ? {'month': month} : null,
      options: await _authHeader(),
    );
    return response.data;
  }

  Future<List<dynamic>> getBranches() async {
    final response = await _dio.get('/branches', options: await _authHeader());
    return response.data;
  }

  /// Admin sees every member in the company; supervisor sees only members
  /// in their own branch. The scoping is enforced server-side — this
  /// method is identical for both roles, the response just differs.
  Future<List<dynamic>> getMembers() async {
    final response = await _dio.get('/members', options: await _authHeader());
    return response.data;
  }

  Future<Map<String, dynamic>> createBranch({
    required String name,
    String? address,
    required double lat,
    required double lng,
    int radius = 30,
  }) async {
    final response = await _dio.post('/branches',
        data: {
          'name': name,
          'address': address,
          'gps_lat': lat,
          'gps_lng': lng,
          'geofence_radius_m': radius,
        },
        options: await _authHeader());
    return response.data;
  }

  /// Returns a branch's working-day/hour schedule as a list of 7 day
  /// objects ({day, is_working, start_time, grace_minutes}), one per
  /// weekday, each with its own time window. If nothing's configured
  /// yet, the server fills in sensible per-day defaults with
  /// "configured": false rather than an error.
  Future<Map<String, dynamic>> getBranchSchedule(int branchId) async {
    final response = await _dio.get('/branches/$branchId/schedule', options: await _authHeader());
    return response.data;
  }

  /// Admin-only. [days] must contain all 7 weekdays, each as a map with
  /// keys: day, is_working, start_time ("HH:mm"), grace_minutes. Sent as
  /// a plain JSON body, not FormData — PHP never parses multipart bodies
  /// on PUT requests, only POST.
  Future<Map<String, dynamic>> updateBranchSchedule({
    required int branchId,
    required List<Map<String, dynamic>> days,
  }) async {
    final response = await _dio.put(
      '/branches/$branchId/schedule',
      data: {'days': days},
      options: await _authHeader(),
    );
    return response.data;
  }

  // ---- Onboarding (public, no auth header) ----

  Future<Map<String, dynamic>> registerCompany({
    required String companyName,
    String? industry,
    required String adminName,
    required String adminEmail,
    required String adminPassword,
    required String adminAttendancePin,
    required XFile adminPhoto,
  }) async {
    final formData = FormData.fromMap({
      'company_name': companyName,
      if (industry != null) 'industry': industry,
      'admin_name': adminName,
      'admin_email': adminEmail,
      'admin_password': adminPassword,
      'admin_attendance_pin': adminAttendancePin,
      'photo': await _multipartFromXFile(adminPhoto),
    });

    final response = await _dio.post('/register-company', data: formData);
    await _storage.write(key: 'token', value: response.data['token']);
    await _storage.write(key: 'role', value: response.data['role'] ?? 'admin');
    return response.data;
  }

  /// Looks up a company by its join code — also returns whether a selfie
  /// is required, so the join screen can tell the person upfront.
  Future<Map<String, dynamic>> getCompanyForJoinCode(String code) async {
    final response = await _dio.get('/join/$code/branches');
    return response.data;
  }

  /// Self-registers a member using a company join code. [photo] is optional
  /// here at the Dart layer — the server enforces whether it's actually
  /// required based on the company's setting, and returns a validation
  /// error if it's missing and required.
  Future<Map<String, dynamic>> registerMember({
    required String joinCode,
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String attendancePin,
    String? phone,
    required int branchId,
    XFile? photo,
  }) async {
    final formData = FormData.fromMap({
      'join_code': joinCode,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'password': password,
      'attendance_pin': attendancePin,
      if (phone != null) 'phone': phone,
      'branch_id': branchId,
      if (photo != null) 'photo': await _multipartFromXFile(photo),
    });

    final response = await _dio.post('/register-member', data: formData);
    await _storage.write(key: 'token', value: response.data['token']);
    await _storage.write(key: 'role', value: response.data['role'] ?? 'member');
    return response.data;
  }

  Future<Map<String, dynamic>> acceptInvite({
    required String token,
    required String firstName,
    required String lastName,
    required String password,
    required String attendancePin,
    String? phone,
    XFile? photo,
  }) async {
    final formData = FormData.fromMap({
      'token': token,
      'first_name': firstName,
      'last_name': lastName,
      'password': password,
      'attendance_pin': attendancePin,
      if (phone != null) 'phone': phone,
      if (photo != null) 'photo': await _multipartFromXFile(photo),
    });

    final response = await _dio.post('/accept-invite', data: formData);
    await _storage.write(key: 'token', value: response.data['token']);
    await _storage.write(key: 'role', value: response.data['role'] ?? 'member');
    return response.data;
  }

  /// Fetches the company's registration policy for an invite before the
  /// app displays the photo step. The API still enforces the policy.
  Future<Map<String, dynamic>> getInviteRegistrationDetails(String token) async {
    final response = await _dio.get('/invites/$token/registration');
    return response.data;
  }

  // ---- Admin: company settings, join code, invites ----

  Future<Map<String, dynamic>> getCompany() async {
    final response = await _dio.get('/company', options: await _authHeader());
    return response.data;
  }

  Future<void> updateCompanySettings({required bool requireSelfieOnJoin}) async {
    await _dio.put('/company/settings',
        data: {'require_selfie_on_join': requireSelfieOnJoin}, options: await _authHeader());
  }

  /// Replaces the join code — the old one stops working immediately, so
  /// the server insists on confirm=true. The caller's dialog is the
  /// confirmation; this just passes it along.
  Future<Map<String, dynamic>> regenerateJoinCode({int? expiresInDays, int? maxUses}) async {
    final response = await _dio.post('/company/regenerate-join-code',
        data: {'confirm': true, 'expires_in_days': expiresInDays, 'max_uses': maxUses},
        options: await _authHeader());
    return response.data;
  }

  Future<List<dynamic>> getInvites() async {
    final response = await _dio.get('/invites', options: await _authHeader());
    return response.data;
  }

  /// [role] is 'member' or 'supervisor'. [branchId] is required for both —
  /// the server rejects a non-admin invite with no branch attached.
  Future<Map<String, dynamic>> createInvite({
    required String email,
    required String role,
    int? branchId,
    int? expiresInDays,
  }) async {
    final response = await _dio.post('/invites',
        data: {
          'email': email,
          'role': role,
          'branch_id': branchId,
          'expires_in_days': expiresInDays,
        },
        options: await _authHeader());
    return response.data;
  }

  Future<void> revokeInvite(int id) async {
    await _dio.delete('/invites/$id', options: await _authHeader());
  }

  Future<Map<String, dynamic>> loginWithPin({
    required String email,
    required String pin,
    required XFile photo,
  }) async {
    final formData = FormData.fromMap({
      'email': email,
      'pin': pin,
      'photo': await _multipartFromXFile(photo),
    });
    final response = await _dio.post('/login-with-pin', data: formData);
    await _storage.write(key: 'token', value: response.data['token']);
    await _storage.write(key: 'role', value: response.data['role'] ?? 'member');
    return response.data;
  }
}