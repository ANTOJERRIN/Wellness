import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/storage/secure_token_storage.dart';
import '../data/auth_api.dart';
import '../../profile/data/profile_api.dart';

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
  SecureTokenStorage get _tokenStorage => ref.read(tokenStorageProvider);
  AuthApi get _authApi => ref.read(authApiProvider);
  ProfileApi get _profileApi => ref.read(profileApiProvider);

  @override
  AuthState build() {
    Future.microtask(() => checkAuthStatus());
    return AuthState();
  }

  Future<void> checkAuthStatus() async {
    try {
      final token = await _tokenStorage.getAccessToken();
      if (token == null) {
        state = AuthState(isAuthenticated: false);
        return;
      }
      final profile = await _profileApi.getProfile();
      state = AuthState(
        isAuthenticated: true,
        userName: profile.name,
        userEmail: profile.email,
      );
    } catch (e) {
      try {
        await _tokenStorage.clearTokens();
      } catch (_) {}
      state = AuthState(isAuthenticated: false);
    }
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final tokens = await _authApi.login(email: email, password: password);
      await _tokenStorage.saveAccessToken(tokens.accessToken);
      await _tokenStorage.saveRefreshToken(tokens.refreshToken);

      final profile = await _profileApi.getProfile();
      state = AuthState(
        isAuthenticated: true,
        userName: profile.name,
        userEmail: profile.email,
      );
    } on DioException catch (e) {
      final msg = e.response?.data["detail"] ?? "Invalid email or password";
      state = state.copyWith(isLoading: false, errorMessage: msg);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> register(String name, String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _authApi.register(name: name, email: email, password: password);
      await login(email, password);
    } on DioException catch (e) {
      final msg = e.response?.data["detail"] ?? "Registration failed";
      state = state.copyWith(isLoading: false, errorMessage: msg);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> logout() async {
    try {
      await _authApi.logout();
    } catch (_) {}
    await _tokenStorage.clearTokens();
    state = AuthState(isAuthenticated: false);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

