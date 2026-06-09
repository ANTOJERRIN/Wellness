import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/network/dio_provider.dart';

class AuthState {
  final bool isAuthenticated;
  final String? userName;
  final String? userEmail;
  final String? errorMessage;
  final bool isLoading;

  AuthState({
    this.isAuthenticated = false,
    this.userName,
    this.userEmail,
    this.errorMessage,
    this.isLoading = false,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    String? userName,
    String? userEmail,
    String? errorMessage,
    bool? isLoading,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      errorMessage: errorMessage ?? this.errorMessage,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  Dio get _dio => ref.read(dioProvider);
  FlutterSecureStorage get _storage => ref.read(secureStorageProvider);

  @override
  AuthState build() {
    Future.microtask(() => checkAuthStatus());
    return AuthState();
  }

  Future<void> checkAuthStatus() async {
    try {
      final token = await _storage.read(key: "access_token");
      if (token == null) {
        state = AuthState(isAuthenticated: false);
        return;
      }
      final res = await _dio.get("/user/profile");
      if (res.statusCode == 200) {
        state = AuthState(
          isAuthenticated: true,
          userName: res.data["name"],
          userEmail: res.data["email"],
        );
      }
    } catch (e) {
      try {
        await _storage.delete(key: "access_token");
        await _storage.delete(key: "refresh_token");
      } catch (_) {}
      state = AuthState(isAuthenticated: false);
    }
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final res = await _dio.post("/auth/login", data: {
        "email": email,
        "password": password,
      });
      final accessToken = res.data["access_token"];
      final refreshToken = res.data["refresh_token"];

      await _storage.write(key: "access_token", value: accessToken);
      await _storage.write(key: "refresh_token", value: refreshToken);

      final profileRes = await _dio.get("/user/profile");
      state = AuthState(
        isAuthenticated: true,
        userName: profileRes.data["name"],
        userEmail: profileRes.data["email"],
      );
    } on DioException catch (e) {
      final msg = e.response?.data["detail"] ?? "Invalid email or password";
      state = state.copyWith(isLoading: false, errorMessage: msg);
    }
  }

  Future<void> register(String name, String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _dio.post("/auth/register", data: {
        "name": name,
        "email": email,
        "password": password,
      });
      await login(email, password);
    } on DioException catch (e) {
      final msg = e.response?.data["detail"] ?? "Registration failed";
      state = state.copyWith(isLoading: false, errorMessage: msg);
    }
  }

  Future<void> logout() async {
    try {
      await _dio.post("/auth/logout");
    } catch (_) {}
    await _storage.delete(key: "access_token");
    await _storage.delete(key: "refresh_token");
    state = AuthState(isAuthenticated: false);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
