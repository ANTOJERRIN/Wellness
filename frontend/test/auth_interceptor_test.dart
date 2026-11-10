import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/auth_interceptor.dart';
import 'package:frontend/core/storage/secure_token_storage.dart';

class MemoryTokens extends SecureTokenStorage {
  MemoryTokens() : super(const FlutterSecureStorage());
  String? access = 'old-access';
  String? refresh = 'old-refresh';
  @override
  Future<String?> getAccessToken() async => access;
  @override
  Future<String?> getRefreshToken() async => refresh;
  @override
  Future<void> saveAccessToken(String token) async {
    access = token;
  }

  @override
  Future<void> saveRefreshToken(String token) async {
    refresh = token;
  }

  @override
  Future<void> clearTokens() async {
    access = null;
    refresh = null;
  }
}

class FakeAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions) respond;
  FakeAdapter(this.respond);
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) => respond(options);
  @override
  void close({bool force = false}) {}
}

ResponseBody jsonBody(int status, Object data) => ResponseBody.fromString(
  jsonEncode(data),
  status,
  headers: {
    Headers.contentTypeHeader: ['application/json'],
  },
);

void main() {
  test(
    'Parallel unauthorized requests share refresh and delayed failures reuse it',
    () async {
      final storage = MemoryTokens();
      final refreshStarted = Completer<void>();
      final releaseRefresh = Completer<void>();
      final releaseDelayed = Completer<void>();
      var refreshCalls = 0;
      final transport = Dio()
        ..httpClientAdapter = FakeAdapter((options) async {
          if (options.path == '/auth/refresh') {
            refreshCalls++;
            refreshStarted.complete();
            await releaseRefresh.future;
            return jsonBody(200, {
              'access_token': 'new-access',
              'refresh_token': 'new-refresh',
            });
          }
          expect(options.headers['Authorization'], 'Bearer new-access');
          return jsonBody(200, {'ok': true});
        });
      final dio = Dio(BaseOptions(baseUrl: 'https://test.example'));
      dio.httpClientAdapter = FakeAdapter((options) async {
        if (options.path == '/delayed') await releaseDelayed.future;
        return jsonBody(401, {});
      });
      dio.interceptors.add(AuthInterceptor(storage, transport: transport));
      final delayed = dio.get('/delayed');
      final requests = List.generate(3, (_) => dio.get('/profile'));
      await refreshStarted.future;
      releaseRefresh.complete();
      final responses = await Future.wait(requests);
      releaseDelayed.complete();
      expect((await delayed).statusCode, 200);
      expect(responses.every((response) => response.statusCode == 200), isTrue);
      expect(refreshCalls, 1);
      expect(storage.refresh, 'new-refresh');
    },
  );

  for (final status in [429, 503, 401]) {
    test(
      'Refresh $status ${status == 401 ? 'clears' : 'retains'} tokens',
      () async {
        final storage = MemoryTokens();
        var logouts = 0;
        final transport = Dio()
          ..httpClientAdapter = FakeAdapter((_) async => jsonBody(status, {}));
        final dio = Dio(BaseOptions(baseUrl: 'https://test.example'))
          ..httpClientAdapter = FakeAdapter((_) async => jsonBody(401, {}));
        dio.interceptors.add(
          AuthInterceptor(
            storage,
            transport: transport,
            onLogout: () {
              logouts++;
            },
          ),
        );
        await expectLater(dio.get('/profile'), throwsA(isA<DioException>()));
        expect(storage.refresh, status == 401 ? isNull : 'old-refresh');
        expect(logouts, status == 401 ? 1 : 0);
      },
    );
  }

  test('A failed retried request preserves the rotated session', () async {
    final storage = MemoryTokens();
    final transport = Dio()
      ..httpClientAdapter = FakeAdapter((options) async {
        if (options.path == '/auth/refresh') {
          return jsonBody(200, {
            'access_token': 'new-access',
            'refresh_token': 'new-refresh',
          });
        }
        return jsonBody(503, {});
      });
    final dio = Dio(BaseOptions(baseUrl: 'https://test.example'))
      ..httpClientAdapter = FakeAdapter((_) async => jsonBody(401, {}));
    dio.interceptors.add(AuthInterceptor(storage, transport: transport));
    await expectLater(dio.get('/profile'), throwsA(isA<DioException>()));
    expect(storage.refresh, 'new-refresh');
    expect(storage.access, 'new-access');
  });
}
