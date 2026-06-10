import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import 'models/profile_model.dart';

class ProfileApi {
  final Dio _dio;

  ProfileApi(this._dio);

  Future<UserProfileModel> getProfile() async {
    final res = await _dio.get('/user/profile');
    return UserProfileModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<HealthProfileModel> updateProfile(HealthProfileModel profile) async {
    final res = await _dio.put('/user/profile', data: profile.toJson());
    final data = res.data['healthProfile'] as Map<String, dynamic>;
    return HealthProfileModel.fromJson(data);
  }
}

final profileApiProvider = Provider<ProfileApi>((ref) {
  final dio = ref.watch(dioProvider);
  return ProfileApi(dio);
});
