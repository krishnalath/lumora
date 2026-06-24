import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Conversation {
  final String id;
  final String title;
  final List<Map<String, dynamic>> messages;
  final DateTime createdAt;
  final DateTime lastModified;

  Conversation({
    required this.id,
    required this.title,
    required this.messages,
    required this.createdAt,
    required this.lastModified,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'messages': messages,
      'createdAt': createdAt.toIso8601String(),
      'lastModified': lastModified.toIso8601String(),
    };
  }

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] as String,
      title: json['title'] as String,
      messages: List<Map<String, dynamic>>.from(json['messages'] as List),
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastModified: DateTime.parse(json['lastModified'] as String),
    );
  }
}

class ConversationService {
  // Base key names — always combined with the user's UID via _key()
  static const String _conversationsBase = 'ai_conversations';
  static const String _currentConversationBase = 'current_conversation_id';

  /// Returns the current Firebase user's UID, or null if not signed in.
  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  /// Returns a user-scoped SharedPreferences key.
  /// Throws if no user is signed in.
  static String _key(String base) {
    final uid = _uid;
    if (uid == null) {
      throw StateError('No user signed in — cannot access conversation storage');
    }
    return '${uid}_$base';
  }

  // Save a conversation
  static Future<void> saveConversation(Conversation conversation) async {
    final prefs = await SharedPreferences.getInstance();
    final conversations = await getAllConversations();

    // Remove if exists and add updated version
    conversations.removeWhere((c) => c.id == conversation.id);
    conversations.add(conversation);

    // Sort by last modified (most recent first)
    conversations.sort((a, b) => b.lastModified.compareTo(a.lastModified));

    final jsonList = conversations.map((c) => jsonEncode(c.toJson())).toList();
    await prefs.setStringList(_key(_conversationsBase), jsonList);
  }

  // Get all conversations
  static Future<List<Conversation>> getAllConversations() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_key(_conversationsBase)) ?? [];

    return jsonList
        .map((json) => Conversation.fromJson(jsonDecode(json)))
        .toList();
  }

  // Get conversation by ID
  static Future<Conversation?> getConversation(String id) async {
    final conversations = await getAllConversations();
    try {
      return conversations.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }

  // Delete conversation
  static Future<void> deleteConversation(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final conversations = await getAllConversations();
    conversations.removeWhere((c) => c.id == id);

    final jsonList = conversations.map((c) => jsonEncode(c.toJson())).toList();
    await prefs.setStringList(_key(_conversationsBase), jsonList);
  }

  // Create new conversation
  static Conversation createNewConversation() {
    final now = DateTime.now();
    return Conversation(
      id: '${now.millisecondsSinceEpoch}',
      title: 'Chat ${now.hour}:${now.minute.toString().padLeft(2, '0')}',
      messages: [],
      createdAt: now,
      lastModified: now,
    );
  }

  // Generate title from first message
  static String generateTitleFromMessage(String message) {
    final words = message.split(' ');
    final title = words.take(5).join(' ');
    return title.length > 30 ? '${title.substring(0, 30)}...' : title;
  }

  // Set current conversation
  static Future<void> setCurrentConversation(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(_currentConversationBase), id);
  }

  // Get current conversation
  static Future<String?> getCurrentConversation() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key(_currentConversationBase));
  }

  // Clear all conversations for the current user
  static Future<void> clearAllConversations() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(_conversationsBase));
    await prefs.remove(_key(_currentConversationBase));
  }

  // Clear only the current session pointer (keeps history intact)
  static Future<void> clearCurrentConversation() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(_currentConversationBase));
  }

  /// Clear local conversation cache for the current user.
  /// Should be called on sign-out to prevent data leaking to the next user.
  static Future<void> clearLocalData() async {
    final uid = _uid;
    if (uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('${uid}_$_conversationsBase');
    await prefs.remove('${uid}_$_currentConversationBase');
  }
}
