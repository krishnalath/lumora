class CBTModule {
  final String moduleId;
  final double completionStatus; // percentage
  final int sessionDurationSeconds;
  final int userRating; // 1-5 stars

  CBTModule({
    required this.moduleId,
    required this.completionStatus,
    required this.sessionDurationSeconds,
    required this.userRating,
  });

  Map<String, dynamic> toJson() {
    return {
      'module_id': moduleId,
      'completion_status': completionStatus,
      'session_duration_seconds': sessionDurationSeconds,
      'user_rating': userRating,
    };
  }

  factory CBTModule.fromMap(Map<String, dynamic> map) {
    return CBTModule(
      moduleId: map['module_id'] ?? '',
      completionStatus: (map['completion_status'] ?? 0.0).toDouble(),
      sessionDurationSeconds: map['session_duration_seconds']?.toInt() ?? 0,
      userRating: map['user_rating']?.toInt() ?? 0,
    );
  }
}
