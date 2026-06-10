import 'package:dio/dio.dart';
import '../storage/secure_token_storage.dart';
import '../constants/api_constants.dart';

class AuthInterceptor extends Interceptor {
  final SecureTokenStorage _tokenStorage;
  final void Function()? onLogout;

  AuthInterceptor(this._tokenStorage, {this.onLogout});

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _tokenStorage.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    super.onRequest(options, handler);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      final path = err.requestOptions.path;
      // Do not try to refresh if the failed request was already login or refresh
      if (path.contains('/auth/login') || path.contains('/auth/refresh')) {
        return super.onError(err, handler);
      }

      final refreshToken = await _tokenStorage.getRefreshToken();
      if (refreshToken == null) {
        await _tokenStorage.clearTokens();
        onLogout?.call();
        return super.onError(err, handler);
      }

      try {
        final refreshDio = Dio(BaseOptions(
          baseUrl: ApiConstants.baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
        ));
        
        final response = await refreshDio.post(
          '/auth/refresh',
          options: Options(
            headers: {
              'Authorization': 'Bearer $refreshToken',
            },
          ),
        );

        final newAccessToken = response.data['access_token'];
        final newRefreshToken = response.data['refresh_token'];

        if (newAccessToken != null && newRefreshToken != null) {
          await _tokenStorage.saveAccessToken(newAccessToken);
          await _tokenStorage.saveRefreshToken(newRefreshToken);

          // Re-attach token and retry the original request
          err.requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
          
          final retryDio = Dio(BaseOptions(
            baseUrl: ApiConstants.baseUrl,
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 30),
          ));
          
          final retryResponse = await retryDio.request(
            err.requestOptions.path,
            data: err.requestOptions.data,
            queryParameters: err.requestOptions.queryParameters,
            options: Options(
              method: err.requestOptions.method,
              headers: err.requestOptions.headers,
              contentType: err.requestOptions.contentType,
            ),
          );
          
          return handler.resolve(retryResponse);
        }
      } catch (e) {
        // Refresh failed (refresh token expired or invalid)
        await _tokenStorage.clearTokens();
        onLogout?.call();
      }
    }
    super.onError(err, handler);
  }
}
