class ChatSessionModel {
  final String sessionId;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;

  ChatSessionModel({
    required this.sessionId,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ChatSessionModel.fromJson(Map<String, dynamic> json) {
    return ChatSessionModel(
      sessionId: json['sessionId'] as String,
      title: json['title'] as String? ?? 'Chat Session',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class ChatMessageModel {
  final String content;
  final String sender; // 'user' or 'ai'
  final DateTime timestamp;
  final bool isFollowUp;

  ChatMessageModel({
    required this.content,
    required this.sender,
    required this.timestamp,
    this.isFollowUp = false,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      content: json['content'] as String,
      sender: json['sender'] as String,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      isFollowUp: json['isFollowUp'] as bool? ?? false,
    );
  }
}

class ChatSendResponseModel {
  final String answer;
  final String followUpQuestion;

  ChatSendResponseModel({
    required this.answer,
    required this.followUpQuestion,
  });

  factory ChatSendResponseModel.fromJson(Map<String, dynamic> json) {
    return ChatSendResponseModel(
      answer: json['answer'] as String? ?? '',
      followUpQuestion: json['followUpQuestion'] as String? ?? '',
    );
  }
}
