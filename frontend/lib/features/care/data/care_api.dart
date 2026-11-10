import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';

class CareApi {
  final Dio dio;
  CareApi(this.dio);
  Future<Map<String, dynamic>> dashboard() async =>
      Map<String, dynamic>.from((await dio.get('/care/dashboard')).data);
  Future<List<Map<String, dynamic>>> doctors() async =>
      ((await dio.get('/care/doctors')).data as List)
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
  Future<void> request(int doctorId, String reason) async {
    await dio.post(
      '/care/consultations',
      data: {'doctorId': doctorId, 'reason': reason},
    );
  }

  Future<List<Map<String, dynamic>>> messages(String id) async =>
      ((await dio.get('/care/consultations/$id/messages')).data as List)
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
  Future<void> send(String id, String content) async {
    await dio.post(
      '/care/consultations/$id/messages',
      data: {'content': content},
    );
  }

  Future<void> status(String id, String status) async {
    await dio.patch('/care/consultations/$id', data: {'status': status});
  }

  Future<Map<String, dynamic>> checkAi() async =>
      Map<String, dynamic>.from((await dio.post('/care/ai/check')).data);
}

final careApiProvider = Provider<CareApi>(
  (ref) => CareApi(ref.watch(dioProvider)),
);
final careDashboardProvider = FutureProvider.autoDispose<Map<String, dynamic>>(
  (ref) => ref.watch(careApiProvider).dashboard(),
);

String careError(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['detail'] is String) {
      return data['detail'] as String;
    }
  }
  return 'Unable to complete this request. Please try again.';
}
