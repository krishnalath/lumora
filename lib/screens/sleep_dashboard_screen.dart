import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_theme.dart';
import '../models/sleep_record.dart';
import '../services/sleep_storage_service.dart';

class SleepDashboardScreen extends StatefulWidget {
  const SleepDashboardScreen({super.key});
  @override
  State<SleepDashboardScreen> createState() => _SleepDashboardScreenState();
}

class _SleepDashboardScreenState extends State<SleepDashboardScreen>
    with SingleTickerProviderStateMixin {
  SleepRecord? _todaySleep;
  Map<int, SleepRecord?> _weeklySummary = {};
  double _weeklyAvg = 0.0;
  bool _isLoading = true;
  bool _hasLoggedToday = false;
  List<Map<String, dynamic>> _history = [];
  late AnimationController _ringController;
  late Animation<double> _ringAnimation;

  // User-selected times
  TimeOfDay _bedtime = const TimeOfDay(hour: 22, minute: 30);
  TimeOfDay _wakeup = const TimeOfDay(hour: 6, minute: 30);

  @override
  void initState() {
    super.initState();
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _ringAnimation = CurvedAnimation(parent: _ringController, curve: Curves.easeOutCubic);
    _loadData();
  }

  @override
  void dispose() {
    _ringController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    // Wait for any in-flight Firestore sync to finish first
    // (times out after 3s so we don't block on slow/offline networks)
    await SleepStorageService.ensureSynced();

    final today = await SleepStorageService.getTodaySleep();
    final weekly = await SleepStorageService.getWeeklySummary();
    final avg = await SleepStorageService.getWeeklyAverageSleep();
    final logged = await SleepStorageService.hasLoggedToday();
    final history = await SleepStorageService.getWeeklyHistory();
    if (mounted) {
      setState(() {
        _todaySleep = today;
        _weeklySummary = weekly;
        _weeklyAvg = avg;
        _hasLoggedToday = logged;
        _history = history.reversed.toList(); // Newest first
        _isLoading = false;
      });
      _ringController.forward(from: 0);
    }
  }

  Future<void> _pickBedtime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _bedtime,
      helpText: 'Select Bedtime',
      builder: (context, child) => _timePickerTheme(child!),
    );
    if (picked != null) setState(() => _bedtime = picked);
  }

  Future<void> _pickWakeup() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _wakeup,
      helpText: 'Select Wake-up Time',
      builder: (context, child) => _timePickerTheme(child!),
    );
    if (picked != null) setState(() => _wakeup = picked);
  }

  Widget _timePickerTheme(Widget child) {
    return Theme(
      data: ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(
          primary: AppTheme.accentLavender,
          onPrimary: Colors.white,
          surface: Color(0xFF252A36),
          onSurface: Colors.white,
        ),
        timePickerTheme: TimePickerThemeData(
          backgroundColor: const Color(0xFF1E212B),
          hourMinuteTextColor: Colors.white,
          hourMinuteColor: const Color(0xFF2A2E3B),
          dialHandColor: AppTheme.accentLavender,
          dialBackgroundColor: const Color(0xFF2A2E3B),
          dialTextColor: Colors.white,
          dayPeriodTextColor: Colors.white,
          dayPeriodColor: const Color(0xFF2A2E3B),
          entryModeIconColor: Colors.white70,
          helpTextStyle: GoogleFonts.dmSans(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
          hourMinuteTextStyle: GoogleFonts.outfit(fontSize: 40, fontWeight: FontWeight.w700),
          dayPeriodTextStyle: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: AppTheme.accentLavender),
        ),
      ),
      child: child,
    );
  }

  Future<void> _logSleepToday() async {
    if (_hasLoggedToday) {
      _showSnack('You already logged sleep for today!', isError: true);
      return;
    }

    final now = DateTime.now();
    // Bedtime = previous night
    DateTime bedDt = DateTime(now.year, now.month, now.day - 1, _bedtime.hour, _bedtime.minute);
    // If bedtime is an early morning hour (0-12), treat it as same day
    if (_bedtime.hour < 12) {
      bedDt = DateTime(now.year, now.month, now.day, _bedtime.hour, _bedtime.minute);
    }
    DateTime wakeDt = DateTime(now.year, now.month, now.day, _wakeup.hour, _wakeup.minute);

    if (wakeDt.isBefore(bedDt) || wakeDt.isAtSameMomentAs(bedDt)) {
      _showSnack('Wake-up time must be after bedtime.', isError: true);
      return;
    }

    try {
      await SleepStorageService.logSleepManually(bedtime: bedDt, wakeup: wakeDt);
      _showSnack('Sleep logged successfully!', isSuccess: true);
      await _loadData();
    } catch (e) {
      _showSnack(e.toString(), isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false, bool isSuccess = false}) {
    Color bg = const Color(0xFF252A36);
    if (isError) bg = Colors.red.shade400;
    if (isSuccess) bg = AppTheme.accentGreen;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.w600)),
      backgroundColor: bg,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  String _fmtTime(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final p = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $p';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.accentLavender))
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    _buildHeader(),
                    const SizedBox(height: 24),
                    _buildScoreCard(),
                    const SizedBox(height: 16),
                    _buildTimePills(),
                    const SizedBox(height: 24),
                    _buildWeeklyChart(),
                    const SizedBox(height: 24),
                    _buildInsightsCard(),
                    const SizedBox(height: 24),
                    _buildLogButton(),
                    const SizedBox(height: 32),
                    _buildHistorySection(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
      ),
    );
  }

  // ── Header (no black bg on back, no Auto badge) ───────────────
  Widget _buildHeader() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textDark, size: 22),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            'Sleep Insights',
            style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.textDark),
          ),
        ),
      ],
    );
  }

  // ── Score Ring Card ────────────────────────────────────────────
  Widget _buildScoreCard() {
    final score = _todaySleep?.sleepScore ?? 0;
    final duration = _todaySleep?.durationFormatted ?? '--';
    final quality = _todaySleep?.qualityLabel ?? 'No data';
    final hasData = _todaySleep != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E212B),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _ringAnimation,
            builder: (context, child) {
              return SizedBox(
                width: 160, height: 160,
                child: CustomPaint(
                  painter: _SleepScoreRingPainter(
                    score: score,
                    progress: hasData ? _ringAnimation.value : 0,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          hasData ? '${(score * _ringAnimation.value).toInt()}' : '--',
                          style: GoogleFonts.outfit(fontSize: 42, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                        Text(
                          'SLEEP SCORE',
                          style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white38, letterSpacing: 1.5),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          Text(duration, style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: _qualityColor(quality).withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(quality, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: _qualityColor(quality))),
          ),
          if (!hasData) ...[
            const SizedBox(height: 16),
            Text(
              'No sleep data for today yet.\nSet your bedtime & wake-up below and log.',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(fontSize: 13, color: Colors.white38, height: 1.5),
            ),
          ],
        ],
      ),
    );
  }

  Color _qualityColor(String quality) {
    switch (quality) {
      case 'Excellent': return AppTheme.accentGreen;
      case 'Good': return AppTheme.accentGreen;
      case 'Fair': return const Color(0xFFFFC94A);
      case 'Poor': return const Color(0xFFFF6B6B);
      default: return Colors.white38;
    }
  }

  // ── Tappable Bedtime / Wake-up pills ──────────────────────────
  Widget _buildTimePills() {
    return Row(
      children: [
        Expanded(child: _timePill(
          Icons.bedtime_rounded, 'Bedtime', _fmtTime(_bedtime),
          AppTheme.accentLavender, _pickBedtime,
        )),
        const SizedBox(width: 12),
        Expanded(child: _timePill(
          Icons.wb_sunny_rounded, 'Wake up', _fmtTime(_wakeup),
          const Color(0xFFFFB347), _pickWakeup,
        )),
      ],
    );
  }

  Widget _timePill(IconData icon, String label, String time, Color accent, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E212B),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: accent.withOpacity(0.18), borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, color: accent, size: 18),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: GoogleFonts.dmSans(fontSize: 11, color: Colors.white38, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(time, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white), overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: Icon(Icons.edit_rounded, color: accent.withOpacity(0.5), size: 13),
          ),
        ],
      ),
    );
  }

  // ── Weekly Chart (Mon–Sun, current week only) ─────────────────
  Widget _buildWeeklyChart() {
    final dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
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
              Text('This Week', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
              Text(
                _weeklyAvg > 0 ? 'Avg ${_weeklyAvg.toStringAsFixed(1)}h' : 'No data',
                style: GoogleFonts.dmSans(fontSize: 13, color: AppTheme.accentGreen, fontWeight: FontWeight.w700),
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
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, gIdx, rod, rIdx) {
                      final r = _weeklySummary[group.x + 1];
                      if (r == null) return null;
                      return BarTooltipItem(
                        r.durationFormatted,
                        GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx > 6) return const SizedBox.shrink();
                        final isToday = (idx + 1) == DateTime.now().weekday;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            dayLabels[idx],
                            style: GoogleFonts.dmSans(
                              color: isToday ? Colors.white : Colors.white38,
                              fontSize: 12,
                              fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true, drawVerticalLine: false, horizontalInterval: 4,
                  getDrawingHorizontalLine: (_) => FlLine(color: Colors.white.withOpacity(0.05), strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(7, (index) {
                  final weekday = index + 1;
                  final record = _weeklySummary[weekday];
                  final hours = record != null ? record.duration.inMinutes / 60.0 : 0.0;
                  final qi = record?.qualityIndex ?? -1;
                  Color barColor;
                  if (qi == 0) barColor = const Color(0xFFFF6B6B);
                  else if (qi == 1) barColor = const Color(0xFFFFC94A);
                  else if (qi == 2) barColor = AppTheme.accentGreen;
                  else barColor = Colors.white12;
                  final isToday = weekday == DateTime.now().weekday;
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: hours > 0 ? hours : 0.4,
                        color: isToday ? barColor : barColor.withOpacity(0.35),
                        width: 14,
                        borderRadius: BorderRadius.circular(5),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true, toY: 12,
                          color: isToday ? Colors.white.withOpacity(0.12) : Colors.white.withOpacity(0.03),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 12),
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
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: GoogleFonts.dmSans(fontSize: 11, color: Colors.white38)),
      ],
    );
  }

  // ── AI Insights Card ──────────────────────────────────────────
  Widget _buildInsightsCard() {
    final insights = _generateInsights();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.textDark,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.accentLavender.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: AppTheme.accentLavender, size: 18),
              ),
              const SizedBox(width: 12),
              Text('AI Sleep Insights', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 18),
          ...insights.map((insight) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  width: 6, height: 6,
                  decoration: BoxDecoration(color: insight['color'] as Color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    insight['text'] as String,
                    style: GoogleFonts.dmSans(fontSize: 13, color: Colors.white70, height: 1.5),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _generateInsights() {
    if (_todaySleep == null) {
      return [
        {'text': 'Start tracking your sleep to receive personalized AI insights about your patterns and wellness.', 'color': Colors.white38},
        {'text': 'Set your bedtime and wake-up time above, then tap "Log Today\'s Sleep" to begin.', 'color': AppTheme.accentLavender},
      ];
    }
    final insights = <Map<String, dynamic>>[];
    final hours = _todaySleep!.duration.inMinutes / 60.0;
    if (hours >= 7 && hours <= 9) {
      insights.add({'text': 'Great job! You slept ${_todaySleep!.durationFormatted} — right within the optimal 7–9 hour range.', 'color': AppTheme.accentGreen});
    } else if (hours < 7) {
      insights.add({'text': 'You only slept ${_todaySleep!.durationFormatted}. Aim for 7–9 hours for optimal performance.', 'color': const Color(0xFFFFC94A)});
    } else {
      insights.add({'text': 'You slept ${_todaySleep!.durationFormatted} — a bit over the recommended range.', 'color': const Color(0xFFFFC94A)});
    }
    final bedHour = _todaySleep!.sleepStart.hour;
    if (bedHour >= 21 && bedHour <= 23) {
      insights.add({'text': 'Your bedtime of ${_formatTime(_todaySleep!.sleepStart)} is ideal for circadian rhythm.', 'color': AppTheme.accentGreen});
    } else {
      insights.add({'text': 'You fell asleep at ${_formatTime(_todaySleep!.sleepStart)}. Try shifting closer to 10 PM.', 'color': const Color(0xFFFFC94A)});
    }
    if (_weeklyAvg > 0) {
      insights.add({'text': 'Your weekly average is ${_weeklyAvg.toStringAsFixed(1)} hours. ${_weeklyAvg >= 7 ? "You\'re maintaining a healthy pattern!" : "Try to gradually increase sleep consistency."}', 'color': _weeklyAvg >= 7 ? AppTheme.accentGreen : const Color(0xFFFFC94A)});
    }
    return insights;
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final m = dt.minute.toString().padLeft(2, '0');
    final p = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $p';
  }

  // ── Log Today's Sleep Button ──────────────────────────────────
  Widget _buildLogButton() {
    final alreadyLogged = _hasLoggedToday;
    return GestureDetector(
      onTap: alreadyLogged ? null : _logSleepToday,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: alreadyLogged
              ? Colors.grey.withOpacity(0.12)
              : AppTheme.accentGreen.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: alreadyLogged
                ? Colors.grey.withOpacity(0.2)
                : AppTheme.accentGreen.withOpacity(0.4),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              alreadyLogged ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
              color: alreadyLogged ? Colors.grey : AppTheme.accentGreen,
              size: 20,
            ),
            const SizedBox(width: 10),
            Text(
              alreadyLogged ? 'Sleep Logged for Today ✓' : 'Log Today\'s Sleep',
              style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: alreadyLogged ? Colors.grey : AppTheme.accentGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── History Section ─────────────────────────────────────────────
  Widget _buildHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Past Insights',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        if (_history.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1E212B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.history_rounded,
                  color: Colors.white24,
                  size: 32,
                ),
                const SizedBox(height: 12),
                Text(
                  'No past insights yet.',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Keep logging your sleep each week to build your history.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: Colors.white54,
                  ),
                ),
              ],
            ),
          )
        else
          ..._history.map((entry) {
            final double avgHours = entry['avgHours'] as double? ?? 0.0;
            final int daysLogged = entry['daysLogged'] as int? ?? 0;
            final int week = entry['week'] as int? ?? 0;
            final int year = entry['year'] as int? ?? 0;
            
            Color avgColor;
            if (avgHours >= 7 && avgHours <= 9) {
              avgColor = AppTheme.accentGreen;
            } else if (avgHours >= 5.5) {
              avgColor = const Color(0xFFFFC94A);
            } else {
              avgColor = const Color(0xFFFF6B6B);
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E212B),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: avgColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        avgHours.toStringAsFixed(1),
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: avgColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Week $week, $year',
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$daysLogged days logged',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.history_rounded,
                    color: Colors.white24,
                    size: 20,
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}

// ── Custom Painter: Animated Score Ring ──────────────────────────
class _SleepScoreRingPainter extends CustomPainter {
  final int score;
  final double progress;

  _SleepScoreRingPainter({required this.score, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;
    const strokeWidth = 10.0;

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = Colors.white.withOpacity(0.08)
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    if (score == 0 || progress == 0) return;

    final sweepAngle = (score / 100.0) * 2 * pi * progress;
    Color arcColor;
    if (score >= 85) arcColor = const Color(0xFF00C9A7);
    else if (score >= 70) arcColor = const Color(0xFF00C9A7);
    else if (score >= 55) arcColor = const Color(0xFFFFC94A);
    else arcColor = const Color(0xFFFF6B6B);

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: -pi / 2,
        endAngle: -pi / 2 + sweepAngle,
        colors: [arcColor.withOpacity(0.6), arcColor],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweepAngle,
      false,
      arcPaint,
    );

    final dotAngle = -pi / 2 + sweepAngle;
    final dotCenter = Offset(
      center.dx + radius * cos(dotAngle),
      center.dy + radius * sin(dotAngle),
    );
    final glowPaint = Paint()
      ..color = arcColor.withOpacity(0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(dotCenter, 6, glowPaint);
    canvas.drawCircle(dotCenter, 4, Paint()..color = arcColor);
  }

  @override
  bool shouldRepaint(covariant _SleepScoreRingPainter old) =>
      old.score != score || old.progress != progress;
}
