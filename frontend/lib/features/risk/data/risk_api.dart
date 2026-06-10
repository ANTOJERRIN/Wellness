import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import 'risk_models.dart';

class RiskApi {
  final Dio _dio;

  RiskApi(this._dio);

  Future<HeartRiskResponseModel> predictHeartRisk(RiskFeaturesModel features) async {
    final res = await _dio.post('/risk/predict', data: features.toJson());
    return HeartRiskResponseModel.fromJson(res.data as Map<String, dynamic>);
  }
}

final riskApiProvider = Provider<RiskApi>((ref) {
  final dio = ref.watch(dioProvider);
  return RiskApi(dio);
});
