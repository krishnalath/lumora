import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/quote_service.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'routine_screen.dart';
import 'my_tasks_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _sleepHistory = [];
  String _quoteText = '"The present moment always will have been."';
  String _quoteAuthor = 'UNKNOWN';
  bool _isQuoteLoading = true;
  int? _selectedDayIndex;

  @override
  void initState() {
    super.initState();
    _loadQuote();
    _loadSleepHistory();
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isSameWeek(DateTime a, DateTime b) {
    final aMonday = a.subtract(Duration(days: a.weekday - 1));
    final bMonday = b.subtract(Duration(days: b.weekday - 1));
    return DateTime(aMonday.year, aMonday.month, aMonday.day) ==
        DateTime(bMonday.year, bMonday.month, bMonday.day);
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

  Future<void> _loadSleepHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String historyJson = prefs.getString('sleep_history_v2') ?? '[]';
    List<Map<String, dynamic>> loadedHistory = [];
    try {
      final List<dynamic> decoded = json.decode(historyJson);
      loadedHistory = decoded.cast<Map<String, dynamic>>();
      if (loadedHistory.isNotEmpty) {
        final lastDate = DateTime.parse(loadedHistory.last['timestamp']);
        if (!_isSameWeek(lastDate, DateTime.now())) {
          final String? archiveJson = prefs.getString('archived_sleep_history');
          List<Map<String, dynamic>> archive = [];
          if (archiveJson != null) {
            archive = (json.decode(archiveJson) as List)
                .cast<Map<String, dynamic>>();
          }
          archive.addAll(loadedHistory);
          await prefs.setString('archived_sleep_history', json.encode(archive));
          loadedHistory = [];
          await prefs.setString('sleep_history_v2', json.encode(loadedHistory));
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _sleepHistory = loadedHistory);
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
              _buildSleepChart(),
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
        if (result == true) _loadSleepHistory();
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
    // Compute average sleep from history
    double avgSleep = 0;
    double total = 0;

    Map<int, double> latestHoursPerDay = {};
    for (var log in _sleepHistory) {
      final int weekday = DateTime.parse(log['timestamp']).weekday;
      latestHoursPerDay[weekday] = (log['hours'] as num).toDouble();
    }

    for (var hours in latestHoursPerDay.values) {
      total += hours;
    }

    avgSleep = total / 7.0; // Consider all 7 days
    final avgStr = '${avgSleep.toStringAsFixed(1)}h';

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
  // WEEKLY MOOD DOTS ROW
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
              final isToday = (i + 1) == today;
              final isPast = (i + 1) < today;
              final isSelected = i == selectedIdx;
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
                        color: isPast || isToday
                            ? AppTheme.accentGreen
                            : Colors.transparent,
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
  // SLEEP CHART  (dark card, proper colors)
  // ─────────────────────────────────────────────
  Widget _buildSleepChart() {
    final selectedIdx = _selectedDayIndex ?? (DateTime.now().weekday - 1);
    double selectedHours = 0.0;
    for (var log in _sleepHistory.reversed) {
      if (DateTime.parse(log['timestamp']).weekday == (selectedIdx + 1)) {
        selectedHours = (log['hours'] as num).toDouble();
        break;
      }
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E212B),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Sleep This Week',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              Text(
                selectedHours > 0
                    ? '${selectedHours.toStringAsFixed(1)} hours'
                    : 'No data',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  color: AppTheme.accentGreen,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 150,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 12,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final int idx = value.toInt();
                        if (idx < 0 || idx > 6) return const SizedBox.shrink();
                        final labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                        final isToday = (idx + 1) == DateTime.now().weekday;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            labels[idx],
                            style: GoogleFonts.dmSans(
                              color: isToday ? Colors.white : Colors.white38,
                              fontSize: 12,
                              fontWeight: isToday
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 4,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: Colors.white.withOpacity(0.05),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(7, (index) {
                  final weekdayTarget = index + 1;
                  Map<String, dynamic>? dayLog;
                  for (var log in _sleepHistory.reversed) {
                    if (DateTime.parse(log['timestamp']).weekday ==
                        weekdayTarget) {
                      dayLog = log;
                      break;
                    }
                  }
                  final double hours = dayLog != null
                      ? (dayLog['hours'] as num).toDouble()
                      : 0.0;
                  final int quality = dayLog != null
                      ? dayLog['quality'] as int
                      : -1;

                  Color barColor;
                  if (quality == 0) {
                    barColor = const Color(0xFFFF6B6B); // poor — red
                  } else if (quality == 1) {
                    barColor = const Color(0xFFFFC94A); // ok — amber
                  } else if (quality == 2) {
                    barColor = AppTheme.accentGreen; // good — green
                  } else {
                    barColor = Colors.white12; // no data
                  }

                  final isSelected = index == selectedIdx;

                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: hours > 0 ? hours : 0.4,
                        color: isSelected
                            ? barColor
                            : barColor.withOpacity(0.3),
                        width: 14,
                        borderRadius: BorderRadius.circular(5),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: 12,
                          color: isSelected
                              ? Colors.white.withOpacity(0.12)
                              : Colors.white.withOpacity(0.03),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legend(AppTheme.accentGreen, 'Good'),
              const SizedBox(width: 16),
              _legend(const Color(0xFFFFC94A), 'Fair'),
              const SizedBox(width: 16),
              _legend(const Color(0xFFFF6B6B), 'Poor'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.dmSans(fontSize: 11, color: Colors.white38),
        ),
      ],
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
