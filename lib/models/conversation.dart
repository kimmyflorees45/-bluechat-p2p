class Conversation {
  final int? id;
  final String deviceName;
  final String deviceAddress;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final DateTime createdAt;

  Conversation({
    this.id,
    required this.deviceName,
    required this.deviceAddress,
    this.lastMessage,
    this.lastMessageTime,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'device_name': deviceName,
      'device_address': deviceAddress,
      'last_message': lastMessage,
      'last_message_time': lastMessageTime?.millisecondsSinceEpoch,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory Conversation.fromMap(Map<String, dynamic> map) {
    return Conversation(
      id: map['id'],
      deviceName: map['device_name'],
      deviceAddress: map['device_address'],
      lastMessage: map['last_message'],
      lastMessageTime: map['last_message_time'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['last_message_time'])
          : null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
    );
  }
}
