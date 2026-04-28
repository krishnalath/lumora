import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
}
