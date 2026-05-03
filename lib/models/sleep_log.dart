class SleepLog {
  final double sleepQualityIndex;
  final DateTime bedtimeTimestamp;
  final DateTime wakeTimestamp;
  final int interruptionsCount;

  SleepLog({
    required this.sleepQualityIndex,
    required this.bedtimeTimestamp,
    required this.wakeTimestamp,
    required this.interruptionsCount,
  });

  Map<String, dynamic> toJson() {
    return {
      'sleep_quality_index': sleepQualityIndex,
      'bedtime_timestamp': bedtimeTimestamp.toIso8601String(),
      'wake_timestamp': wakeTimestamp.toIso8601String(),
      'interruptions_count': interruptionsCount,
    };
  }

  factory SleepLog.fromMap(Map<String, dynamic> map) {
    return SleepLog(
      sleepQualityIndex: (map['sleep_quality_index'] ?? 0.0).toDouble(),
      bedtimeTimestamp: map['bedtime_timestamp'] != null 
          ? DateTime.parse(map['bedtime_timestamp']) 
          : DateTime.now(),
      wakeTimestamp: map['wake_timestamp'] != null 
          ? DateTime.parse(map['wake_timestamp']) 
          : DateTime.now(),
      interruptionsCount: map['interruptions_count']?.toInt() ?? 0,
    );
  }
}
