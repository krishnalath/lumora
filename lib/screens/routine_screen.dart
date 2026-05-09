import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../native_bridge.dart';
import '../theme/app_theme.dart';

enum RoutineType { morning, afternoon, night }

class RoutineScreen extends StatefulWidget {
  final RoutineType routineType;
  const RoutineScreen({super.key, required this.routineType});

  @override
  State<RoutineScreen> createState() => _RoutineScreenState();
}

class _RoutineScreenState extends State<RoutineScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Step 1 Data
  String? _selectedFeeling;
  final List<String> _feelings = [
    'Rewarding', 'Productive', 'Ordinary',
    'Peaceful', 'Content', 'Relieved',
    'Stressed', 'Worryful', 'Exciting',
    'Frustrating', 'Tiring', 'Sad'
  ];

  bool _isSaving = false;

  void _nextPage() {
    if (_selectedFeeling == null) {
      AppTheme.showCustomSnackBar(context, 'Please select how you are feeling.');
      return;
    }
    _saveRoutine();
  }

  Future<void> _saveRoutine() async {
    setState(() => _isSaving = true);
    final prefs = await SharedPreferences.getInstance();
    
    // Save Mood
    int moodScore = 5;
    if (_selectedFeeling != null) {
      if (['Rewarding', 'Productive', 'Exciting'].contains(_selectedFeeling)) moodScore = 9;
      else if (['Peaceful', 'Content', 'Relieved'].contains(_selectedFeeling)) moodScore = 7;
      else if (['Ordinary'].contains(_selectedFeeling)) moodScore = 5;
      else if (['Stressed', 'Worryful', 'Tiring'].contains(_selectedFeeling)) moodScore = 3;
      else if (['Frustrating', 'Sad'].contains(_selectedFeeling)) moodScore = 1;
    }
    await prefs.setInt('latest_mood', moodScore);
    await prefs.setInt('latest_energy', moodScore); 


    if (mounted) {
      Navigator.pop(context, true); 
    }
  }



  @override
  Widget build(BuildContext context) {
    String themeTitle = 'Morning';
    IconData themeIcon = Icons.wb_sunny_rounded;
    String moodQuestion = 'How are you feeling?';
    
    if (widget.routineType == RoutineType.afternoon) {
      themeTitle = 'Afternoon';
      themeIcon = Icons.wb_cloudy_rounded;
      moodQuestion = 'How is your day going?';
    } else if (widget.routineType == RoutineType.night) {
      themeTitle = 'Night';
      themeIcon = Icons.nights_stay_rounded;
      moodQuestion = 'How was your day?';
    }


    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF161A23), size: 20),
                    onPressed: () {
                      if (_currentPage == 1) {
                        _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                      } else {
                        Navigator.pop(context);
                      }
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (idx) => setState(() => _currentPage = idx),
                children: [
                  // PAGE 1: MOOD
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF252A36),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Row(
                            children: [
                              Icon(themeIcon, color: const Color(0xFF00E5FF), size: 36),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$themeTitle Check-in',
                                    style: GoogleFonts.dmSans(color: const Color(0xFF00E5FF), fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    moodQuestion,
                                    style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 18),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        Wrap(
                          spacing: 12,
                          runSpacing: 16,
                          children: _feelings.map((feeling) {
                            final isSelected = _selectedFeeling == feeling;
                            return GestureDetector(
                              onTap: () => setState(() => _selectedFeeling = feeling),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFF00E5FF) : const Color(0xFF252A36),
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Text(
                                  feeling,
                                  style: GoogleFonts.dmSans(
                                    color: isSelected ? Colors.black : Colors.white70,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),

                ],
              ),
            ),
            
            // Floating Action Button
            Padding(
              padding: const EdgeInsets.only(right: 24, bottom: 24),
              child: Align(
                alignment: Alignment.bottomRight,
                child: GestureDetector(
                  onTap: _isSaving ? null : _nextPage,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E5FF),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00E5FF).withOpacity(0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: _isSaving
                        ? const Center(child: CircularProgressIndicator(color: Colors.black))
                        : Icon(
                            Icons.check_rounded,
                            color: Colors.black,
                            size: 24,
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
