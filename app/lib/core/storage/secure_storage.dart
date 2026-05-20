import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'secure_storage.g.dart';

const _keyAccessToken = 'access_token';
const _keyRefreshToken = 'refresh_token';
const _keyTeacherID = 'teacher_id';

@riverpod
SecureStorageService secureStorage(SecureStorageRef ref) {
  return SecureStorageService();
}

class SecureStorageService {
  SecureStorageService()
      : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
        );

  final FlutterSecureStorage _storage;

  Future<String?> readAccessToken() => _storage.read(key: _keyAccessToken);
  Future<String?> readRefreshToken() => _storage.read(key: _keyRefreshToken);
  Future<String?> readTeacherID() => _storage.read(key: _keyTeacherID);

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required String teacherID,
  }) async {
    await Future.wait([
      _storage.write(key: _keyAccessToken, value: accessToken),
      _storage.write(key: _keyRefreshToken, value: refreshToken),
      _storage.write(key: _keyTeacherID, value: teacherID),
    ]);
  }

  Future<void> clearTokens() async {
    await Future.wait([
      _storage.delete(key: _keyAccessToken),
      _storage.delete(key: _keyRefreshToken),
      _storage.delete(key: _keyTeacherID),
    ]);
  }
}
