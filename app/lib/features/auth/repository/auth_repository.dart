import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_repository.g.dart';

const _baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8080',
);

class AuthException implements Exception {
  const AuthException(this.code, this.message);
  final String code;
  final String message;

  @override
  String toString() => message;
}

class AuthRepository {
  AuthRepository() : _dio = Dio(BaseOptions(baseUrl: _baseUrl));

  final Dio _dio;

  Future<String> sendRegistrationOtp({
    required String name,
    required String mobile,
    required String schoolName,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/register/send-otp',
        data: {
          'name': name,
          'mobile': mobile,
          'school_name': schoolName,
          'password': password,
        },
      );
      return response.data['req_id'] as String;
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        throw AuthException(
          data['error'] as String? ?? 'unknown',
          data['message'] as String? ?? 'Registration failed',
        );
      }
      throw const AuthException('network_error', 'Network error. Please try again.');
    }
  }

  Future<Map<String, String>> verifyRegistrationOtp({
    required String reqId,
    required String otp,
    required String name,
    required String mobile,
    required String schoolName,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/register/verify-otp',
        data: {
          'req_id': reqId,
          'otp': otp,
          'name': name,
          'mobile': mobile,
          'school_name': schoolName,
          'password': password,
        },
      );
      final data = response.data as Map<String, dynamic>;
      return {
        'access_token': data['access_token'] as String,
        'refresh_token': data['refresh_token'] as String,
        'teacher_id': data['teacher_id'] as String? ?? '',
      };
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        throw AuthException(
          data['error'] as String? ?? 'unknown',
          data['message'] as String? ?? 'OTP verification failed',
        );
      }
      throw const AuthException('network_error', 'Network error. Please try again.');
    }
  }

  Future<Map<String, String>> login({
    required String mobile,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/login',
        data: {'mobile': mobile, 'password': password},
      );
      final data = response.data as Map<String, dynamic>;
      return {
        'access_token': data['access_token'] as String,
        'refresh_token': data['refresh_token'] as String,
        'teacher_id': data['teacher_id'] as String? ?? '',
      };
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        throw AuthException(
          data['error'] as String? ?? 'unknown',
          data['message'] as String? ?? 'Invalid mobile or password',
        );
      }
      throw const AuthException('network_error', 'Network error. Please try again.');
    }
  }

  Future<void> retryOtp({required String reqId, int retryChannel = 11}) async {
    try {
      await _dio.post(
        '/auth/otp/retry',
        data: {'req_id': reqId, 'retry_channel': retryChannel},
      );
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        throw AuthException(
          data['error'] as String? ?? 'unknown',
          data['message'] as String? ?? 'Retry failed',
        );
      }
      throw const AuthException('network_error', 'Network error. Please try again.');
    }
  }
}

@riverpod
AuthRepository authRepository(Ref ref) => AuthRepository();
