enum MessageType { text, image, file }

class Message {
  final String text;
  final bool isFromMe;
  final DateTime timestamp;
  final MessageType messageType;
  final String? filePath;

  Message({
    required this.text,
    required this.isFromMe,
    required this.timestamp,
    this.messageType = MessageType.text,
    this.filePath,
  });

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'isFromMe': isFromMe,
      'timestamp': timestamp.toIso8601String(),
      'messageType': messageType.toString(),
      'filePath': filePath,
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'is_from_me': isFromMe ? 1 : 0,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'message_type': messageType.toString().split('.').last,
      'file_path': filePath,
    };
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      text: json['text'],
      isFromMe: json['isFromMe'],
      timestamp: DateTime.parse(json['timestamp']),
      messageType: MessageType.values.firstWhere(
        (e) => e.toString() == json['messageType'],
        orElse: () => MessageType.text,
      ),
      filePath: json['filePath'],
    );
  }

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      text: map['text'],
      isFromMe: map['is_from_me'] == 1,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
      messageType: MessageType.values.firstWhere(
        (e) => e.toString().split('.').last == map['message_type'],
        orElse: () => MessageType.text,
      ),
      filePath: map['file_path'],
    );
  }
}
