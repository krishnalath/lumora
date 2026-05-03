import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TaskModel {
  final String id;
  final String uid;
  final String title;
  final String category; // Client Project, Family task, Company task, etc.
  final String status; // Completed, Rejected, Running, Upcoming
  final DateTime date;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final int progress; // 0 to 100
  final bool isPinned;
  final DateTime? pinnedAt;
  final DateTime createdAt;

  TaskModel({
    required this.id,
    required this.uid,
    required this.title,
    required this.category,
    required this.status,
    required this.date,
    required this.startTime,
    required this.endTime,
    this.progress = 0,
    this.isPinned = false,
    this.pinnedAt,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'title': title,
      'category': category,
      'status': status,
      'date': Timestamp.fromDate(date),
      'startTime': '${startTime.hour}:${startTime.minute}',
      'endTime': '${endTime.hour}:${endTime.minute}',
      'progress': progress,
      'isPinned': isPinned,
      'pinnedAt': pinnedAt != null ? Timestamp.fromDate(pinnedAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory TaskModel.fromMap(Map<String, dynamic> map, String docId) {
    // Helper to parse time string "HH:MM"
    TimeOfDay parseTime(String timeStr) {
      try {
        final parts = timeStr.split(':');
        return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      } catch (e) {
        return const TimeOfDay(hour: 0, minute: 0);
      }
    }

    return TaskModel(
      id: docId,
      uid: map['uid'] ?? '',
      title: map['title'] ?? '',
      category: map['category'] ?? 'Task',
      status: map['status'] ?? 'Upcoming',
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      startTime: map['startTime'] != null ? parseTime(map['startTime']) : const TimeOfDay(hour: 9, minute: 0),
      endTime: map['endTime'] != null ? parseTime(map['endTime']) : const TimeOfDay(hour: 10, minute: 0),
      progress: map['progress'] ?? 0,
      isPinned: map['isPinned'] ?? false,
      pinnedAt: (map['pinnedAt'] as Timestamp?)?.toDate(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
