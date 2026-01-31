class ChatMessage {
  final String id;
  final String roomId;
  final String senderId;
  final String content;
  final bool isSystemMessage;
  final DateTime createdAt;
  final String? senderName;
  final String? senderPhoto;

  ChatMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.content,
    this.isSystemMessage = false,
    required this.createdAt,
    this.senderName,
    this.senderPhoto,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    // Handling join data from Supabase: { ..., users: { nama: '...', foto_profil: '...' } }
    final userData = json['users'] as Map<String, dynamic>?;

    return ChatMessage(
      id: json['id'],
      roomId: json['room_id'],
      senderId: json['sender_id'] ?? '',
      content: json['content'] ?? '',
      isSystemMessage: json['is_system_message'] ?? false,
      createdAt: DateTime.parse(json['created_at']).toLocal(),
      senderName: userData?['nama'] ?? json['sender_name'],
      senderPhoto: userData?['foto_profil'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'room_id': roomId,
      'sender_id': senderId,
      'content': content,
      'is_system_message': isSystemMessage,
      // created_at let DB handle it
    };
  }
}
