class Message {
  final String? message;
  final String type;
  final String from;

  Message({
    this.message,
    required this.type,
    required this.from,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      message: json['message'],
      type: json['type'],
      from: json['from'],
    );
  }

  @override
  String toString() {
    return 'Message{message: $message, type: $type, from: $from}';
  }

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'type': type,
      'from': from,
    };
  }
}

class SignalMessage {
  final String from;
  final String type;
  final Map<String, dynamic> message;
  final bool announce;
  final int timestamp = DateTime.now().millisecondsSinceEpoch;

  SignalMessage({
    required this.from,
    required this.type,
    required this.message,
    this.announce = false,
  });

  @override
  String toString() {
    return 'SignalMessage{from: $from, type: $type, message: $message, announce: $announce, timestamp: $timestamp}';
  }

  Map<String, dynamic> toJson() {
    return {
      'from': from,
      'type': type,
      'message': message,
      'announce': announce,
      'timestamp': timestamp,
    };
  }

  factory SignalMessage.fromJson(Map<String, dynamic> json) {
    return SignalMessage(
      from: json['from'],
      type: json['type'],
      message: json['message'],
      announce: json['announce'],
    );
  }
}
