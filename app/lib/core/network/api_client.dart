import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:school_attendance/core/auth/auth_notifier.dart';
import 'package:school_attendance/core/storage/secure_storage.dart';

part 'api_client.g.dart';

const _baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8080',
);

@riverpod
Dio apiClient(Ref ref) {
  final dio = Dio(BaseOptions(baseUrl: _baseUrl));
  dio.interceptors.add(_JwtInterceptor(ref));
  return dio;
}

class _JwtInterceptor extends QueuedInterceptorsWrapper {
  _JwtInterceptor(this._ref);
  final Ref _ref;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final storage = _ref.read(secureStorageProvider);
    final accessToken = await storage.readAccessToken();
    if (accessToken != null) {
      options.headers['Authorization'] = 'Bearer $accessToken';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401) {
      handler.next(err);
      return;
    }

    final storage = _ref.read(secureStorageProvider);
    final refreshToken = await storage.readRefreshToken();

    if (refreshToken == null) {
      await _ref.read(authNotifierProvider.notifier).logout();
      handler.next(err);
      return;
    }

    try {
      final refreshDio = Dio(BaseOptions(baseUrl: _baseUrl));
      final response = await refreshDio.post(
        '/auth/refresh',
        options: Options(
          headers: {'Authorization': 'Bearer $refreshToken'},
          validateStatus: (s) => s != null,
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final newAccessToken = data['access_token'] as String;
        final teacherID = data['teacher_id'] as String? ?? '';

        await storage.saveTokens(
          accessToken: newAccessToken,
          refreshToken: refreshToken,
          teacherID: teacherID,
        );
        await _ref.read(authNotifierProvider.notifier).login(
          accessToken: newAccessToken,
          refreshToken: refreshToken,
          teacherID: teacherID,
        );

        // Retry original request with new token using a fresh Dio to avoid
        // re-entering the interceptor chain and causing duplicate refresh calls.
        final retryDio = Dio(BaseOptions(baseUrl: _baseUrl));
        err.requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
        final retryOpts = Options(
          method: err.requestOptions.method,
          headers: err.requestOptions.headers,
          validateStatus: (s) => s != null,
        );
        final retryResponse = await retryDio.request(
          err.requestOptions.path,
          data: err.requestOptions.data,
          queryParameters: err.requestOptions.queryParameters,
          options: retryOpts,
        );
        handler.resolve(retryResponse);
      } else {
        await _ref.read(authNotifierProvider.notifier).logout();
        handler.next(err);
      }
    } catch (_) {
      await _ref.read(authNotifierProvider.notifier).logout();
      handler.next(err);
    }
  }
}
