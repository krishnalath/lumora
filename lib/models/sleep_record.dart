/// Data model representing a single auto-detected sleep session.
///
/// Each record captures when the user fell asleep and woke up,
/// along with metadata about detection confidence, sensor readings,
/// and sleep quality metrics.
class SleepRecord {
  /// Unique identifier (timestamp-based)
  final String id;

  /// Detected sleep start time
  final DateTime sleepStart;

  /// Detected sleep end time (null if still sleeping)
  final DateTime? sleepEnd;

  /// Composite confidence score (0–100) from sensor signals
  final int confidenceScore;

  /// Whether the phone was charging during the sleep session
  final bool isCharging;

  /// Average accelerometer magnitude during the session (m/s²)
  final double avgMotion;

  /// Number of brief wake-ups detected during the session
  final int interruptions;

  SleepRecord({
    required this.id,
    required this.sleepStart,
    this.sleepEnd,
    required this.confidenceScore,
    required this.isCharging,
    required this.avgMotion,
    this.interruptions = 0,
  });

  /// Total sleep duration. Returns Duration.zero if sleep is still in progress.
  Duration get duration {
    if (sleepEnd == null) return Duration.zero;
    return sleepEnd!.difference(sleepStart);
  }

  /// Formatted duration string, e.g. "7h 42m"
  String get durationFormatted {
    final d = duration;
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    if (hours == 0 && minutes == 0) return '--';
    return '${hours}h ${minutes}m';
  }

  /// Sleep wellness score (0–100) based on duration, interruptions, and confidence.
  ///
  /// Scoring breakdown:
  ///   Base:                       50
  ///   Duration 7–9h:             +30   (6–7h or 9–10h: +15, else: 0)
  ///   Few interruptions (0–1):   +10   (2–3: +5, 4+: 0)
  ///   High confidence (≥80):     +10
  int get sleepScore {
    int score = 50;
    final hours = duration.inMinutes / 60.0;

    // Duration scoring
    if (hours >= 7 && hours <= 9) {
      score += 30;
    } else if ((hours >= 6 && hours < 7) || (hours > 9 && hours <= 10)) {
      score += 15;
    }

    // Interruption scoring
    if (interruptions <= 1) {
      score += 10;
    } else if (interruptions <= 3) {
      score += 5;
    }

    // Confidence scoring
    if (confidenceScore >= 80) {
      score += 10;
    }

    return score.clamp(0, 100);
  }

  /// Quality label derived from sleep score
  String get qualityLabel {
    if (sleepScore >= 85) return 'Excellent';
    if (sleepScore >= 70) return 'Good';
    if (sleepScore >= 55) return 'Fair';
    return 'Poor';
  }

  /// Quality index (0 = Poor, 1 = Fair, 2 = Good/Excellent) for chart colors
  int get qualityIndex {
    if (sleepScore >= 70) return 2;
    if (sleepScore >= 55) return 1;
    return 0;
  }

  /// Serialize to JSON for SharedPreferences storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sleepStart': sleepStart.toIso8601String(),
      'sleepEnd': sleepEnd?.toIso8601String(),
      'confidenceScore': confidenceScore,
      'isCharging': isCharging,
      'avgMotion': avgMotion,
      'interruptions': interruptions,
    };
  }

  /// Deserialize from JSON
  factory SleepRecord.fromJson(Map<String, dynamic> json) {
    return SleepRecord(
      id: json['id'] as String,
      sleepStart: DateTime.parse(json['sleepStart'] as String),
      sleepEnd: json['sleepEnd'] != null
          ? DateTime.parse(json['sleepEnd'] as String)
          : null,
      confidenceScore: json['confidenceScore'] as int,
      isCharging: json['isCharging'] as bool,
      avgMotion: (json['avgMotion'] as num).toDouble(),
      interruptions: json['interruptions'] as int? ?? 0,
    );
  }
}
