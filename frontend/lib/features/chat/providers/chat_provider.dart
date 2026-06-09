import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_provider.dart';

class ChatMessage {
  final String text;
  final String sender; // 'user' or 'ai'
  final DateTime timestamp;
  final bool isFollowUpPrompt;

  ChatMessage({
    required this.text,
    required this.sender,
    required this.timestamp,
    this.isFollowUpPrompt = false,
  });
}

class ChatNotifier extends Notifier<List<ChatMessage>> {
  Dio get _dio => ref.read(dioProvider);
  String? activeSessionId;

  @override
  List<ChatMessage> build() {
    return [];
  }

  Future<void> startNewSession() async {
    activeSessionId = null;
    state = [
      ChatMessage(
        text:
            "Hello! I'm Med Genie, your AI health assistant. How can I help you today?\n\nTip: Fill out your Health Profile for more personalized answers.",
        sender: 'ai',
        timestamp: DateTime.now(),
      )
    ];
    try {
      final res = await _dio.post("/chat/sessions", data: {"title": "New Chat Session"});
      activeSessionId = res.data["sessionId"];
    } catch (_) {}
  }

  Future<void> loadSession(String sessionId) async {
    activeSessionId = sessionId;
    state = [
      ChatMessage(
        text: "Loading session history...",
        sender: 'ai',
        timestamp: DateTime.now(),
      )
    ];
    // Start a fresh local view — in a more advanced version, we'd fetch messages
    state = [
      ChatMessage(
        text: "Session resumed. Continue your conversation below.",
        sender: 'ai',
        timestamp: DateTime.now(),
      )
    ];
  }

  Future<void> sendMessage(String text) async {
    if (activeSessionId == null) {
      await startNewSession();
    }

    final userMsg = ChatMessage(
      text: text,
      sender: 'user',
      timestamp: DateTime.now(),
    );
    state = [...state, userMsg];

    final thinkingMsg = ChatMessage(
      text: "Thinking...",
      sender: 'ai',
      timestamp: DateTime.now(),
    );
    state = [...state, thinkingMsg];

    try {
      final res = await _dio.post(
        "/chat/sessions/$activeSessionId/messages",
        data: {"content": text},
      );
      state = state.where((msg) => msg.text != "Thinking...").toList();

      final answer = res.data["answer"];
      final followUp = res.data["followUpQuestion"];

      state = [
        ...state,
        ChatMessage(
          text: answer,
          sender: 'ai',
          timestamp: DateTime.now(),
        )
      ];

      if (followUp != null && followUp.toString().isNotEmpty) {
        state = [
          ...state,
          ChatMessage(
            text: followUp,
            sender: 'ai',
            timestamp: DateTime.now(),
            isFollowUpPrompt: true,
          )
        ];
      }
    } on DioException catch (_) {
      state = state.where((msg) => msg.text != "Thinking...").toList();
      state = [
        ...state,
        ChatMessage(
          text:
              "I encountered an issue connecting to the AI service. Please check your connection and try again.",
          sender: 'ai',
          timestamp: DateTime.now(),
        )
      ];
    }
  }

  void clearMessages() {
    state = [];
    activeSessionId = null;
  }
}

final chatProvider =
    NotifierProvider<ChatNotifier, List<ChatMessage>>(ChatNotifier.new);
