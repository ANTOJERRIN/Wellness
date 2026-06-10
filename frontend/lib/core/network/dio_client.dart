import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/api_constants.dart';
import '../storage/secure_token_storage.dart';
import 'auth_interceptor.dart';
import '../../features/auth/providers/auth_provider.dart';

final dioClientProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: ApiConstants.baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
  ));

  final tokenStorage = ref.watch(tokenStorageProvider);
  dio.interceptors.add(AuthInterceptor(
    tokenStorage,
    onLogout: () {
      ref.read(authProvider.notifier).logout();
    },
  ));

  return dio;
});

final dioProvider = dioClientProvider;

