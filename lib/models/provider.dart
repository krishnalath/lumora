class Provider {
  final String providerId;
  final DateTime sessionTimestamp;
  final String messageEncryptionKey;
  final bool escalationFlag;

  Provider({
    required this.providerId,
    required this.sessionTimestamp,
    required this.messageEncryptionKey,
    required this.escalationFlag,
  });

  Map<String, dynamic> toJson() {
    return {
      'provider_id': providerId,
      'session_timestamp': sessionTimestamp.toIso8601String(),
      'message_encryption_key': messageEncryptionKey,
      'escalation_flag': escalationFlag,
    };
  }

  factory Provider.fromMap(Map<String, dynamic> map) {
    return Provider(
      providerId: map['provider_id'] ?? '',
      sessionTimestamp: map['session_timestamp'] != null 
          ? DateTime.parse(map['session_timestamp']) 
          : DateTime.now(),
      messageEncryptionKey: map['message_encryption_key'] ?? '',
      escalationFlag: map['escalation_flag'] ?? false,
    );
  }
}
