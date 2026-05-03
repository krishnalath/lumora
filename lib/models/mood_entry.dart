class MoodEntry {
  final int moodValenceScore; // 1-10 scale
  final List<String> emotionTags; // e.g., ["anxious", "joyful"]
  final String triggerContext; // e.g., "work", "relationships"
  final DateTime logTimestamp;

  MoodEntry({
    required this.moodValenceScore,
    required this.emotionTags,
    required this.triggerContext,
    required this.logTimestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'mood_valence_score': moodValenceScore,
      'emotion_tags': emotionTags,
      'trigger_context': triggerContext,
      'log_timestamp': logTimestamp.toIso8601String(),
    };
  }

  factory MoodEntry.fromMap(Map<String, dynamic> map) {
    return MoodEntry(
      moodValenceScore: map['mood_valence_score']?.toInt() ?? 5,
      emotionTags: List<String>.from(map['emotion_tags'] ?? []),
      triggerContext: map['trigger_context'] ?? '',
      logTimestamp: map['log_timestamp'] != null 
          ? DateTime.parse(map['log_timestamp']) 
          : DateTime.now(),
    );
  }
}
