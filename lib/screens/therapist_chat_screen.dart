import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../services/firestore_service.dart';

/// Chat screen from the therapist's perspective.
/// Messages sent here are written with `isUser: false`.
class TherapistChatScreen extends StatefulWidget {
  final String chatId;
  final String patientName;
  final String therapistName;

  const TherapistChatScreen({
    super.key,
    required this.chatId,
    required this.patientName,
    required this.therapistName,
  });

  @override
  State<TherapistChatScreen> createState() => _TherapistChatScreenState();
}

class _TherapistChatScreenState extends State<TherapistChatScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    setState(() => _isSending = true);

    try {
      // Write message as the therapist (isUser: false)
      await FirebaseFirestore.instance
          .collection('care_chats')
          .doc(widget.chatId)
          .collection('messages')
          .add({
        'uid': '', // therapist UID not needed for display
        'senderName': widget.therapistName,
        'text': text,
        'isVoiceNote': false,
        'isUser': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update chat metadata
      await FirebaseFirestore.instance
          .collection('care_chats')
          .doc(widget.chatId)
          .set({
        'lastMessage': text,
        'lastMessageAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }

    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0F14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E212B),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.primary.withOpacity(0.2),
              child:
                  const Icon(Icons.person, color: AppTheme.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.patientName,
                  style: GoogleFonts.dmSans(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'Patient',
                  style: GoogleFonts.dmSans(
                    color: AppTheme.accentLavender,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Therapist notice ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: AppTheme.accentLavender.withOpacity(0.08),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.medical_services,
                    color: AppTheme.accentLavender, size: 14),
                const SizedBox(width: 8),
                Text(
                  'Responding as ${widget.therapistName}',
                  style: GoogleFonts.dmSans(
                    color: AppTheme.accentLavender.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // ── Messages list ──
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestoreService.getChatMessages(widget.chatId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child:
                        CircularProgressIndicator(color: AppTheme.accentLavender),
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.chat_bubble_outline,
                            color: Colors.white12, size: 64),
                        const SizedBox(height: 16),
                        Text(
                          'No messages from ${widget.patientName} yet',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.dmSans(
                            color: Colors.white30,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final isUser = data['isUser'] as bool? ?? true;
                    final text = data['text'] as String? ?? '';
                    final timestamp = data['createdAt'] as Timestamp?;
                    final timeStr = timestamp != null
                        ? '${timestamp.toDate().hour}:${timestamp.toDate().minute.toString().padLeft(2, '0')}'
                        : '';

                    // For therapist view: patient messages (isUser=true) on left,
                    // therapist messages (isUser=false) on right
                    final isTherapistMessage = !isUser;

                    return Align(
                      alignment: isTherapistMessage
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isTherapistMessage
                              ? AppTheme.accentLavender.withOpacity(0.15)
                              : const Color(0xFF1E212B),
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(18),
                            topRight: const Radius.circular(18),
                            bottomLeft:
                                Radius.circular(isTherapistMessage ? 18 : 4),
                            bottomRight:
                                Radius.circular(isTherapistMessage ? 4 : 18),
                          ),
                          border: Border.all(
                            color: isTherapistMessage
                                ? AppTheme.accentLavender.withOpacity(0.2)
                                : Colors.white.withOpacity(0.05),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!isTherapistMessage)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  widget.patientName,
                                  style: GoogleFonts.dmSans(
                                    color: AppTheme.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            Text(
                              text,
                              style: GoogleFonts.dmSans(
                                color: Colors.white,
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              timeStr,
                              style: GoogleFonts.dmSans(
                                color: Colors.white24,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ).animate().fadeIn(duration: 200.ms);
                  },
                );
              },
            ),
          ),

          // ── Input bar ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF1E212B),
              border: Border(
                top: BorderSide(color: Color(0xFF2A2E3B), width: 1),
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2E3B),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _messageController,
                        style: GoogleFonts.dmSans(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Reply to ${widget.patientName}...',
                          hintStyle: GoogleFonts.dmSans(
                            color: Colors.white30,
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 12),
                        ),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _isSending ? null : _sendMessage,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.accentLavender,
                            AppTheme.primary,
                          ],
                        ),
                      ),
                      child: _isSending
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.send_rounded,
                              color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
