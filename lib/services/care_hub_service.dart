import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'sleep_storage_service.dart';

/// Service layer for Care Hub advanced features:
///   - AI-powered professional matching based on user data
///   - Pre-session data briefing generator
class CareHubService {
  static final _auth = FirebaseAuth.instance;
  static final _db = FirebaseFirestore.instance;

  static final _professionals = [
    {
      'name': 'Dr. Sarah',
      'specialty': 'CBT Specialist',
      'strengths': 'cognitive distortions, negative thought patterns, behavioral activation, depression, OCD',
    },
    {
      'name': 'Mark P.',
      'specialty': 'Anxiety Coach',
      'strengths': 'generalized anxiety, panic attacks, social anxiety, stress management, worry spirals',
    },
    {
      'name': 'Dr. Jane',
      'specialty': 'Sleep Expert',
      'strengths': 'insomnia, sleep hygiene, circadian rhythm, nightmares, sleep anxiety, fatigue',
    },
  ];

  // ── AI Matchmaking ──────────────────────────────────────────

  /// Analyzes the user's recent journals and sleep data, then uses
  /// Gemini to recommend the best-fitting professional.
  /// Returns a map with keys: 'professional', 'reason', 'urgency'.
  static Future<Map<String, String>> getAIRecommendation() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return _defaultRecommendation();
      }

      // 1. Fetch recent journal entries (last 7 days)
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      final journalSnapshot = await _db
          .collection('journals')
          .where('uid', isEqualTo: user.uid)
          .get();

      final recentJournals = journalSnapshot.docs
          .map((doc) => doc.data())
          .where((j) {
        try {
          final date = DateTime.parse(j['date'] as String);
          return date.isAfter(sevenDaysAgo);
        } catch (_) {
          return false;
        }
      }).toList();

      // 2. Fetch recent sleep data
      final sleepSummary = await SleepStorageService.getWeeklySummary();
      final avgSleep = await SleepStorageService.getWeeklyAverageSleep();

      // 3. Build context string
      final journalContext = recentJournals.isEmpty
          ? 'No journal entries in the last 7 days.'
          : recentJournals
              .map((j) =>
                  '- [${j['tag'] ?? 'GENERAL'}] ${j['title']}: ${(j['content'] as String).length > 200 ? (j['content'] as String).substring(0, 200) : j['content']}')
              .join('\n');

      int daysLogged = 0;
      for (final entry in sleepSummary.entries) {
        if (entry.value != null) daysLogged++;
      }
      final sleepContext = avgSleep > 0
          ? 'Average sleep: ${avgSleep.toStringAsFixed(1)} hrs/night over $daysLogged days this week.'
          : 'No sleep data logged this week.';

      // 4. Build professional profiles string
      final profsString = _professionals
          .map((p) =>
              '- ${p['name']} (${p['specialty']}): Specializes in ${p['strengths']}')
          .join('\n');

      // 5. Ask Gemini via HTTP
      final prompt = '''
You are a smart mental health triage assistant for the Lumora app. Based on a user's recent journal entries and sleep data, recommend the SINGLE best professional from the available list.

Available professionals:
$profsString

User's recent journal entries (last 7 days):
$journalContext

User's recent sleep data:
$sleepContext

Respond in EXACTLY this format (3 lines, no markdown, no extra text):
PROFESSIONAL: [exact name from the list]
REASON: [1-2 sentence personalized explanation of why this professional is the best fit right now]
URGENCY: [LOW/MEDIUM/HIGH based on the emotional tone of their journals and sleep patterns]
''';
      final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
      final httpResp = await http.post(
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent'),
        headers: {'Content-Type': 'application/json', 'x-goog-api-key': apiKey},
        body: jsonEncode({'contents': [{'parts': [{'text': prompt}]}]}),
      );
      final String text;
      if (httpResp.statusCode == 200) {
        final data = jsonDecode(httpResp.body);
        text = data['candidates'][0]['content']['parts'][0]['text'] as String;
      } else {
        text = '';
      }

      // 6. Parse the response
      final lines = text.trim().split('\n');
      String professional = 'Dr. Sarah';
      String reason =
          'Based on your overall wellness patterns, a CBT specialist can help build resilience.';
      String urgency = 'LOW';

      for (final line in lines) {
        if (line.startsWith('PROFESSIONAL:')) {
          professional = line.replaceFirst('PROFESSIONAL:', '').trim();
        } else if (line.startsWith('REASON:')) {
          reason = line.replaceFirst('REASON:', '').trim();
        } else if (line.startsWith('URGENCY:')) {
          urgency = line.replaceFirst('URGENCY:', '').trim().toUpperCase();
        }
      }

      // Validate the professional name
      final validNames =
          _professionals.map((p) => p['name'] as String).toList();
          
      bool isValid = false;
      for (final name in validNames) {
        if (name.toLowerCase() == professional.toLowerCase() || 
            professional.toLowerCase().contains(name.toLowerCase())) {
          professional = name; // exact formatted name
          isValid = true;
          break;
        }
      }

      if (!isValid) {
        professional = validNames.first;
        reason = 'Based on your overall wellness patterns, a CBT specialist can help build resilience.';
      }

      return {
        'professional': professional,
        'reason': reason,
        'urgency': urgency,
      };
    } catch (e) {
      debugPrint('AI matchmaking failed: $e');
      return _defaultRecommendation();
    }
  }

  static Map<String, String> _defaultRecommendation() {
    return {
      'professional': 'Dr. Sarah',
      'reason':
          'Start with a CBT specialist to build a strong mental wellness foundation.',
      'urgency': 'LOW',
    };
  }

  // ── Pre-Session Data Briefing ───────────────────────────────

  /// Generates a summary of the user's recent mental health data
  /// that can be shared with the therapist before a session.
  static Future<String> generateSessionBriefing() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 'No data available.';

      // 1. Sleep data
      final avgSleep = await SleepStorageService.getWeeklyAverageSleep();
      final sleepSummary = await SleepStorageService.getWeeklySummary();
      int daysLogged = 0;
      double totalScore = 0;
      for (final entry in sleepSummary.entries) {
        if (entry.value != null) {
          daysLogged++;
          totalScore += entry.value!.sleepScore;
        }
      }
      final avgScore = daysLogged > 0 ? (totalScore / daysLogged) : 0;

      // 2. Recent journals
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      final journalSnapshot = await _db
          .collection('journals')
          .where('uid', isEqualTo: user.uid)
          .get();

      final recentJournals = journalSnapshot.docs
          .map((doc) => doc.data())
          .where((j) {
        try {
          final date = DateTime.parse(j['date'] as String);
          return date.isAfter(sevenDaysAgo);
        } catch (_) {
          return false;
        }
      }).toList();

      final journalTags = <String, int>{};
      for (final j in recentJournals) {
        final tag = (j['tag'] as String?) ?? 'GENERAL';
        journalTags[tag] = (journalTags[tag] ?? 0) + 1;
      }

      // 3. Task completion (last 7 days)
      final now = DateTime.now();
      int completedTasks = 0;
      int totalTasks = 0;
      for (int i = 0; i < 7; i++) {
        final date = now.subtract(Duration(days: i));
        final targetDate = DateTime(date.year, date.month, date.day);
        final taskSnap = await _db
            .collection('tasks')
            .where('uid', isEqualTo: user.uid)
            .where('date', isEqualTo: Timestamp.fromDate(targetDate))
            .get();
        for (final doc in taskSnap.docs) {
          totalTasks++;
          if (doc.data()['status'] == 'Done') completedTasks++;
        }
      }

      // 4. Build the briefing
      final buffer = StringBuffer();
      buffer.writeln('=== Pre-Session Briefing ===');
      buffer.writeln('Generated: ${DateTime.now().toIso8601String()}');
      buffer.writeln('');
      buffer.writeln('── Sleep (Last 7 Days) ──');
      buffer.writeln('Average Sleep: ${avgSleep > 0 ? '${avgSleep.toStringAsFixed(1)} hours/night' : 'No data'}');
      buffer.writeln('Days Logged: $daysLogged / 7');
      buffer.writeln('Average Sleep Score: ${avgScore > 0 ? avgScore.toStringAsFixed(0) : 'N/A'} / 100');
      buffer.writeln('');
      buffer.writeln('── Journal Activity ──');
      buffer.writeln('Entries This Week: ${recentJournals.length}');
      if (journalTags.isNotEmpty) {
        buffer.writeln('Topics: ${journalTags.entries.map((e) => '${e.key} (${e.value})').join(', ')}');
      }
      buffer.writeln('');
      buffer.writeln('── Task Completion ──');
      buffer.writeln('Tasks Completed: $completedTasks / $totalTasks');
      if (totalTasks > 0) {
        final rate = (completedTasks / totalTasks * 100).toStringAsFixed(0);
        buffer.writeln('Completion Rate: $rate%');
      }

      return buffer.toString();
    } catch (e) {
      debugPrint('Briefing generation failed: $e');
      return 'Could not generate briefing at this time.';
    }
  }
}
