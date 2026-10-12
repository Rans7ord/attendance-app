import 'package:dio/dio.dart';

/// Turns whatever a request threw into a sentence a person can read.
/// Prefers the server's own message (e.g. "You cannot review your own
/// leave request."), then the first validation error, then a fallback.
String apiErrorMessage(Object error, {String fallback = 'Something went wrong. Please try again.'}) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map) {
      final errors = data['errors'];
      if (errors is Map && errors.isNotEmpty) {
        final first = errors.values.first;
        if (first is List && first.isNotEmpty) return first.first.toString();
      }
      final message = data['message'];
      if (message is String && message.isNotEmpty) return message;
    }
    switch (error.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Cannot reach the server. Check your connection.';
      default:
        break;
    }
  }
  return fallback;
}