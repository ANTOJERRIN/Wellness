import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SecureTokenStorage {
  final FlutterSecureStorage _storage;

  SecureTokenStorage(this._storage);

  static const String _accessTokenKey = 'access_token';

  Future<String?> getAccessToken() async {
    return await _storage.read(key: _accessTokenKey);
  }

  Future<void> saveAccessToken(String token) async {
    await _storage.write(key: _accessTokenKey, value: token);
  }

  Future<void> deleteAccessToken() async {
    await _storage.delete(key: _accessTokenKey);
  }
}

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

final tokenStorageProvider = Provider<SecureTokenStorage>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return SecureTokenStorage(storage);
});
