import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import 'create_journal_screen.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  DateTime? _selectedDate;
  String _selectedTag = 'All';

  final List<String> _tags = ['All', 'Calm', 'Grateful', 'Anxious', 'Reflective', 'Inspired', 'Tired'];

  Color _getTagColor(String tag) {
    switch (tag.toUpperCase()) {
      case 'CALM': return const Color(0xFF00E5FF).withOpacity(0.15);
      case 'GRATEFUL': return Colors.green.withOpacity(0.15);
      case 'ANXIOUS': return Colors.orange.withOpacity(0.15);
      case 'REFLECTIVE': return Colors.purple.withOpacity(0.15);
      case 'INSPIRED': return Colors.amber.withOpacity(0.15);
      case 'TIRED': return Colors.blueGrey.withOpacity(0.15);
      default: return Colors.grey.withOpacity(0.15);
    }
  }

  Color _getTagTextColor(String tag) {
    switch (tag.toUpperCase()) {
      case 'CALM': return const Color(0xFF00E5FF);
      case 'GRATEFUL': return Colors.green;
      case 'ANXIOUS': return Colors.orange;
      case 'REFLECTIVE': return Colors.purple;
      case 'INSPIRED': return Colors.amber;
      case 'TIRED': return Colors.blueGrey;
      default: return Colors.grey;
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF00E5FF),
              onPrimary: Colors.black,
              surface: Color(0xFF1E212B),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF1E212B),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateJournalScreen()),
          );
        },
        backgroundColor: AppTheme.primary,
        elevation: 4,
        child: const Icon(Icons.add, color: Colors.black, size: 28),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                      PopupMenuButton<String>(
                        color: const Color(0xFF1E212B),
                        elevation: 8,
                        onSelected: (value) async {
                          if (value == 'signout') {
                            await AuthService().signOut();
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'signout',
                            child: Row(
                              children: [
                                const Icon(Icons.logout, color: Color(0xFF00E5FF), size: 20),
                                const SizedBox(width: 12),
                                Text(
                                  'Sign Out', 
                                  style: GoogleFonts.dmSans(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.white.withOpacity(0.1)),
                        ),
                        offset: const Offset(0, 45),
                        child: const CircleAvatar(
                          radius: 20,
                          backgroundColor: Color(0xFFE2E8F0),
                          child: Icon(Icons.person, color: Color(0xFF64748B)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'My Reflections',
                    style: GoogleFonts.dmSans(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF161A23),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your private sanctuary for thoughts,\ngrowth, and moments of clarity.',
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      color: AppTheme.textMedium,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Date Picker
                  GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E212B),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, color: Color(0xFF00E5FF), size: 18),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _selectedDate != null
                                  ? DateFormat('MMMM dd, yyyy').format(_selectedDate!)
                                  : 'Filter by date...',
                              style: GoogleFonts.dmSans(
                                fontSize: 14,
                                color: _selectedDate != null ? Colors.white : Colors.white54,
                              ),
                            ),
                          ),
                          if (_selectedDate != null)
                            GestureDetector(
                              onTap: () => setState(() => _selectedDate = null),
                              child: const Icon(Icons.close, color: Colors.white54, size: 18),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Category Filter Chips
                  SizedBox(
                    height: 38,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _tags.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final tag = _tags[index];
                        final isSelected = _selectedTag == tag;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedTag = tag),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF00E5FF) : const Color(0xFF2A2E3B),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              tag,
                              style: GoogleFonts.dmSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isSelected ? Colors.black : Colors.white60,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),

            // Entries list
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirestoreService().getJournalEntries(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Text(
                          'Error: ${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.dmSans(color: Colors.redAccent),
                        ),
                      ),
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];
                  
                  // Filter by date and category
                  final filteredDocs = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;

                    // Filter by category
                    if (_selectedTag != 'All') {
                      final tag = (data['tag'] ?? '').toString().toUpperCase();
                      if (tag != _selectedTag.toUpperCase()) return false;
                    }

                    // Filter by date
                    if (_selectedDate != null) {
                      final dateStr = data['date'] as String?;
                      if (dateStr != null) {
                        final selectedStr = '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}';
                        if (dateStr != selectedStr) return false;
                      } else {
                        // Fallback to timestamp comparison for older entries
                        final timestamp = data['createdAt'] as Timestamp?;
                        if (timestamp != null) {
                          final entryDate = timestamp.toDate();
                          if (entryDate.year != _selectedDate!.year ||
                              entryDate.month != _selectedDate!.month ||
                              entryDate.day != _selectedDate!.day) return false;
                        }
                      }
                    }

                    return true;
                  }).toList();

                  final hasActiveFilter = _selectedDate != null || _selectedTag != 'All';

                  if (filteredDocs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.edit_note, size: 64, color: AppTheme.textLight.withOpacity(0.5)),
                          const SizedBox(height: 16),
                          Text(
                            hasActiveFilter
                                ? 'No entries match your filters.'
                                : 'No entries yet. Start writing!',
                            style: GoogleFonts.dmSans(color: AppTheme.textLight),
                          ),
                          if (hasActiveFilter) ...[
                            const SizedBox(height: 12),
                            GestureDetector(
                              onTap: () => setState(() {
                                _selectedDate = null;
                                _selectedTag = 'All';
                              }),
                              child: Text(
                                'Clear filters',
                                style: GoogleFonts.dmSans(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 4,
                    ),
                    itemCount: filteredDocs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final doc = filteredDocs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final timestamp = data['createdAt'] as Timestamp?;
                      final dateStr = timestamp != null 
                          ? DateFormat('MMM dd').format(timestamp.toDate())
                          : 'Recent';
                      final timeStr = timestamp != null
                          ? DateFormat('hh:mm a').format(timestamp.toDate())
                          : '';

                      return _JournalCard(
                        id: doc.id,
                        date: dateStr,
                        tag: data['tag'] ?? 'CALM',
                        tagColor: _getTagColor(data['tag'] ?? 'CALM'),
                        tagTextColor: _getTagTextColor(data['tag'] ?? 'CALM'),
                        title: data['title'] ?? '',
                        content: data['content'] ?? '',
                        time: timeStr,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JournalCard extends StatelessWidget {
  final String id;
  final String date;
  final String tag;
  final Color tagColor;
  final Color tagTextColor;
  final String title;
  final String content;
  final String time;

  const _JournalCard({
    required this.id,
    required this.date,
    required this.tag,
    required this.tagColor,
    required this.tagTextColor,
    required this.title,
    required this.content,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => JournalDetailScreen(
              id: id,
              date: date,
              tag: tag,
              tagColor: tagColor,
              tagTextColor: tagTextColor,
              title: title,
              content: content,
              time: time,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1E212B),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  date.toUpperCase(),
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: tagColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    tag,
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: tagTextColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.dmSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(
                fontSize: 14,
                color: Colors.white.withOpacity(0.7),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: Colors.white.withOpacity(0.4)),
                const SizedBox(width: 4),
                Text(
                  time,
                  style: GoogleFonts.dmSans(fontSize: 12, color: Colors.white.withOpacity(0.4)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class JournalDetailScreen extends StatelessWidget {
  final String id;
  final String date;
  final String tag;
  final Color tagColor;
  final Color tagTextColor;
  final String title;
  final String content;
  final String time;

  const JournalDetailScreen({
    super.key,
    required this.id,
    required this.date,
    required this.tag,
    required this.tagColor,
    required this.tagTextColor,
    required this.title,
    required this.content,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: const Color(0xFF1E212B),
                  title: const Text('Delete Entry?', style: TextStyle(color: Colors.white)),
                  content: Text('This action cannot be undone.', style: TextStyle(color: Colors.white.withOpacity(0.7))),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL', style: TextStyle(color: Colors.grey))),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('DELETE', style: TextStyle(color: Colors.redAccent)),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await FirestoreService().deleteJournalEntry(id);
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: tagColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    tag,
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: tagTextColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  date.toUpperCase(),
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: AppTheme.textLight,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: GoogleFonts.dmSans(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppTheme.textDark,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: AppTheme.textLight),
                const SizedBox(width: 6),
                Text(
                  time,
                  style: GoogleFonts.dmSans(fontSize: 14, color: AppTheme.textLight),
                ),
              ],
            ),
            const SizedBox(height: 32),
            const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
            const SizedBox(height: 32),
            Text(
              content,
              style: GoogleFonts.dmSans(
                fontSize: 17,
                height: 1.8,
                color: AppTheme.textMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
