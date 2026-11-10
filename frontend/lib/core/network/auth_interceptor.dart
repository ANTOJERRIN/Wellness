import 'package:dio/dio.dart';
import '../storage/secure_token_storage.dart';
import '../constants/api_constants.dart';

class AuthInterceptor extends Interceptor {
  final SecureTokenStorage _tokenStorage;
  final Dio _transport;
  final void Function()? onLogout;
  Future<String?>? _refreshInFlight;

  AuthInterceptor(this._tokenStorage, {this.onLogout, Dio? transport})
    : _transport =
          transport ??
          Dio(
            BaseOptions(
              baseUrl: ApiConstants.baseUrl,
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 30),
            ),
          );

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _tokenStorage.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    super.onRequest(options, handler);
  }

  Future<String?> _refresh() async {
    final refreshToken = await _tokenStorage.getRefreshToken();
    if (refreshToken == null) {
      await _tokenStorage.clearTokens();
      onLogout?.call();
      return null;
    }
    try {
      final response = await _transport.post(
        '/auth/refresh',
        options: Options(headers: {'Authorization': 'Bearer $refreshToken'}),
      );
      final access = response.data['access_token'];
      final refresh = response.data['refresh_token'];
      if (access is! String ||
          refresh is! String ||
          access.isEmpty ||
          refresh.isEmpty) {
        throw const FormatException('Invalid refresh response');
      }
      await _tokenStorage.saveRefreshToken(refresh);
      await _tokenStorage.saveAccessToken(access);
      return access;
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        await _tokenStorage.clearTokens();
        onLogout?.call();
      }
      rethrow;
    }
  }

  Future<String?> _tokenForRetry(String? failedAuthorization) async {
    if (_refreshInFlight != null) return _refreshInFlight!;
    final current = await _tokenStorage.getAccessToken();
    if (_refreshInFlight != null) return _refreshInFlight!;
    // A delayed 401 may arrive after another request has completed rotation.
    if (current != null && 'Bearer $current' != failedAuthorization) {
      return current;
    }
    return _refreshInFlight = _refresh().whenComplete(() {
      _refreshInFlight = null;
    });
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final path = err.requestOptions.path;
    if (err.response?.statusCode != 401 || path.contains('/auth/')) {
      return super.onError(err, handler);
    }
    try {
      final token = await _tokenForRetry(
        err.requestOptions.headers['Authorization'] as String?,
      );
      if (token == null) return handler.next(err);
      final options = err.requestOptions.copyWith(
        headers: {
          ...err.requestOptions.headers,
          'Authorization': 'Bearer $token',
        },
      );
      // The transport has no auth interceptor, so each request is retried once.
      final response = await _transport.fetch<dynamic>(options);
      return handler.resolve(response);
    } on DioException catch (error) {
      return handler.next(error);
    } catch (_) {
      return handler.next(err);
    }
  }
}
