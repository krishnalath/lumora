import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/firestore_service.dart';

class CreateJournalScreen extends StatefulWidget {
  const CreateJournalScreen({super.key});

  @override
  State<CreateJournalScreen> createState() => _CreateJournalScreenState();
}

class _CreateJournalScreenState extends State<CreateJournalScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  String _selectedTag = 'Calm';
  bool _isLoading = false;

  final List<String> _tags = [
    'Calm',
    'Grateful',
    'Anxious',
    'Reflective',
    'Inspired',
    'Tired',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _saveEntry() async {
    if (_titleController.text.trim().isEmpty || _contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in both title and content'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirestoreService().createJournalEntry(
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        tag: _selectedTag,
      );

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppTheme.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveEntry,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                  )
                : Text(
                    'SAVE',
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary,
                      letterSpacing: 1.2,
                    ),
                  ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'New Reflection',
              style: GoogleFonts.dmSans(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Capture this moment of clarity.',
              style: GoogleFonts.dmSans(
                fontSize: 16,
                color: AppTheme.textMedium,
              ),
            ),
            const SizedBox(height: 32),
            
            // Tag Selector
            Text(
              'HOW DO YOU FEEL?',
              style: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: AppTheme.textLight,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _tags.map((tag) {
                final isSelected = _selectedTag == tag;
                return GestureDetector(
                  onTap: () => setState(() => _selectedTag = tag),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.primary : AppTheme.cardGrey,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      tag,
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.black : Colors.white70,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),

            // Title Field
            TextField(
              controller: _titleController,
              style: GoogleFonts.dmSans(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppTheme.textDark,
              ),
              decoration: InputDecoration(
                hintText: 'Title of your journey...',
                hintStyle: GoogleFonts.dmSans(color: AppTheme.textLight),
                border: InputBorder.none,
              ),
            ),
            const Divider(height: 32, thickness: 1, color: Color(0xFFE2E8F0)),

            // Content Field
            TextField(
              controller: _contentController,
              maxLines: null,
              style: GoogleFonts.dmSans(
                fontSize: 16,
                height: 1.6,
                color: AppTheme.textMedium,
              ),
              decoration: InputDecoration(
                hintText: 'Start writing your heart out...',
                hintStyle: GoogleFonts.dmSans(color: AppTheme.textLight),
                border: InputBorder.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
