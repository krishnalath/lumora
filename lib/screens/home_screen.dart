import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/quote_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedMoodIndex = 2; // Serene selected by default
  String _quoteText = '"Peace is not the absence of trouble, but the presence of God."';
  String _quoteAuthor = 'UNKNOWN';
  bool _isQuoteLoading = true;

  @override
  void initState() {
    super.initState();
    _loadQuote();
  }

  Future<void> _loadQuote() async {
    final quoteData = await QuoteService.fetchRandomQuote();
    if (mounted) {
      setState(() {
        _quoteText = '"${quoteData['text']}"';
        _quoteAuthor = quoteData['author']!.toUpperCase();
        _isQuoteLoading = false;
      });
    }
  }

  final List<Map<String, String>> _moods = [
    {'emoji': '😔', 'label': 'Low'},
    {'emoji': '😐', 'label': 'Quiet'},
    {'emoji': '😊', 'label': 'Serene'},
    {'emoji': '🤩', 'label': 'Joyful'},
    {'emoji': '🔥', 'label': 'Vibrant'},
  ];

  // Weekly data: 0 = no data, 1-5 = mood level
  final List<Map<String, dynamic>> _weeklyData = [
    {'day': 'M', 'level': 0},
    {'day': 'T', 'level': 1},
    {'day': 'W', 'level': 3},
    {'day': 'T', 'level': 3},
    {'day': 'F', 'level': 2},
    {'day': 'S', 'level': 0},
    {'day': 'S', 'level': 0},
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
              const SizedBox(height: 8),
              Text(
                'Good evening, ${FirebaseAuth.instance.currentUser?.displayName ?? 'User'}.',
                style: GoogleFonts.dmSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textMedium,
                ),
              ),
              const SizedBox(height: 24),
              
              // Energy Card
              const _EnergyCard(),
              
              const SizedBox(height: 32),

              // Daily Check-In Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E212B),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Text(
                        'DAILY CHECK-IN',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(_moods.length, (index) {
                        final isSelected = _selectedMoodIndex == index;
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _selectedMoodIndex = index),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF00E5FF).withOpacity(0.15)
                                  : const Color(0xFF2A2E3B),
                              borderRadius: BorderRadius.circular(16),
                              border: isSelected
                                  ? Border.all(
                                      color: const Color(0xFF00E5FF),
                                      width: 2,
                                    )
                                  : null,
                            ),
                            child: Column(
                              children: [
                                Text(
                                  _moods[index]['emoji']!,
                                  style: const TextStyle(fontSize: 28),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _moods[index]['label']!,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 11,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? const Color(0xFF00E5FF)
                                        : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Weekly Flow Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E212B),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WEEKLY FLOW',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Mostly Serene',
                      style: GoogleFonts.dmSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: _weeklyData.map((data) {
                        final level = data['level'] as int;
                        final hasData = level > 0;
                        final maxHeight = 80.0;
                        final barHeight = hasData
                            ? (level / 5.0) * maxHeight
                            : 0.0;
                        return Column(
                          children: [
                            SizedBox(
                              height: maxHeight,
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: hasData
                                    ? AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 400,
                                        ),
                                        width: 18,
                                        height: barHeight,
                                        decoration: BoxDecoration(
                                          color: level >= 3
                                              ? const Color(0xFF00E5FF)
                                              : Colors.white.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                      )
                                    : Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white.withOpacity(0.1),
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              data['day'] as String,
                              style: GoogleFonts.dmSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withOpacity(0.5),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Quote Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E212B),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Text(
                        '❝',
                        style: TextStyle(
                          fontSize: 48,
                          color: const Color(0xFF00E5FF).withOpacity(0.15),
                          height: 1,
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        _isQuoteLoading 
                          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)))
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _quoteText,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 1.5,
                                      color: Colors.white.withOpacity(0.3),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _quoteAuthor,
                                      style: GoogleFonts.dmSans(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.5,
                                        color: Colors.white.withOpacity(0.7),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _EnergyCard extends StatefulWidget {
  const _EnergyCard();

  @override
  State<_EnergyCard> createState() => _EnergyCardState();
}

class _EnergyCardState extends State<_EnergyCard> {
  double _energyValue = 0.3;

  String get _energyDescription {
    if (_energyValue < 0.2) return 'Depleted / Running on empty';
    if (_energyValue < 0.4) return 'Low / Surviving the day';
    if (_energyValue < 0.6) return 'Moderate / Getting by';
    if (_energyValue < 0.8) return 'Good / Feeling okay';
    return 'Peak / Unstoppable';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E212B),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How is your energy right now?',
            style: GoogleFonts.dmSans(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _energyDescription,
            style: GoogleFonts.dmSans(
              color: const Color(0xFF00E5FF),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              const Icon(Icons.battery_0_bar, color: Colors.grey, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 4,
                    activeTrackColor: const Color(0xFF00E5FF),
                    inactiveTrackColor: Colors.grey.withOpacity(0.3),
                    thumbColor: const Color(0xFF00E5FF),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                  ),
                  child: Slider(
                    value: _energyValue,
                    onChanged: (value) {
                      setState(() {
                        _energyValue = value;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.battery_charging_full, color: Color(0xFF00E5FF), size: 24),
            ],
          ),
          const SizedBox(height: 32),
          Center(
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.memory, color: Colors.black, size: 20),
              label: Text(
                'Log to AI Engine',
                style: GoogleFonts.dmSans(
                  color: Colors.black,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
