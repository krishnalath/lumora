import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sleep_record.dart';
import 'firestore_service.dart';

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

  static final FirestoreService _firestore = FirestoreService();

  /// Tracks whether the initial Firestore sync has completed.
  /// Screens can call [ensureSynced] to wait for it before loading data.
  static Completer<void>? _syncCompleter;

  /// Wait for the in-flight Firestore sync to finish (if any).
  /// Times out after [timeout] so the UI isn't blocked forever on
  /// slow/offline networks.
  static Future<void> ensureSynced({Duration timeout = const Duration(seconds: 3)}) async {
    if (_syncCompleter != null && !_syncCompleter!.isCompleted) {
      try {
        await _syncCompleter!.future.timeout(timeout);
      } catch (_) {
        // Timeout or error — proceed with whatever local data we have
        debugPrint('Sleep sync timed out — using local data');
      }
    }
  }

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
      final avgEntry = {
        'week': week,
        'year': year,
        'avgHours': avgHours,
        'daysLogged': count,
        'archivedAt': DateTime.now().toIso8601String(),
      };
      history.add(avgEntry);
      // Keep last 52 weeks of history
      if (history.length > 52) {
        history.removeRange(0, history.length - 52);
      }
      await prefs.setString(_historyKey, json.encode(history));

      // Sync weekly average to Firestore
      try {
        await _firestore.saveSleepWeeklyAverage(avgEntry);
      } catch (e) {
        debugPrint('Firestore sleep weekly avg sync failed: $e');
      }
    } catch (_) {}
  }

  // ── Core CRUD ─────────────────────────────────────────────────

  /// Save a sleep record for a specific weekday in the current week.
  /// Writes to both local SharedPreferences and Firestore.
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

    // ── Sync to Firestore (fire-and-forget, won't block UI) ──
    try {
      await _firestore.saveSleepRecord(record.toJson());
    } catch (e) {
      debugPrint('Firestore sleep record sync failed: $e');
    }
  }

  /// Get the current week's summary: `Map<weekday, SleepRecord?>` for Mon(1)–Sun(7).
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
  /// Checks the explicit flag first, then falls back to checking
  /// whether actual sleep data exists for today's weekday.
  static Future<bool> hasLoggedToday() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    // Fast path: explicit flag
    final lastLog = prefs.getString(_lastLogDateKey);
    if (lastLog == today) return true;

    // Fallback: check if there's actual data for today's weekday
    // (covers cases where flag was lost, e.g. after cloud sync / reinstall)
    final weekDataStr = prefs.getString(_currentWeekKey) ?? '{}';
    try {
      final Map<String, dynamic> weekData = json.decode(weekDataStr);
      final todayKey = now.weekday.toString();
      if (weekData.containsKey(todayKey)) {
        // Verify the record is actually from today, not a different week's same weekday
        final record = SleepRecord.fromJson(weekData[todayKey] as Map<String, dynamic>);
        final recordDate = record.sleepEnd ?? record.sleepStart;
        final recordDay = '${recordDate.year}-${recordDate.month.toString().padLeft(2, '0')}-${recordDate.day.toString().padLeft(2, '0')}';
        if (recordDay == today || record.sleepStart.day == now.day) {
          // Restore the flag so future checks are fast
          await prefs.setString(_lastLogDateKey, today);
          return true;
        }
      }
    } catch (_) {}

    return false;
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
    );

    await saveSleepRecord(record);
    await _markLoggedToday();
    return record;
  }

  /// Get the history of past weekly averages.
  /// Reads from local SharedPreferences first; falls back to Firestore
  /// `sleep_weekly_averages`, then computes from raw `sleep_records`.
  static Future<List<Map<String, dynamic>>> getWeeklyHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyStr = prefs.getString(_historyKey) ?? '[]';
    try {
      final List<dynamic> history = json.decode(historyStr);
      if (history.isNotEmpty) {
        return history.cast<Map<String, dynamic>>();
      }
    } catch (_) {}

    // Fallback 1: Try pre-aggregated weekly averages from Firestore
    try {
      final cloudAverages = await _firestore.getSleepWeeklyAverages();
      if (cloudAverages.isNotEmpty) {
        final List<Map<String, dynamic>> normalised = cloudAverages.map((e) => {
          'week': e['week'],
          'year': e['year'],
          'avgHours': (e['avgHours'] as num?)?.toDouble() ?? 0.0,
          'daysLogged': e['daysLogged'] as int? ?? 0,
          'archivedAt': e['archivedAt'] ?? e['updatedAt']?.toString() ?? DateTime.now().toIso8601String(),
        }).toList();

        normalised.sort((a, b) {
          final aYear = (a['year'] as int?) ?? 0;
          final bYear = (b['year'] as int?) ?? 0;
          if (aYear != bYear) return aYear.compareTo(bYear);
          return ((a['week'] as int?) ?? 0).compareTo((b['week'] as int?) ?? 0);
        });

        await prefs.setString(_historyKey, json.encode(normalised));
        return normalised;
      }
    } catch (e) {
      debugPrint('Firestore weekly averages fallback failed: $e');
    }

    // Fallback 2: Compute from raw sleep_records in Firestore
    try {
      final rawRecords = await _firestore.getSleepHistory(days: 365);
      if (rawRecords.isEmpty) return [];

      final now = DateTime.now();
      final currentWeek = _isoWeekNumber(now);
      final currentYear = _isoWeekYear(now);

      // Group records by ISO (year, week), skipping the current week
      final Map<String, List<double>> weeklyMinutes = {};
      for (final recordJson in rawRecords) {
        try {
          final record = SleepRecord.fromJson(recordJson);
          if (record.sleepEnd == null) continue;

          final wakeDate = record.sleepEnd!;
          final week = _isoWeekNumber(wakeDate);
          final year = _isoWeekYear(wakeDate);

          // Skip the current week (it's not a "past" insight yet)
          if (week == currentWeek && year == currentYear) continue;

          final key = '${year}_$week';
          weeklyMinutes.putIfAbsent(key, () => []);
          weeklyMinutes[key]!.add(record.duration.inMinutes.toDouble());
        } catch (_) {}
      }

      if (weeklyMinutes.isEmpty) return [];

      final List<Map<String, dynamic>> computed = [];
      for (final entry in weeklyMinutes.entries) {
        final parts = entry.key.split('_');
        final year = int.parse(parts[0]);
        final week = int.parse(parts[1]);
        final minutes = entry.value;
        final avgHours = minutes.reduce((a, b) => a + b) / (minutes.length * 60.0);

        final avgEntry = {
          'week': week,
          'year': year,
          'avgHours': avgHours,
          'daysLogged': minutes.length,
          'archivedAt': DateTime.now().toIso8601String(),
        };
        computed.add(avgEntry);

        // Also save to Firestore so future loads are faster
        try {
          await _firestore.saveSleepWeeklyAverage(avgEntry);
        } catch (_) {}
      }

      // Sort oldest first
      computed.sort((a, b) {
        final aYear = (a['year'] as int?) ?? 0;
        final bYear = (b['year'] as int?) ?? 0;
        if (aYear != bYear) return aYear.compareTo(bYear);
        return ((a['week'] as int?) ?? 0).compareTo((b['week'] as int?) ?? 0);
      });

      // Keep last 52 weeks
      if (computed.length > 52) {
        computed.removeRange(0, computed.length - 52);
      }

      // Cache locally
      await prefs.setString(_historyKey, json.encode(computed));
      debugPrint('Computed ${computed.length} weekly averages from raw sleep records.');
      return computed;
    } catch (e) {
      debugPrint('Computing weekly history from raw records failed: $e');
    }

    return [];
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

  // ── Firestore Sync ─────────────────────────────────────────────

  /// Pull sleep records from Firestore into local SharedPreferences.
  /// Call this on app startup or login to hydrate the local cache
  /// with cloud data (e.g., when switching devices).
  static Future<void> syncFromFirestore() async {
    // Set up completer so other code can await this sync
    _syncCompleter = Completer<void>();
    try {
      await _syncFromFirestoreInternal();
    } finally {
      if (!_syncCompleter!.isCompleted) {
        _syncCompleter!.complete();
      }
    }
  }

  static Future<void> _syncFromFirestoreInternal() async {
    try {
      final now = DateTime.now();

      // Calculate current ISO week start (Monday) and end (next Monday)
      final weekday = now.weekday; // Mon=1 .. Sun=7
      final weekStart = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: weekday - 1));
      final weekEnd = weekStart.add(const Duration(days: 7));

      // Fetch current week's records from Firestore
      final cloudRecords = await _firestore.getCurrentWeekSleepRecords(
        weekStart: weekStart,
        weekEnd: weekEnd,
      );

      if (cloudRecords.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();

      // Rebuild the current week map from cloud data
      final Map<String, dynamic> weekData = {};
      for (final recordJson in cloudRecords) {
        try {
          final record = SleepRecord.fromJson(recordJson);
          final wakeDay = record.sleepEnd?.weekday ?? record.sleepStart.weekday;
          weekData[wakeDay.toString()] = record.toJson();
        } catch (e) {
          debugPrint('Skipping malformed cloud sleep record: $e');
        }
      }

      // Merge with local: cloud wins for same weekday
      final localStr = prefs.getString(_currentWeekKey) ?? '{}';
      final Map<String, dynamic> localData = json.decode(localStr);
      localData.addAll(weekData); // Cloud overwrites local for same keys
      await prefs.setString(_currentWeekKey, json.encode(localData));

      // Update week tracking
      await prefs.setInt(_weekNumberKey, _isoWeekNumber(now));
      await prefs.setInt(_weekYearKey, _isoWeekYear(now));

      // Restore the "logged today" flag if today's data came from the cloud
      final todayKey = now.weekday.toString();
      if (localData.containsKey(todayKey)) {
        try {
          final record = SleepRecord.fromJson(localData[todayKey] as Map<String, dynamic>);
          final recordDate = record.sleepEnd ?? record.sleepStart;
          if (recordDate.year == now.year &&
              recordDate.month == now.month &&
              recordDate.day == now.day) {
            final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
            await prefs.setString(_lastLogDateKey, todayStr);
          }
        } catch (_) {}
      }

      debugPrint('Sleep sync from Firestore complete: ${cloudRecords.length} records merged.');

      // ── Also sync weekly history/averages from Firestore ──
      await _syncWeeklyHistoryFromFirestore(prefs);
    } catch (e) {
      debugPrint('Firestore sleep sync failed (offline?): $e');
    }
  }

  /// Pull weekly average history from Firestore and merge into local cache.
  /// This ensures "Past Insights" shows data after reinstall / device switch.
  static Future<void> _syncWeeklyHistoryFromFirestore(SharedPreferences prefs) async {
    try {
      final cloudAverages = await _firestore.getSleepWeeklyAverages();
      if (cloudAverages.isEmpty) return;

      // Load existing local history
      final localHistoryStr = prefs.getString(_historyKey) ?? '[]';
      final List<dynamic> localHistory = json.decode(localHistoryStr);

      // Build a set of existing (week, year) keys for de-duplication
      final existingKeys = <String>{};
      for (final entry in localHistory) {
        final w = entry['week'];
        final y = entry['year'];
        if (w != null && y != null) {
          existingKeys.add('${y}_$w');
        }
      }

      // Merge cloud entries that aren't already present locally
      int added = 0;
      for (final cloudEntry in cloudAverages) {
        final w = cloudEntry['week'];
        final y = cloudEntry['year'];
        if (w == null || y == null) continue;

        final key = '${y}_$w';
        if (!existingKeys.contains(key)) {
          localHistory.add({
            'week': w,
            'year': y,
            'avgHours': (cloudEntry['avgHours'] as num?)?.toDouble() ?? 0.0,
            'daysLogged': cloudEntry['daysLogged'] as int? ?? 0,
            'archivedAt': cloudEntry['archivedAt'] ?? cloudEntry['updatedAt']?.toString() ?? DateTime.now().toIso8601String(),
          });
          existingKeys.add(key);
          added++;
        }
      }

      if (added > 0) {
        // Sort by year then week ascending (oldest first, matching local convention)
        localHistory.sort((a, b) {
          final aYear = (a['year'] as int?) ?? 0;
          final bYear = (b['year'] as int?) ?? 0;
          if (aYear != bYear) return aYear.compareTo(bYear);
          final aWeek = (a['week'] as int?) ?? 0;
          final bWeek = (b['week'] as int?) ?? 0;
          return aWeek.compareTo(bWeek);
        });

        // Keep last 52 weeks
        if (localHistory.length > 52) {
          localHistory.removeRange(0, localHistory.length - 52);
        }

        await prefs.setString(_historyKey, json.encode(localHistory));
        debugPrint('Sleep weekly history synced from Firestore: $added new entries merged.');
      }
    } catch (e) {
      debugPrint('Firestore weekly history sync failed: $e');
    }
  }
}
