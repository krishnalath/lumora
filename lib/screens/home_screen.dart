import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/quote_service.dart';
import 'routine_screen.dart';
import 'my_tasks_screen.dart';
import 'sleep_dashboard_screen.dart';
import '../services/sleep_storage_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _quoteText = '"The present moment always will have been."';
  String _quoteAuthor = 'UNKNOWN';
  bool _isQuoteLoading = true;
  int? _selectedDayIndex;
  Map<int, dynamic> _weeklySleepSummary = {};
  double _weeklyAvgSleep = 0.0;

  @override
  void initState() {
    super.initState();
    _loadQuote();
    _loadWeeklySleepSummary();
  }

  Future<void> _loadWeeklySleepSummary() async {
    final summary = await SleepStorageService.getWeeklySummary();
    final avg = await SleepStorageService.getWeeklyAverageSleep();
    if (mounted) {
      setState(() {
        _weeklySleepSummary = summary;
        _weeklyAvgSleep = avg;
      });
    }
  }

  String _getGreeting() {
    final name = FirebaseAuth.instance.currentUser?.displayName ?? 'there';
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning, $name';
    if (hour < 18) return 'Good afternoon, $name';
    return 'Good evening, $name';
  }

  String _getDateLabel() {
    final now = DateTime.now();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
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

  @override
  Widget build(BuildContext context) {
    final int hour = DateTime.now().hour;
    RoutineType currentRoutineType = RoutineType.morning;
    if (hour >= 12 && hour < 17) {
      currentRoutineType = RoutineType.afternoon;
    } else if (hour >= 17) {
      currentRoutineType = RoutineType.night;
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              _buildHeader(),
              const SizedBox(height: 6),
              Text(
                _getDateLabel(),
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: AppTheme.textLight,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 28),
              _buildRoutineCard(currentRoutineType),
              const SizedBox(height: 14),
              _buildSleepAndTasks(),
              const SizedBox(height: 14),
              _buildWeeklyMoodRow(),
              const SizedBox(height: 14),
              _buildAutoSleepCard(),
              const SizedBox(height: 14),
              _buildQuoteCard(),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // HEADER
  // ─────────────────────────────────────────────
  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getGreeting(),
                style: GoogleFonts.outfit(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textDark,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
        PopupMenuButton<String>(
          color: const Color(0xFF1E212B),
          elevation: 8,
          onSelected: (value) async {
            if (value == 'signout') await AuthService().signOut();
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'signout',
              child: Row(
                children: [
                  const Icon(Icons.logout, color: AppTheme.primary, size: 20),
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
          ),
          offset: const Offset(0, 45),
          child: const Icon(Icons.person, color: AppTheme.textDark, size: 24),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // ROUTINE CARD — full-width, bold accent strip
  // ─────────────────────────────────────────────
  Widget _buildRoutineCard(RoutineType routineType) {
    Color accent;
    Color bg;
    String label;
    String sub;
    IconData icon;

    if (routineType == RoutineType.morning) {
      accent = const Color(0xFFFFB347);
      bg = const Color(0xFF1C1A14);
      label = 'Morning Routine';
      sub = 'Start your day intentionally';
      icon = Icons.wb_sunny_rounded;
    } else if (routineType == RoutineType.afternoon) {
      accent = AppTheme.accentGreen;
      bg = const Color(0xFF0F2027);
      label = 'Afternoon Check-in';
      sub = 'How is your day going?';
      icon = Icons.wb_cloudy_rounded;
    } else {
      accent = AppTheme.accentLavender;
      bg = const Color(0xFF16141F);
      label = 'Night Routine';
      sub = 'Wind down and reflect';
      icon = Icons.nights_stay_rounded;
    }

    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RoutineScreen(routineType: routineType),
          ),
        );
        if (result == true) _loadWeeklySleepSummary();
      },
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.18),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: accent, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    sub,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: accent, size: 16),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // SLEEP STATS + TASKS  (side-by-side)
  // ─────────────────────────────────────────────
  Widget _buildSleepAndTasks() {
    final avgStr = '${_weeklyAvgSleep.toStringAsFixed(1)}h';

    return Row(
      children: [
        // Sleep stat tile
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF1E212B),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.accentLavender.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.bedtime_outlined,
                    color: AppTheme.accentLavender,
                    size: 20,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  avgStr,
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'avg sleep\nthis week',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: Colors.white54,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 14),
        // My Tasks tile
        Expanded(
          child: GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MyTasksScreen()),
            ),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF0F2027),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.accentGreen.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.task_alt_rounded,
                      color: AppTheme.accentGreen,
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'My\nTasks',
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'Open tasks',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: Colors.white54,
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: AppTheme.accentGreen,
                        size: 16,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // WEEKLY SLEEP LOG STATUS ROW
  // ─────────────────────────────────────────────
  Widget _buildWeeklyMoodRow() {
    final dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final today = DateTime.now().weekday; // 1=Mon … 7=Sun
    final selectedIdx = _selectedDayIndex ?? (today - 1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This Week',
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (i) {
              final weekday = i + 1;
              final isToday = weekday == today;
              final isPast = weekday < today;
              final isSelected = i == selectedIdx;
              final hasLogged = _weeklySleepSummary[weekday] != null;
              // Dot color: green if logged, red if past/today and not logged, transparent if future
              Color dotColor;
              if (hasLogged) {
                dotColor = AppTheme.accentGreen;
              } else if (isPast || isToday) {
                dotColor = const Color(0xFFFF6B6B);
              } else {
                dotColor = Colors.transparent;
              }
              return GestureDetector(
                onTap: () => setState(() => _selectedDayIndex = i),
                child: Column(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.textDark
                            : isPast
                            ? const Color(0xFFD0CEC9).withOpacity(0.5)
                            : Colors.transparent,
                        shape: BoxShape.circle,
                        border: isSelected || isPast
                            ? null
                            : Border.all(
                                color: const Color(0xFFD0CEC9),
                                width: 1.5,
                              ),
                      ),
                      child: Center(
                        child: Text(
                          dayLabels[i],
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? Colors.white
                                : isPast
                                ? AppTheme.textMedium
                                : AppTheme.textLight,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: dotColor,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }


  // ─────────────────────────────────────────────
  // SLEEP INSIGHTS CARD
  // ─────────────────────────────────────────────
  Widget _buildAutoSleepCard() {
    final int loggedDays = _weeklySleepSummary.values.where((v) => v != null).length;
    final hasData = loggedDays > 0;

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SleepDashboardScreen()),
        );
        _loadWeeklySleepSummary();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A1530), Color(0xFF1E212B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.accentLavender.withOpacity(0.15),
                border: Border.all(
                  color: hasData ? AppTheme.accentLavender.withOpacity(0.5) : Colors.white12,
                  width: 2.5,
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.bedtime_rounded,
                  color: hasData ? AppTheme.accentLavender : Colors.white24,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sleep Insights',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasData
                        ? '$loggedDays/7 days logged • Avg ${_weeklyAvgSleep.toStringAsFixed(1)}h'
                        : 'Tap to log your sleep',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: AppTheme.accentLavender.withOpacity(0.5),
              size: 14,
            ),
          ],
        ),
      ),
    );
  }


  // ─────────────────────────────────────────────
  // QUOTE CARD
  // ─────────────────────────────────────────────
  Widget _buildQuoteCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.textDark,
        borderRadius: BorderRadius.circular(20),
      ),
      child: _isQuoteLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppTheme.accentLavender,
                strokeWidth: 2,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '❝',
                  style: TextStyle(
                    fontSize: 32,
                    color: AppTheme.accentLavender.withOpacity(0.6),
                    height: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _quoteText,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(width: 24, height: 1.5, color: Colors.white24),
                    const SizedBox(width: 8),
                    Text(
                      _quoteAuthor,
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        color: Colors.white38,
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}
