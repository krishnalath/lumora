import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import 'create_post_screen.dart';
import 'comments_screen.dart';
import '../services/firestore_service.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  int _selectedFilter = 0;

  final List<String> _filters = [
    'Trending',
    'New',
    'Exam Stress',
    'Relationships',
    'Self Care',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'LUMORA',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF161A23),
                      letterSpacing: 6.0,
                    ),
                  ),
                  const CircleAvatar(
                    radius: 20,
                    backgroundColor: Color(0xFFE2E8F0),
                    child: Icon(Icons.person, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Title
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'Safe Space.\n',
                      style: GoogleFonts.dmSans(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textDark,
                        height: 1.2,
                      ),
                    ),
                    TextSpan(
                      text: 'Shared Journey.',
                      style: GoogleFonts.dmSans(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF161A23),
                        fontStyle: FontStyle.italic,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "You're not alone. Share what's on your mind\nanonymously with students who understand.",
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: AppTheme.textMedium,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),

              // Post Anonymously button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const CreatePostScreen(),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.edit_note_rounded,
                    color: Colors.black,
                    size: 20,
                  ),
                  label: Text(
                    'Post Anonymously',
                    style: GoogleFonts.dmSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E5FF),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(_filters.length, (index) {
                    final isSelected = _selectedFilter == index;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedFilter = index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF00E5FF)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: isSelected ? null : Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          _filters[index],
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? Colors.black
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 16),

              // Posts
              StreamBuilder<QuerySnapshot>(
                stream: FirestoreService().getPosts(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(40.0),
                      child: Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF))),
                    );
                  }
                  if (snapshot.hasError) {
                    return const Center(child: Text('Error loading posts.'));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40.0),
                        child: Text(
                          'No posts yet. Be the first to share!',
                          style: GoogleFonts.dmSans(color: Colors.grey),
                        ),
                      ),
                    );
                  }

                  var docs = snapshot.data!.docs.toList();
                  final selectedCategory = _filters[_selectedFilter];

                  // Client-side filtering
                  if (selectedCategory != 'Trending' && selectedCategory != 'New') {
                    docs = docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return data['category'] == selectedCategory;
                    }).toList();
                  }

                  // Client-side sorting for Trending
                  if (selectedCategory == 'Trending') {
                    docs.sort((a, b) {
                      final aLikes = (a.data() as Map<String, dynamic>)['likes'] ?? 0;
                      final bLikes = (b.data() as Map<String, dynamic>)['likes'] ?? 0;
                      return (bLikes as int).compareTo(aLikes as int);
                    });
                  }

                  if (docs.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40.0),
                        child: Text(
                          'No posts in this category yet.',
                          style: GoogleFonts.dmSans(color: Colors.grey),
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: List.generate(docs.length, (index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>;

                      String timeString = 'Just now';
                      if (data['createdAt'] != null) {
                        final DateTime dt = (data['createdAt'] as Timestamp).toDate();
                        final diff = DateTime.now().difference(dt);
                        if (diff.inDays > 0) {
                          timeString = '${diff.inDays} days ago';
                        } else if (diff.inHours > 0) {
                          timeString = '${diff.inHours} hours ago';
                        } else if (diff.inMinutes > 0) {
                          timeString = '${diff.inMinutes} mins ago';
                        }
                      }

                      final bool isEven = index % 2 == 0;
                      final cardColor = isEven ? const Color(0xFF1E212B) : const Color(0xFF2A2E3B);

                      final postMap = {
                        'docId': doc.id,
                        'username': data['username'] ?? 'Anonymous',
                        'timeAgo': timeString,
                        'category': data['category'] ?? 'General',
                        'title': data['title'] ?? '',
                        'body': data['body'] ?? '',
                        'likedBy': List<String>.from(data['likedBy'] ?? []),
                        'comments': data['comments'] ?? 0,
                        'cardColor': cardColor,
                        'highlight': index == 0,
                        'reaction': null,
                        'reactionCount': null,
                      };

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _PostCard(post: postMap),
                      );
                    }),
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostCard extends StatefulWidget {
  final Map<String, dynamic> post;

  const _PostCard({required this.post});

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  bool _likeLoading = false;

  void _toggleLike() async {
    if (_likeLoading) return;
    final docId = widget.post['docId'] as String?;
    if (docId == null) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final likedBy = widget.post['likedBy'] as List<String>? ?? [];
    final isLiked = likedBy.contains(uid);
    setState(() => _likeLoading = true);
    try {
      await FirestoreService().toggleLike(docId, isLiked);
    } finally {
      setState(() => _likeLoading = false);
    }
  }

  void _openComments() {
    final docId = widget.post['docId'] as String?;
    if (docId == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CommentsScreen(
          postId: docId,
          postTitle: widget.post['title'] as String,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final hasReaction = post['reaction'] != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: post['cardColor'] as Color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author row
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: post['highlight'] == true
                      ? AppTheme.primary
                      : AppTheme.cardGrey,
                ),
                child: Icon(
                  post['highlight'] == true
                      ? Icons.smart_toy_rounded
                      : Icons.person_outline,
                  color: post['highlight'] == true
                      ? Colors.black
                      : Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post['username'] as String,
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '${post['timeAgo']} in ${post['category']}',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.more_horiz, color: Colors.grey, size: 20),
            ],
          ),
          const SizedBox(height: 10),

          // Title
          Text(
            post['title'] as String,
            style: GoogleFonts.dmSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 6),

          // Body
          Text(
            post['body'] as String,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: Colors.grey[300],
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),

          // Reactions / likes
          if (hasReaction) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.volunteer_activism,
                    color: Color(0xFF00E5FF),
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    "${post['reaction']} (${post['reactionCount']})",
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF00E5FF),
                    ),
                  ),
                  const SizedBox(width: 20),
                  const Icon(
                    Icons.chat_bubble_outline,
                    color: Colors.grey,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${post['comments']}',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Row(
              children: [
                GestureDetector(
                  onTap: _toggleLike,
                  child: Row(
                    children: [
                      Builder(builder: (context) {
                        final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
                        final likedBy = widget.post['likedBy'] as List<String>? ?? [];
                        final isLiked = likedBy.contains(uid);
                        return Icon(
                          isLiked ? Icons.favorite : Icons.favorite_border,
                          color: isLiked ? Colors.red : Colors.grey,
                          size: 18,
                        );
                      }),
                      const SizedBox(width: 4),
                      Builder(builder: (context) {
                        final likedBy = widget.post['likedBy'] as List<String>? ?? [];
                        return Text(
                          '${likedBy.length}',
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                GestureDetector(
                  onTap: _openComments,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.chat_bubble_outline,
                        color: Colors.grey,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${post['comments']}',
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
