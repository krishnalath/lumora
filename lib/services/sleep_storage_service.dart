import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sleep_record.dart';

/// Persistence layer for sleep records.
///
/// Uses SharedPreferences to store:
///   - `'sleep_current_week'`  : JSON map of weekday→SleepRecord for the current ISO week
///   - `'sleep_week_number'`   : ISO week number when the current data was started
///   - `'sleep_week_history'`  : JSON list of past weekly averages [{week, year, avgHours}]
///   - `'sleep_all_records'`   : Full archive of all records for long-term reference
class SleepStorageService {
  static const String _currentWeekKey = 'sleep_current_week';
  static const String _weekNumberKey = 'sleep_week_number';
  static const String _weekYearKey = 'sleep_week_year';
  static const String _historyKey = 'sleep_week_history';
  static const String _allRecordsKey = 'sleep_all_records';
  static const String _lastLogDateKey = 'sleep_last_log_date';

  // ── ISO week helpers ─────────────────────────────────────────────

  /// Returns the ISO week number for [date].
  static int _isoWeekNumber(DateTime date) {
    // ISO week: week 1 contains the first Thursday of the year
    final dayOfYear = date.difference(DateTime(date.year, 1, 1)).inDays + 1;
    final weekday = date.weekday; // Mon=1 .. Sun=7
    final weekNumber = ((dayOfYear - weekday + 10) / 7).floor();
    if (weekNumber < 1) return _isoWeekNumber(DateTime(date.year - 1, 12, 31));
    if (weekNumber > 52) {
      final dec31 = DateTime(date.year, 12, 31);
      if (dec31.weekday < 4) return 1;
    }
    return weekNumber;
  }

  /// Returns the ISO year for the week containing [date].
  static int _isoWeekYear(DateTime date) {
    final weekNumber = _isoWeekNumber(date);
    if (weekNumber > 50 && date.month == 1) return date.year - 1;
    if (weekNumber == 1 && date.month == 12) return date.year + 1;
    return date.year;
  }

  // ── Week rotation ─────────────────────────────────────────────

  /// Check if we've entered a new week. If so, archive the old week
  /// and clear current-week data.
  static Future<void> _rotateWeekIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final currentWeek = _isoWeekNumber(now);
    final currentYear = _isoWeekYear(now);
    final storedWeek = prefs.getInt(_weekNumberKey) ?? -1;
    final storedYear = prefs.getInt(_weekYearKey) ?? -1;

    if (storedWeek != currentWeek || storedYear != currentYear) {
      // Archive the previous week's data before clearing
      if (storedWeek > 0) {
        await _archiveCurrentWeek(prefs, storedWeek, storedYear);
      }
      // Reset current week
      await prefs.setString(_currentWeekKey, '{}');
      await prefs.setInt(_weekNumberKey, currentWeek);
      await prefs.setInt(_weekYearKey, currentYear);
      // Reset last log date so user can log on the new week
      await prefs.remove(_lastLogDateKey);
    }
  }

  /// Archive the current week's average sleep hours into history.
  static Future<void> _archiveCurrentWeek(SharedPreferences prefs, int week, int year) async {
    final weekDataStr = prefs.getString(_currentWeekKey) ?? '{}';
    try {
      final Map<String, dynamic> weekData = json.decode(weekDataStr);
      if (weekData.isEmpty) return;

      double totalMinutes = 0;
      int count = 0;
      for (final entry in weekData.values) {
        final record = SleepRecord.fromJson(entry as Map<String, dynamic>);
        if (record.sleepEnd != null) {
          totalMinutes += record.duration.inMinutes;
          count++;
        }
      }

      if (count == 0) return;

      final avgHours = totalMinutes / (count * 60.0);

      // Load existing history
      final historyStr = prefs.getString(_historyKey) ?? '[]';
      final List<dynamic> history = json.decode(historyStr);
      history.add({
        'week': week,
        'year': year,
        'avgHours': avgHours,
        'daysLogged': count,
        'archivedAt': DateTime.now().toIso8601String(),
      });
      // Keep last 52 weeks of history
      if (history.length > 52) {
        history.removeRange(0, history.length - 52);
      }
      await prefs.setString(_historyKey, json.encode(history));
    } catch (_) {}
  }

  // ── Core CRUD ─────────────────────────────────────────────────

  /// Save a sleep record for a specific weekday in the current week.
  static Future<void> saveSleepRecord(SleepRecord record) async {
    await _rotateWeekIfNeeded();
    final prefs = await SharedPreferences.getInstance();

    // Save to current week map (keyed by weekday 1-7)
    final weekDataStr = prefs.getString(_currentWeekKey) ?? '{}';
    final Map<String, dynamic> weekData = json.decode(weekDataStr);
    final wakeDay = record.sleepEnd?.weekday ?? record.sleepStart.weekday;
    weekData[wakeDay.toString()] = record.toJson();
    await prefs.setString(_currentWeekKey, json.encode(weekData));

    // Also save to the full archive
    final allStr = prefs.getString(_allRecordsKey) ?? '[]';
    try {
      final List<dynamic> all = json.decode(allStr);
      // Remove existing record for same id
      all.removeWhere((e) => e['id'] == record.id);
      all.add(record.toJson());
      // Keep last 90 days
      final cutoff = DateTime.now().subtract(const Duration(days: 90));
      all.removeWhere((e) {
        try {
          return DateTime.parse(e['sleepStart']).isBefore(cutoff);
        } catch (_) {
          return false;
        }
      });
      await prefs.setString(_allRecordsKey, json.encode(all));
    } catch (_) {}
  }

  /// Get the current week's summary: Map<weekday, SleepRecord?> for Mon(1)–Sun(7).
  static Future<Map<int, SleepRecord?>> getWeeklySummary() async {
    await _rotateWeekIfNeeded();
    final prefs = await SharedPreferences.getInstance();
    final weekDataStr = prefs.getString(_currentWeekKey) ?? '{}';

    final Map<int, SleepRecord?> summary = {};
    for (int i = 1; i <= 7; i++) {
      summary[i] = null;
    }

    try {
      final Map<String, dynamic> weekData = json.decode(weekDataStr);
      for (final entry in weekData.entries) {
        final weekday = int.tryParse(entry.key);
        if (weekday != null && weekday >= 1 && weekday <= 7) {
          summary[weekday] = SleepRecord.fromJson(entry.value as Map<String, dynamic>);
        }
      }
    } catch (_) {}

    return summary;
  }

  /// Get today's sleep record (if logged).
  static Future<SleepRecord?> getTodaySleep() async {
    await _rotateWeekIfNeeded();
    final prefs = await SharedPreferences.getInstance();
    final weekDataStr = prefs.getString(_currentWeekKey) ?? '{}';
    final today = DateTime.now().weekday;

    try {
      final Map<String, dynamic> weekData = json.decode(weekDataStr);
      if (weekData.containsKey(today.toString())) {
        return SleepRecord.fromJson(weekData[today.toString()] as Map<String, dynamic>);
      }
    } catch (_) {}
    return null;
  }

  /// Compute the current week's average sleep (only from days that have data).
  static Future<double> getWeeklyAverageSleep() async {
    await _rotateWeekIfNeeded();
    final prefs = await SharedPreferences.getInstance();
    final weekDataStr = prefs.getString(_currentWeekKey) ?? '{}';

    try {
      final Map<String, dynamic> weekData = json.decode(weekDataStr);
      if (weekData.isEmpty) return 0.0;

      double totalMinutes = 0;
      int count = 0;
      for (final entry in weekData.values) {
        final record = SleepRecord.fromJson(entry as Map<String, dynamic>);
        if (record.sleepEnd != null) {
          totalMinutes += record.duration.inMinutes;
          count++;
        }
      }
      if (count == 0) return 0.0;
      return totalMinutes / (count * 60.0);
    } catch (_) {
      return 0.0;
    }
  }

  /// Check if the user already logged sleep today.
  static Future<bool> hasLoggedToday() async {
    final prefs = await SharedPreferences.getInstance();
    final lastLog = prefs.getString(_lastLogDateKey);
    if (lastLog == null) return false;
    final now = DateTime.now();
    final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return lastLog == today;
  }

  /// Mark today as logged.
  static Future<void> _markLoggedToday() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    await prefs.setString(_lastLogDateKey, today);
  }

  /// Log sleep from user-provided bedtime and wakeup time.
  /// Returns the created SleepRecord.
  /// Throws if already logged today.
  static Future<SleepRecord> logSleepManually({
    required DateTime bedtime,
    required DateTime wakeup,
  }) async {
    if (await hasLoggedToday()) {
      throw Exception('Sleep already logged for today.');
    }

    final record = SleepRecord(
      id: bedtime.millisecondsSinceEpoch.toString(),
      sleepStart: bedtime,
      sleepEnd: wakeup,
      confidenceScore: 95, // User-reported = high confidence
      isCharging: false,
      avgMotion: 0.0,
      interruptions: 0,
    );

    await saveSleepRecord(record);
    await _markLoggedToday();
    return record;
  }

  /// Get the history of past weekly averages.
  static Future<List<Map<String, dynamic>>> getWeeklyHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyStr = prefs.getString(_historyKey) ?? '[]';
    try {
      final List<dynamic> history = json.decode(historyStr);
      return history.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  /// Clear all stored records (for testing).
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentWeekKey);
    await prefs.remove(_weekNumberKey);
    await prefs.remove(_weekYearKey);
    await prefs.remove(_historyKey);
    await prefs.remove(_allRecordsKey);
    await prefs.remove(_lastLogDateKey);
  }
}
