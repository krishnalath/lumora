import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, dynamic>> _entries = [
    {
      'date': 'TODAY',
      'tag': 'CALM',
      'tagColor': const Color(0xFF00E5FF).withOpacity(0.15),
      'tagTextColor': const Color(0xFF00E5FF),
      'title': 'Finding stillness in the morning light',
      'preview':
          'The air felt particularly crisp this morning. I took ten minutes to just sit with my tea, watching th...',
      'time': '08:45 AM',
      'location': 'Home Sanctuary',
      'cardColor': const Color(0xFF1E212B),
      'showArrow': false,
      'titleColor': Colors.white,
      'previewColor': Colors.grey,
    },
    {
      'date': 'Oct 24',
      'title': 'Focus Sessions',
      'preview':
          'Managed to complete the deep work cycle today without interruptions. The new ritual is starting to take hold.',
      'cardColor': const Color(0xFF2A2E3B),
      'showArrow': true,
      'titleColor': const Color(0xFF00E5FF),
      'previewColor': Colors.grey,
    },
    {
      'date': 'OCT 22',
      'title': 'Gratitude List',
      'isList': true,
      'items': ['Warm coffee', 'Finished project', 'Evening walk'],
      'cardColor': const Color(0xFF1E212B),
      'showArrow': false,
      'titleColor': Colors.white,
    },
    {
      'date': 'OCT 21',
      'title': 'Evening Reflections',
      'preview':
          'The sunset was a vibrant mix of oranges and purples. Reminded me that...',
      'cardColor': const Color(0xFF1E212B),
      'showArrow': false,
      'titleColor': Colors.white,
      'previewColor': Colors.grey,
    },
    {
      'date': 'OCT 19',
      'title': 'Note to self',
      'preview':
          '"Be patient with yourself. Nothing in nature blooms all year."',
      'cardColor': const Color(0xFF2A2E3B),
      'showArrow': false,
      'titleColor': Colors.white,
      'previewColor': Colors.grey,
      'isItalic': true,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: AppTheme.primary,
        elevation: 4,
        child: const Icon(Icons.add, color: Colors.white, size: 28),
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
                      const CircleAvatar(
                        radius: 20,
                        backgroundColor: Color(0xFFE2E8F0),
                        child: Icon(Icons.person, color: Color(0xFF64748B)),
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

                  // Search bar
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.cardGrey,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.search,
                          color: AppTheme.textLight,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            style: GoogleFonts.dmSans(
                              fontSize: 14,
                              color: AppTheme.textDark,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Search through your journey...',
                              hintStyle: GoogleFonts.dmSans(
                                fontSize: 14,
                                color: AppTheme.textLight,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),

            // Entries list
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
                itemCount: _entries.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final entry = _entries[index];
                  return _JournalCard(entry: entry);
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
  final Map<String, dynamic> entry;

  const _JournalCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final isTransparent = entry['cardColor'] == Colors.transparent;
    final isList = entry['isList'] == true;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isTransparent ? AppTheme.background : entry['cardColor'],
        borderRadius: BorderRadius.circular(16),
        boxShadow: isTransparent
            ? null
            : [
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                entry['date'] as String,
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
              if (entry['tag'] != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: entry['tagColor'] as Color,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    entry['tag'] as String,
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: entry['tagTextColor'] as Color,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            entry['title'] as String,
            style: GoogleFonts.dmSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: entry['titleColor'] as Color,
              height: 1.3,
            ),
          ),
          if (isList) ...[
            const SizedBox(height: 8),
            ...(entry['items'] as List<String>).map(
              (item) => Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '• $item',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
          ] else if (entry['preview'] != null) ...[
            const SizedBox(height: 6),
            Text(
              entry['preview'] as String,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: entry['previewColor'] as Color? ?? Colors.grey,
                height: 1.5,
                fontStyle: entry['isItalic'] == true
                    ? FontStyle.italic
                    : FontStyle.normal,
              ),
            ),
          ],
          if (entry['time'] != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.access_time,
                  size: 13,
                  color: Colors.grey,
                ),
                const SizedBox(width: 4),
                Text(
                  entry['time'] as String,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(
                  Icons.location_on_outlined,
                  size: 13,
                  color: Colors.grey,
                ),
                const SizedBox(width: 4),
                Text(
                  entry['location'] as String,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ],
          if (entry['showArrow'] == true) ...[
            const SizedBox(height: 8),
            const Align(
              alignment: Alignment.centerRight,
              child: Icon(
                Icons.arrow_forward,
                color: Color(0xFF00E5FF),
                size: 20,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
