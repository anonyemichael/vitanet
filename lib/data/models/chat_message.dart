/// Represents a single message in the triage chat.
enum MessageRole { user, assistant }

class ChatAction {
  final String label;
  final String type;
  final String payload;

  const ChatAction({
    required this.label,
    required this.type,
    required this.payload,
  });

  factory ChatAction.fromMap(Map<String, dynamic> map) {
    return ChatAction(
      label: map['label'] as String? ?? '',
      type: map['type'] as String? ?? 'button',
      payload: map['payload'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'label': label,
      'type': type,
      'payload': payload,
    };
  }
}

class ChatMessage {
  final String id;
  final MessageRole role;
  final String text;
  final DateTime timestamp;
  final List<String>? quickReplies;
  final List<ChatAction>? actions;
  final String? widgetType;
  final Map<String, dynamic>? widgetPayload;
  final String? imagePath;

  const ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.timestamp,
    this.quickReplies,
    this.actions,
    this.widgetType,
    this.widgetPayload,
    this.imagePath,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'role': role.name,
        'text': text,
        'timestamp': timestamp.toIso8601String(),
        if (actions != null) 'actions': actions!.map((a) => a.toMap()).toList(),
        if (widgetType != null) 'widgetType': widgetType,
        if (widgetPayload != null) 'widgetPayload': widgetPayload,
        if (imagePath != null) 'imagePath': imagePath,
      };

  factory ChatMessage.fromMap(Map<String, dynamic> map) => ChatMessage(
        id: map['id'] as String,
        role: MessageRole.values.byName(map['role'] as String),
        text: map['text'] as String,
        timestamp: DateTime.parse(map['timestamp'] as String),
        actions: map['actions'] != null
            ? (map['actions'] as List).map((a) => ChatAction.fromMap(a as Map<String, dynamic>)).toList()
            : null,
        widgetType: map['widgetType'] as String?,
        widgetPayload: map['widgetPayload'] as Map<String, dynamic>?,
        imagePath: map['imagePath'] as String?,
      );
}
