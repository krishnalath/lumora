import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> createPost(String title, String body, String category) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Must be logged in to post');

    await _db.collection('posts').add({
      'username': user.displayName ?? 'Anonymous',
      'title': title,
      'body': body,
      'category': category,
      'createdAt': FieldValue.serverTimestamp(),
      'likes': 0,
      'comments': 0,
      'uid': user.uid,
    });
  }

  Stream<QuerySnapshot> getPosts() {
    return _db
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> toggleLike(String postId, bool isLiked) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final ref = _db.collection('posts').doc(postId);
    if (isLiked) {
      await ref.update({'likedBy': FieldValue.arrayRemove([user.uid])});
    } else {
      await ref.update({'likedBy': FieldValue.arrayUnion([user.uid])});
    }
  }

  Future<void> addComment(String postId, String text) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Must be logged in to comment');

    final postRef = _db.collection('posts').doc(postId);
    await postRef.collection('comments').add({
      'username': user.displayName ?? 'Anonymous',
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await postRef.update({'comments': FieldValue.increment(1)});
  }

  Stream<QuerySnapshot> getComments(String postId) {
    return _db
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  // Journal Methods
  Future<void> createJournalEntry({
    required String title,
    required String content,
    required String tag,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Must be logged in to journal');

    final now = DateTime.now();
    await _db.collection('journals').add({
      'uid': user.uid,
      'title': title,
      'content': content,
      'tag': tag.toUpperCase(),
      'date': '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> getJournalEntries() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _db
        .collection('journals')
        .where('uid', isEqualTo: user.uid)
        // .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> updateJournalEntry(String entryId, Map<String, dynamic> data) async {
    await _db.collection('journals').doc(entryId).update(data);
  }

  Future<void> deleteJournalEntry(String entryId) async {
    await _db.collection('journals').doc(entryId).delete();
  }

  // Task Methods
  Future<void> createTask({
    required String title,
    required String category,
    required String status,
    required DateTime date,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    int progress = 0,
    bool isPinned = false,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Must be logged in to manage tasks');

    await _db.collection('tasks').add({
      'uid': user.uid,
      'title': title,
      'category': category,
      'status': status,
      'date': Timestamp.fromDate(DateTime(date.year, date.month, date.day)), // store pure date for easier querying
      'startTime': '${startTime.hour}:${startTime.minute}',
      'endTime': '${endTime.hour}:${endTime.minute}',
      'progress': progress,
      'isPinned': isPinned,
      'pinnedAt': isPinned ? FieldValue.serverTimestamp() : null,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> getTasksForDate(DateTime date) {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    // Reset date to midnight for exact match if we saved it as pure date
    final targetDate = DateTime(date.year, date.month, date.day);
    
    return _db
        .collection('tasks')
        .where('uid', isEqualTo: user.uid)
        .where('date', isEqualTo: Timestamp.fromDate(targetDate))
        .snapshots();
  }

  Future<void> updateTask(String taskId, Map<String, dynamic> data) async {
    await _db.collection('tasks').doc(taskId).update(data);
  }

  Future<void> deleteTask(String taskId) async {
    await _db.collection('tasks').doc(taskId).delete();
  }

  // ── Sleep Log Methods ───────────────────────────────────────────

  /// Save or update a single sleep record in Firestore.
  /// Uses the record's `id` as the document ID for idempotent upserts.
  Future<void> saveSleepRecord(Map<String, dynamic> recordJson) async {
    final user = _auth.currentUser;
    if (user == null) return; // Silently skip if not logged in

    final docId = recordJson['id'] as String;
    await _db
        .collection('sleep_records')
        .doc(docId)
        .set({
      ...recordJson,
      'uid': user.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Fetch all sleep records for the current ISO week.
  /// Returns them sorted by sleepStart ascending.
  Future<List<Map<String, dynamic>>> getCurrentWeekSleepRecords({
    required DateTime weekStart,
    required DateTime weekEnd,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final snapshot = await _db
        .collection('sleep_records')
        .where('uid', isEqualTo: user.uid)
        .get();

    final docs = snapshot.docs.map((doc) => doc.data()).toList();
    
    // Filter by weekStart and weekEnd in memory to avoid needing composite indexes
    final startStr = weekStart.toIso8601String();
    final endStr = weekEnd.toIso8601String();
    
    final filtered = docs.where((data) {
      final sleepStart = data['sleepStart'] as String?;
      if (sleepStart == null) return false;
      return sleepStart.compareTo(startStr) >= 0 && sleepStart.compareTo(endStr) < 0;
    }).toList();

    // Sort by sleepStart ascending
    filtered.sort((a, b) {
      final aStart = a['sleepStart'] as String? ?? '';
      final bStart = b['sleepStart'] as String? ?? '';
      return aStart.compareTo(bStart);
    });

    return filtered;
  }

  /// Fetch all sleep records within the last [days] days.
  Future<List<Map<String, dynamic>>> getSleepHistory({int days = 90}) async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final snapshot = await _db
        .collection('sleep_records')
        .where('uid', isEqualTo: user.uid)
        .get();

    final docs = snapshot.docs.map((doc) => doc.data()).toList();
    final cutoffStr = DateTime.now().subtract(Duration(days: days)).toIso8601String();

    final filtered = docs.where((data) {
      final sleepStart = data['sleepStart'] as String?;
      if (sleepStart == null) return false;
      return sleepStart.compareTo(cutoffStr) >= 0;
    }).toList();

    // Sort by sleepStart descending
    filtered.sort((a, b) {
      final aStart = a['sleepStart'] as String? ?? '';
      final bStart = b['sleepStart'] as String? ?? '';
      return bStart.compareTo(aStart);
    });

    return filtered;
  }

  /// Delete a specific sleep record by its ID.
  Future<void> deleteSleepRecord(String recordId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _db
        .collection('sleep_records')
        .doc(recordId)
        .delete();
  }

  /// Save the weekly average history entry to Firestore.
  Future<void> saveSleepWeeklyAverage(Map<String, dynamic> avgData) async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Use a unique document ID per user to prevent collision in top-level collection
    final docId = '${user.uid}_${avgData['year']}_w${avgData['week']}';
    await _db
        .collection('sleep_weekly_averages')
        .doc(docId)
        .set({
      ...avgData,
      'uid': user.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Fetch all weekly average history entries.
  Future<List<Map<String, dynamic>>> getSleepWeeklyAverages() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final snapshot = await _db
        .collection('sleep_weekly_averages')
        .where('uid', isEqualTo: user.uid)
        .get();

    final docs = snapshot.docs.map((doc) => doc.data()).toList();

    // Sort by year descending, then week descending
    docs.sort((a, b) {
      final aYear = a['year'] as int? ?? 0;
      final bYear = b['year'] as int? ?? 0;
      if (aYear != bYear) {
        return bYear.compareTo(aYear);
      }
      final aWeek = a['week'] as int? ?? 0;
      final bWeek = b['week'] as int? ?? 0;
      return bWeek.compareTo(aWeek);
    });

    return docs;
  }

  // ── Care Hub Methods ───────────────────────────────────────────

  Future<void> bookCareSession({
    required String professionalName,
    required DateTime date,
    required TimeOfDay time,
    String? briefing,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Must be logged in to book a session');

    await _db.collection('care_sessions').add({
      'uid': user.uid,
      'patientName': user.displayName ?? 'Patient',
      'professionalName': professionalName,
      'date': Timestamp.fromDate(DateTime(date.year, date.month, date.day)),
      'time': '${time.hour}:${time.minute}',
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      if (briefing != null) 'briefing': briefing,
    });
  }

  // ── Secure Chat Methods ─────────────────────────────────────────

  /// Send a message in a chat thread with a professional.
  /// The chatId is derived from the professional name for simplicity.
  Future<void> sendChatMessage({
    required String chatId,
    required String text,
    bool isVoiceNote = false,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Must be logged in to send messages');

    await _db
        .collection('care_chats')
        .doc(chatId)
        .collection('messages')
        .add({
      'uid': user.uid,
      'senderName': user.displayName ?? 'You',
      'text': text,
      'isVoiceNote': isVoiceNote,
      'isUser': true,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Update the chat metadata (last message preview)
    await _db.collection('care_chats').doc(chatId).set({
      'uid': user.uid,
      'patientName': user.displayName ?? 'Patient',
      'lastMessage': text,
      'lastMessageAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Stream of messages for a specific chat thread (real-time).
  Stream<QuerySnapshot> getChatMessages(String chatId) {
    return _db
        .collection('care_chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots();
  }
}

