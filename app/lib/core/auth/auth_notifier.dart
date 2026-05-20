import 'dart:io';

import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:school_attendance/core/storage/secure_storage.dart';
import 'package:school_attendance/core/auth/auth_state.dart';

part 'auth_notifier.g.dart';

const _baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8080',
);

@riverpod
class AuthNotifier extends _$AuthNotifier {
  @override
  AuthState build() => const AuthInitial();

  Future<void> silentRefresh() async {
    state = const AuthLoading();
    final storage = ref.read(secureStorageProvider);
    final refreshToken = await storage.readRefreshToken();

    if (refreshToken == null) {
      state = const AuthUnauthenticated();
      return;
    }

    try {
      final dio = Dio(BaseOptions(baseUrl: _baseUrl));
      final response = await dio.post(
        '/auth/refresh',
        options: Options(
          headers: {'Authorization': 'Bearer $refreshToken'},
          validateStatus: (status) => status != null,
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final accessToken = data['access_token'] as String;
        final teacherID = data['teacher_id'] as String? ?? '';
        await storage.saveTokens(
          accessToken: accessToken,
          refreshToken: refreshToken,
          teacherID: teacherID,
        );
        state = AuthAuthenticated(
          accessToken: accessToken,
          teacherID: teacherID,
        );
      } else if (response.statusCode == 401) {
        await storage.clearTokens();
        state = const AuthUnauthenticated();
      } else {
        state = const AuthNetworkError();
      }
    } on SocketException {
      state = const AuthNetworkError();
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        state = const AuthNetworkError();
      } else if (e.response?.statusCode == 401) {
        await storage.clearTokens();
        state = const AuthUnauthenticated();
      } else {
        state = const AuthNetworkError();
      }
    }
  }

  Future<void> login({
    required String accessToken,
    required String refreshToken,
    required String teacherID,
  }) async {
    final storage = ref.read(secureStorageProvider);
    await storage.saveTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
      teacherID: teacherID,
    );
    state = AuthAuthenticated(
      accessToken: accessToken,
      teacherID: teacherID,
    );
  }

  Future<void> logout() async {
    final storage = ref.read(secureStorageProvider);
    await storage.clearTokens();
    state = const AuthUnauthenticated();
  }
}
