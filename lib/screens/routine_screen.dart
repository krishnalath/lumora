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

  // Step 2 Data
  double _sleepHours = 7.0;
  int _sleepQuality = 1; // 0 = Poor, 1 = Fair, 2 = Excellent
  bool _isSaving = false;

  void _nextPage() {
    if (_currentPage == 0) {
      if (_selectedFeeling == null) {
        AppTheme.showCustomSnackBar(context, 'Please select how you are feeling.');
        return;
      }
      if (widget.routineType != RoutineType.morning) {
        // Afternoon/Night routines only have 1 page
        _saveRoutine();
      } else {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    } else {
      _saveRoutine();
    }
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

    // Save Sleep (only for morning)
    if (widget.routineType == RoutineType.morning) {
      final String historyJson = prefs.getString('sleep_history_v2') ?? '[]';
      List<Map<String, dynamic>> history = [];
      try {
        history = List<Map<String, dynamic>>.from(json.decode(historyJson));
      } catch (_) {}
      
      final todayWeekday = DateTime.now().weekday;
      final dayLabel = ['M', 'T', 'W', 'T', 'F', 'S', 'S'][todayWeekday - 1];
      
      int calculatedQuality = 1;
      if (_sleepHours < 6) {
        calculatedQuality = 0; // Poor
      } else if (_sleepHours >= 6 && _sleepHours <= 8) {
        calculatedQuality = 2; // Excellent (changed from Fair to fit logic better, wait actually let's stick to simple logic: <5 poor, 5-7 fair, >7 excellent)
      } else {
        calculatedQuality = 2; 
      }
      // Wait let's do: < 5 -> 0, 5 to 7.5 -> 1, > 7.5 -> 2.
      if (_sleepHours < 5.0) {
        calculatedQuality = 0;
      } else if (_sleepHours >= 5.0 && _sleepHours < 7.5) {
        calculatedQuality = 1;
      } else {
        calculatedQuality = 2;
      }

      final newEntry = {
        'day': dayLabel,
        'hours': _sleepHours,
        'quality': calculatedQuality,
        'timestamp': DateTime.now().toIso8601String(),
      };

      // Check if entry for today exists and replace it, otherwise append
      int existingIndex = history.indexWhere((log) => DateTime.parse(log['timestamp']).weekday == todayWeekday);
      if (existingIndex != -1) {
        history[existingIndex] = newEntry;
      } else {
        history.add(newEntry);
        if (history.length > 7) history.removeAt(0);
      }
      
      await prefs.setString('sleep_history_v2', json.encode(history));
      
      String qualityStr = calculatedQuality == 0 ? "Poor" : (calculatedQuality == 1 ? "Fair" : "Excellent");
      final sleepText = "User slept for ${_sleepHours.toStringAsFixed(1)} hours with $qualityStr quality on ${DateTime.now().toIso8601String()}. Mood today was $_selectedFeeling.";
      await prefs.setString('latest_sleep_data', sleepText);
      await prefs.setDouble('latest_sleep_hours', _sleepHours);
      await prefs.setString('latest_sleep_quality', qualityStr);

      try {
        final model = GenerativeModel(
          model: 'gemini-embedding-001',
          apiKey: dotenv.env['GEMINI_API_KEY'] ?? '',
        );
        final response = await model.embedContent(Content.text(sleepText));
        VectorEngineBridge.insertVector(DateTime.now().millisecondsSinceEpoch % 2147483647, response.embedding.values);
      } catch (e) {
        debugPrint("Failed to save embedding: $e");
      }
    }

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

    final isMorning = widget.routineType == RoutineType.morning;

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
                                    isMorning ? '$themeTitle Check-in 1/2' : '$themeTitle Check-in',
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

                  // PAGE 2: SLEEP
                  if (isMorning)
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
                                const Icon(Icons.bedtime_rounded, color: Color(0xFF00E5FF), size: 36),
                                const SizedBox(width: 16),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$themeTitle Check-in 2/2',
                                      style: GoogleFonts.dmSans(color: const Color(0xFF00E5FF), fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'How did you sleep?',
                                      style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 18),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                          Text(
                            'Hours Slept: ${_sleepHours.toStringAsFixed(1)} hrs',
                            style: GoogleFonts.dmSans(color: Color(0xFF161A23), fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          SliderTheme(
                            data: SliderThemeData(
                              trackHeight: 6,
                              activeTrackColor: const Color(0xFF00E5FF),
                              inactiveTrackColor: Colors.black.withOpacity(0.1),
                              thumbColor: const Color(0xFF161A23),
                            ),
                            child: Slider(
                              value: _sleepHours,
                              min: 0,
                              max: 12,
                              divisions: 24,
                              onChanged: (val) => setState(() => _sleepHours = val),
                            ),
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
                            (_currentPage == 0 && isMorning) ? Icons.arrow_forward_ios_rounded : Icons.check_rounded,
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
