import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import 'models/chat_model.dart';

class ChatApi {
  final Dio _dio;

  ChatApi(this._dio);

  Future<ChatSessionModel> createSession(String title) async {
    final res = await _dio.post('/chat/sessions', data: {'title': title});
    return ChatSessionModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<ChatSessionModel>> listSessions() async {
    final res = await _dio.get('/chat/sessions');
    final list = res.data as List<dynamic>;
    return list.map((e) => ChatSessionModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<ChatMessageModel>> getSessionMessages(String sessionId) async {
    final res = await _dio.get('/chat/sessions/$sessionId/messages');
    final list = res.data as List<dynamic>;
    return list.map((e) => ChatMessageModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<ChatSendResponseModel> sendMessage(String sessionId, String message) async {
    final res = await _dio.post('/chat/sessions/$sessionId/messages', data: {'content': message});
    return ChatSendResponseModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> deleteSession(String sessionId) async {
    await _dio.delete('/chat/sessions/$sessionId');
  }
}

final chatApiProvider = Provider<ChatApi>((ref) {
  final dio = ref.watch(dioProvider);
  return ChatApi(dio);
});
