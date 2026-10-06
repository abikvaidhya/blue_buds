import 'dart:typed_data';

enum MessageType { text, image, system, imageRequest, imageAccepted, imageRejected }

enum MessageStatus { sending, sent, delivered, failed }

class ChatMessage {
  final String id;
  final String senderId; // empty or 'me' for local
  final String content; // text or base64 for small images / status
  final MessageType type;
  final DateTime timestamp;
  final MessageStatus status;
  final Uint8List? imageBytes; // only held in memory while connection live
  final bool isMine;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.content,
    required this.type,
    required this.timestamp,
    this.status = MessageStatus.sent,
    this.imageBytes,
    required this.isMine,
  });

  ChatMessage copyWith({
    MessageStatus? status,
    Uint8List? imageBytes,
  }) {
    return ChatMessage(
      id: id,
      senderId: senderId,
      content: content,
      type: type,
      timestamp: timestamp,
      status: status ?? this.status,
      imageBytes: imageBytes ?? this.imageBytes,
      isMine: isMine,
    );
  }
}

/// Active chat session (ephemeral – cleared when connection drops)
class ChatSession {
  final String peerId;
  final String peerName;
  final bool isSavedPeer;
  final List<ChatMessage> messages;
  final DateTime startedAt;
  final bool connected;

  ChatSession({
    required this.peerId,
    required this.peerName,
    this.isSavedPeer = false,
    List<ChatMessage>? messages,
    DateTime? startedAt,
    this.connected = true,
  })  : messages = messages ?? [],
        startedAt = startedAt ?? DateTime.now();

  ChatSession copyWith({
    String? peerName,
    bool? isSavedPeer,
    List<ChatMessage>? messages,
    bool? connected,
  }) {
    return ChatSession(
      peerId: peerId,
      peerName: peerName ?? this.peerName,
      isSavedPeer: isSavedPeer ?? this.isSavedPeer,
      messages: messages ?? this.messages,
      startedAt: startedAt,
      connected: connected ?? this.connected,
    );
  }
}
