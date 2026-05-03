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
}

