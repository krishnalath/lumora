import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../native_bridge.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/conversation_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'dart:io';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/sleep_storage_service.dart';
import '../services/youtube_service.dart';
import '../widgets/video_suggestion_card.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key, this.onLiveStatusChanged});

  final ValueChanged<bool>? onLiveStatusChanged;

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  static const String _geminiModel = 'gemini-2.5-flash';
  static const String _geminiEndpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/$_geminiModel:generateContent';

  Future<String> _callGemini(String prompt) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    final response = await http.post(
      Uri.parse(_geminiEndpoint),
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': apiKey,
      },
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.9,
          'maxOutputTokens': 1024,
        }
      }),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['candidates'][0]['content']['parts'][0]['text'] as String;
    } else {
      final data = jsonDecode(response.body);
      throw Exception(data['error']['message'] ?? 'HTTP ${response.statusCode}');
    }
  }
  bool _isLoading = false;
  int? _editingIndex; // index of user message being edited

  late List<Map<String, dynamic>> _messages;
  late Conversation _currentConversation;
  bool _isInitialized = false;

  // Health context tracking — used to build the system context prefix
  int? _lastMood;
  int? _lastEnergy;
  double? _lastSleepHours;
  String? _lastSleepQuality;
  bool _contextInjectedThisSession = false;

  // Voice input
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _speechAvailable = false;

  // Image picker
  final ImagePicker _imagePicker = ImagePicker();
  // Staged attachments (multi-image before send)
  final List<File> _pendingImages = [];

  double _moodValue = 5.0;
  double _energyValue = 5.0;

  bool _isHighRiskDetected = false;
  final List<String> _riskKeywords = [
    'give up',
    'no hope',
    'harm',
    'end it',
    'cant take it anymore',
    'worthless',
    'better off without me',
    'suicide',
    'kill myself',
  ];

  @override
  void initState() {
    super.initState();
    _initializeConversation();
    _initSpeech();
    _msgController.addListener(_checkRiskLevel);
  }

  Future<void> _initSpeech() async {
    // Explicitly request mic permission — STT silently fails without it
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      if (mounted) setState(() => _speechAvailable = false);
      return;
    }

    // Re-initialize each time to ensure a fresh engine session
    if (_speech.isAvailable) {
      await _speech.stop();
    }

    _speechAvailable = await _speech.initialize(
      onError: (e) {
        debugPrint('STT error: ${e.errorMsg}');
        if (mounted) setState(() => _isListening = false);
      },
      onStatus: (status) {
        debugPrint('STT status: $status');
        if (mounted) {
          // Only mark as not-listening on final states
          if (status == 'done' || status == 'notListening') {
            setState(() => _isListening = false);
          } else if (status == stt.SpeechToText.listeningStatus) {
            setState(() => _isListening = true);
          }
        }
      },
      debugLogging: false,
    );
    if (mounted) setState(() {});
  }

  Future<void> _initializeConversation() async {
    // Always start completely fresh — clear any remembered session
    await ConversationService.clearCurrentConversation();
    _currentConversation = ConversationService.createNewConversation();
    _messages = [];
    // Reset context injection flag so the health prefix fires again on first message
    _contextInjectedThisSession = false;
    _lastMood = null;
    _lastEnergy = null;
    _lastSleepHours = null;
    _lastSleepQuality = null;
    print('Luna: System Online');
    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    _msgController.removeListener(_checkRiskLevel);
    super.dispose();
  }

  void _checkRiskLevel() {
    final text = _msgController.text.toLowerCase();
    bool foundRisk = _riskKeywords.any((keyword) => text.contains(keyword));

    if (foundRisk != _isHighRiskDetected) {
      setState(() {
        _isHighRiskDetected = foundRisk;
      });
    }
  }

  bool get _hasApiKeyConfigured {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    return apiKey != null && apiKey.trim().isNotEmpty;
  }

  void _showMissingApiKeyError() {
    AppTheme.showCustomSnackBar(
      context,
      'Luna AI is not configured. Please add a valid GEMINI_API_KEY to your .env file.',
      isError: true,
    );
  }

  Future<void> _saveCurrentConversationState() async {
    if (_messages.isEmpty) return;
    _currentConversation = Conversation(
      id: _currentConversation.id,
      title: _currentConversation.title,
      messages: _messages,
      createdAt: _currentConversation.createdAt,
      lastModified: DateTime.now(),
    );
    await ConversationService.saveConversation(_currentConversation);
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    if (!_hasApiKeyConfigured) {
      _showMissingApiKeyError();
      return;
    }

    // Generate title from first message
    if (_messages.isEmpty) {
      _currentConversation = Conversation(
        id: _currentConversation.id,
        title: ConversationService.generateTitleFromMessage(text),
        messages: _currentConversation.messages,
        createdAt: _currentConversation.createdAt,
        lastModified: DateTime.now(),
      );
    }

    // 1. Update UI with User's Message
    setState(() {
      _messages.add({
        'isBot': false,
        'text': text.trim(),
        'time':
            '${TimeOfDay.now().hour}:${TimeOfDay.now().minute.toString().padLeft(2, '0')} AM',
      });
      _isLoading = true;
    });

    _msgController.clear();
    await _saveCurrentConversationState();

    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    try {
      // 2. Construct health context from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final int currentMood = prefs.getInt('latest_mood') ?? -1;
      final String? currentMoodStr = prefs.getString('latest_mood_str');
      final int currentEnergy = prefs.getInt('latest_energy') ?? -1;
      final String? currentEnergyStr = prefs.getString('latest_energy_str');
      
      // Read accurate sleep log from the modern SleepStorageService
      final todaySleep = await SleepStorageService.getTodaySleep();
      final double currentSleepHours = todaySleep != null ? todaySleep.duration.inMinutes / 60.0 : -1.0;
      final int currentSleepScore = todaySleep != null ? todaySleep.sleepScore : -1;
      final String currentSleepQuality = todaySleep != null ? '${todaySleep.durationFormatted}' : '';

      // Determine whether health values have changed since last injection
      // Only consider it a "change" if we have already injected once this session (_lastMood != null)
      final bool healthChanged = _lastMood != null &&
          (currentMood != _lastMood ||
          currentEnergy != _lastEnergy ||
          currentSleepHours != _lastSleepHours ||
          currentSleepQuality != _lastSleepQuality);

      final bool isNewConversation = _messages.length <= 1;

      // Build the health context prefix only on first message of a new conversation or when data actually changed
      String healthContextPrefix = '';
      if (isNewConversation || healthChanged) {
        if (currentMood >= 0 || currentEnergy >= 0 || currentSleepHours >= 0) {
          final moodStr = currentMoodStr ?? (currentMood >= 0 ? '${currentMood}/10' : 'unknown');
          final energyStr = currentEnergyStr ?? (currentEnergy >= 0 ? '${currentEnergy}/10' : 'unknown');
          final sleepStr = currentSleepHours >= 0
              ? '${currentSleepHours.toStringAsFixed(1)} hrs (Score: $currentSleepScore/100)'
              : 'Not logged today';

          healthContextPrefix =
              '[Health Context: Mood is $moodStr, Energy is $energyStr, Sleep $sleepStr]\n\n';

          // Remember what we injected
          _lastMood = currentMood;
          _lastEnergy = currentEnergy;
          _lastSleepHours = currentSleepHours;
          _lastSleepQuality = currentSleepQuality;
          _contextInjectedThisSession = true;
        }
      } else if (_lastMood == null) {
        // Sync state on load so future changes are detected
        _lastMood = currentMood;
        _lastEnergy = currentEnergy;
        _lastSleepHours = currentSleepHours;
        _lastSleepQuality = currentSleepQuality;
        _contextInjectedThisSession = true;
      }

      // 3. Build full prompt with system context
      String contextString = 'Local DB Search Results:\n';
      for (var result in searchResults) {
        contextString +=
            '- Context [ID: ${result['id']}]: Found relevant memory with distance ${result['distance'].toStringAsFixed(4)}\n';
      }

      String historyString = '';
      for (int i = 0; i < _messages.length - 1; i++) {
        final msg = _messages[i];
        final role = msg['isBot'] == true ? 'Luna' : 'User';
        historyString += '$role: ${msg['text']}\n\n';
      }

      final String fullPrompt =
          '''
You are Luna, a warm, empathetic, and helpful mental health companion inside the Lumora app.

Lumora App Features:
- Sleep Insights: Log bedtime/wake-up times, track sleep patterns and 7-day averages.
- Journal: Write daily journals, tag them, and reflect on emotions.
- Routines: Log Morning, Afternoon, Night routines including mood and energy check-ins.
- Care Hub: Find professional therapists, emergency hotlines, and coping tools.
- My Tasks: Manage daily to-do lists and personal goals.

If the user describes a problem with a clear physical or technical solution (e.g., yoga for back pain, breathing for anxiety, meditation for sleep), include a special tag in your response exactly like [VIDEO_SEARCH: search_term]. Only use ONE tag per response.

If the provided Health Context shows a low sleep score (<60) or low energy ("Low" or "Exhausted"), proactively check up on the user's mood and offer supportive advice or ask how they are coping today. Do not ask again if it has already been discussed in the Conversation History.

Use the following local context from the user's C++ database (which contains past journal entries, sleep logs, or routines) if it's relevant to their query. If no DB context is provided or relevant, just chat naturally based on your capabilities.

$contextString

Conversation History:
$historyString

${healthContextPrefix}User Question: $text
''';

      // 4. Call Gemini via HTTP (supports both AIzaSy and AQ. key formats)
      String reply = await _callGemini(fullPrompt);
      widget.onLiveStatusChanged?.call(true);

      // Check for video tag
      final videoTagRegex = RegExp(r'\[VIDEO_SEARCH:\s*(.*?)\]');
      final match = videoTagRegex.firstMatch(reply);
      String? videoSearchTerm;
      if (match != null) {
        videoSearchTerm = match.group(1);
        reply = reply.replaceAll(match.group(0)!, '').trim();
      }

      // 6. Update UI with Bot's response
      if (mounted) {
        setState(() {
          _isLoading = false;
          _messages.add({
            'isBot': true,
            'text': reply,
            'time':
                '${TimeOfDay.now().hour}:${TimeOfDay.now().minute.toString().padLeft(2, '0')} AM',
            if (videoSearchTerm != null) 'videoSearchTerm': videoSearchTerm,
            if (videoSearchTerm != null) 'isLoadingVideo': true,
          });
        });

        final msgIndex = _messages.length - 1;

        if (videoSearchTerm != null) {
          YouTubeService.searchBestVideo(videoSearchTerm).then((videoData) {
            if (mounted) {
              setState(() {
                _messages[msgIndex]['isLoadingVideo'] = false;
                if (videoData != null) {
                  _messages[msgIndex]['videoData'] = {
                    'id': videoData.id,
                    'title': videoData.title,
                    'thumbnailUrl': videoData.thumbnailUrl,
                    'author': videoData.author,
                    'durationInSeconds': videoData.duration.inSeconds,
                  };
                }
              });
              // We do not save videoData to DB right now to keep Conversation model simple
            }
          });
        }

        Future.delayed(const Duration(milliseconds: 100), () {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }

      // 7. Save conversation with messages
      _currentConversation = Conversation(
        id: _currentConversation.id,
        title: _currentConversation.title,
        messages: _messages,
        createdAt: _currentConversation.createdAt,
        lastModified: DateTime.now(),
      );
      await ConversationService.saveConversation(_currentConversation);
    } catch (e) {
      if (!mounted) return;

      final String errorStr = e.toString().toLowerCase();
      final statusCode =
          RegExp(
            r'\b(401|403|404|429|500|502|503)\b',
          ).firstMatch(errorStr)?.group(0) ??
          'unknown';
      debugPrint('AI send error: $e [status=$statusCode]');
      final bool isAuthError =
          errorStr.contains('unauthorized') ||
          errorStr.contains('invalid') ||
          errorStr.contains('permission') ||
          errorStr.contains('api key');
      final bool isRateLimit =
          errorStr.contains('429') ||
          errorStr.contains('quota') ||
          errorStr.contains('too many requests');
      final bool isServerOverloaded =
          errorStr.contains('503') ||
          errorStr.contains('high demand') ||
          errorStr.contains('unavailable');

      if (isAuthError) {
        setState(() => _isLoading = false);
        AppTheme.showCustomSnackBar(
          context,
          'Luna could not authenticate with Gemini. Check your GEMINI_API_KEY and Google Cloud billing.',
          isError: true,
        );
      } else if (isRateLimit) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            backgroundColor: const Color(0xFF1E212B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Color(0xFF00E5FF), width: 1),
            ),
            duration: const Duration(seconds: 6),
            content: Row(
              children: [
                const Icon(
                  Icons.hourglass_bottom_rounded,
                  color: Color(0xFF00E5FF),
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Luna needs a breather! 🌙 Your Gemini key may be rate limited or out of quota.',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      color: Colors.white,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      } else if (isServerOverloaded) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            backgroundColor: const Color(0xFF1E212B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Color(0xFFFFB300), width: 1),
            ),
            duration: const Duration(seconds: 6),
            content: Row(
              children: [
                const Icon(
                  Icons.cloud_off_rounded,
                  color: Color(0xFFFFB300),
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Luna is experiencing very high traffic! Please wait a moment and try again.',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      color: Colors.white,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        setState(() {
          _isLoading = false;
          _messages.add({
            'isBot': true,
            'text':
                "Something went wrong on my end: $errorStr\nPlease check if your GEMINI_API_KEY is valid. 💙",
            'time':
                '${TimeOfDay.now().hour}:${TimeOfDay.now().minute.toString().padLeft(2, '0')} AM',
          });
        });

        await _saveCurrentConversationState();

        Future.delayed(const Duration(milliseconds: 100), () {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
        ),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppTheme.background,
      endDrawer: _buildHistoryDrawer(),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header & Sliders
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Luna AI',
                        style: GoogleFonts.outfit(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textDark,
                          letterSpacing: -0.5,
                        ),
                      ).animate().shimmer(
                        duration: 2000.ms,
                        color: const Color(0xFF00E5FF),
                      ),
                      GestureDetector(
                        onTap: () => _scaffoldKey.currentState?.openEndDrawer(),
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: const Icon(
                            Icons.menu_rounded,
                            color: AppTheme.textDark,
                            size: 28,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 4),

            // Messages
            Expanded(
              child: _messages.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.smart_toy_rounded,
                              size: 40,
                              color: const Color(0xFF00E5FF).withOpacity(0.35),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'How can Luna support you today?',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: const Color(
                                  0xFF161A23,
                                ).withOpacity(0.75),
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Mental check-ins, study stress, sleep insights, or just to feel heard.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.dmSans(
                                fontSize: 14,
                                color: const Color(
                                  0xFF161A23,
                                ).withOpacity(0.45),
                                height: 1.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _messages.length + (_isLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _messages.length && _isLoading) {
                          return _buildTypingIndicator();
                        }
                        final msg = _messages[index];
                        final isUser = !(msg['isBot'] as bool);
                        return _ChatBubble(
                          message: msg,
                          onEdit: isUser && !_isLoading
                              ? () => _startEdit(index)
                              : null,
                        );
                      },
                    ),
            ),

            // --- Bottom input area ---
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1E212B),
                border: Border(top: BorderSide(color: Color(0xFF2A2E3B))),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // --- Proactive Safety Banner ---
                  if (_isHighRiskDetected)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF4B4B).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFFFF4B4B).withOpacity(0.4),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.favorite,
                                color: Color(0xFFFF4B4B),
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  "You're not alone. Help is available right now.",
                                  style: GoogleFonts.dmSans(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () {
                              // Reassuring dialog before switching to Care Hub
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: const Color(0xFF1E212B),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  title: Text(
                                    "Help is Here",
                                    style: GoogleFonts.dmSans(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  content: Text(
                                    "We're connecting you to our Care Hub. Please talk to a verified professional or use our emergency resources.",
                                    style: GoogleFonts.dmSans(
                                      color: Colors.white70,
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: Text(
                                        "CANCEL",
                                        style: GoogleFonts.dmSans(
                                          color: Colors.white54,
                                        ),
                                      ),
                                    ),
                                    ElevatedButton(
                                      onPressed: () {
                                        Navigator.pop(ctx); // Close dialog
                                        _msgController
                                            .clear(); // Clear high risk message
                                        // Since we are in the Shell, we can't easily switch tabs without a key or controller,
                                        // but for this evolution we'll show the intent.
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              "Redirecting to Care Hub...",
                                            ),
                                          ),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFFFF4B4B,
                                        ),
                                      ),
                                      child: const Text(
                                        "CONTINUE",
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF4B4B),
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 44),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              'Connect to a Professional',
                              style: GoogleFonts.dmSans(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn().slideY(begin: 0.2, end: 0),
                  // Attachment preview strip (shown when images are staged)
                  if (_pendingImages.isNotEmpty)
                    Container(
                      height: 100,
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _pendingImages.length + 1,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          // Last item = "Add more" button
                          if (index == _pendingImages.length) {
                            return GestureDetector(
                              onTap: _openMediaPicker,
                              child: Container(
                                width: 80,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2A2E3B),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(
                                      0xFF00E5FF,
                                    ).withOpacity(0.4),
                                    width: 1.5,
                                  ),
                                ),
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_photo_alternate_rounded,
                                      color: Color(0xFF00E5FF),
                                      size: 22,
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Add',
                                      style: TextStyle(
                                        color: Color(0xFF00E5FF),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
                          // Image thumbnail with remove button
                          return Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  _pendingImages[index],
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 2,
                                right: 2,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(
                                      () => _pendingImages.removeAt(index),
                                    );
                                  },
                                  child: Container(
                                    width: 20,
                                    height: 20,
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),

                  // Input row
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      _pendingImages.isNotEmpty ? 8 : 12,
                      16,
                      12 + MediaQuery.of(context).padding.bottom,
                    ),
                    child: Row(
                      children: [
                        // Mic button
                        GestureDetector(
                          onTap: _handleVoiceInput,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isListening
                                  ? const Color(0xFFFF4B4B)
                                  : const Color(0xFF2A2E3B),
                              boxShadow: _isListening
                                  ? [
                                      BoxShadow(
                                        color: const Color(
                                          0xFFFF4B4B,
                                        ).withOpacity(0.5),
                                        blurRadius: 12,
                                        spreadRadius: 2,
                                      ),
                                    ]
                                  : [],
                            ),
                            child: Icon(
                              _isListening
                                  ? Icons.mic_rounded
                                  : Icons.mic_none_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Text field + attach
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: _editingIndex != null
                                  ? const Color(0xFF2A2E3B)
                                  : const Color(0xFF252A36),
                              borderRadius: BorderRadius.circular(28),
                              border: _editingIndex != null
                                  ? Border.all(
                                      color: const Color(
                                        0xFF00E5FF,
                                      ).withOpacity(0.5),
                                      width: 1,
                                    )
                                  : null,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _msgController,
                                    style: GoogleFonts.dmSans(
                                      fontSize: 14,
                                      color: Colors.white,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: _editingIndex != null
                                          ? 'Editing message…'
                                          : _pendingImages.isEmpty
                                          ? 'Ask Luna anything...'
                                          : 'Add a caption… (optional)',
                                      hintStyle: GoogleFonts.dmSans(
                                        fontSize: 14,
                                        color: _editingIndex != null
                                            ? const Color(
                                                0xFF00E5FF,
                                              ).withOpacity(0.6)
                                            : Colors.grey,
                                      ),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    onSubmitted: (_) => _handleSend(),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (_editingIndex != null)
                                  GestureDetector(
                                    onTap: _cancelEdit,
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: const Color(
                                          0xFF00E5FF,
                                        ).withOpacity(0.15),
                                      ),
                                      child: const Icon(
                                        Icons.close_rounded,
                                        color: Color(0xFF00E5FF),
                                        size: 18,
                                      ),
                                    ),
                                  )
                                else
                                  GestureDetector(
                                    onTap: _openMediaPicker,
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: const BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Color(0xFF1E212B),
                                          ),
                                          child: Icon(
                                            Icons.attach_file_rounded,
                                            color: _pendingImages.isNotEmpty
                                                ? const Color(0xFF00E5FF)
                                                : Colors.white54,
                                            size: 18,
                                          ),
                                        ),
                                        if (_pendingImages.isNotEmpty)
                                          Positioned(
                                            right: 0,
                                            top: 0,
                                            child: Container(
                                              width: 16,
                                              height: 16,
                                              decoration: const BoxDecoration(
                                                color: Color(0xFF00E5FF),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Center(
                                                child: Text(
                                                  '${_pendingImages.length}',
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.black,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Send / Pause button
                        GestureDetector(
                          onTap: _handleSend,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isLoading
                                  ? const Color(0xFFFF6B6B)
                                  : const Color(0xFF00E5FF),
                            ),
                            child: Icon(
                              _isLoading
                                  ? Icons.pause_rounded
                                  : Icons.send_rounded,
                              color: Colors.black,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF1E212B),
      child: StatefulBuilder(
        builder: (context, setDrawerState) {
          return FutureBuilder<List<Conversation>>(
            future: ConversationService.getAllConversations(),
            builder: (context, snapshot) {
              final conversations = snapshot.data ?? [];
              return Column(
                children: [
                  // Drawer header
                  SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Chats',
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          Row(
                            children: [
                              // New chat button
                              IconButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _initializeConversation();
                                },
                                icon: const Icon(
                                  Icons.add_rounded,
                                  color: Color(0xFF00E5FF),
                                ),
                                tooltip: 'New Chat',
                              ),
                              // Clear all button
                              if (conversations.isNotEmpty)
                                IconButton(
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        backgroundColor: const Color(
                                          0xFF1E212B,
                                        ),
                                        title: Text(
                                          'Clear All?',
                                          style: GoogleFonts.dmSans(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        content: Text(
                                          'This will delete all conversations.',
                                          style: GoogleFonts.dmSans(
                                            color: Colors.white70,
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, false),
                                            child: Text(
                                              'Cancel',
                                              style: GoogleFonts.dmSans(
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, true),
                                            child: Text(
                                              'Delete All',
                                              style: GoogleFonts.dmSans(
                                                color: const Color(0xFFFF6B6B),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      await ConversationService.clearAllConversations();
                                      _initializeConversation();
                                      if (context.mounted) {
                                        Navigator.pop(context);
                                      }
                                    }
                                  },
                                  icon: Icon(
                                    Icons.delete_sweep_rounded,
                                    color: Colors.white.withOpacity(0.5),
                                  ),
                                  tooltip: 'Clear All',
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(color: Color(0xFF2A2E3B), height: 1),
                  // List
                  Expanded(
                    child: !snapshot.hasData
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF00E5FF),
                            ),
                          )
                        : conversations.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  size: 48,
                                  color: Colors.white.withOpacity(0.2),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No conversations yet',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.4),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 12,
                            ),
                            itemCount: conversations.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 4),
                            itemBuilder: (context, index) {
                              final conv = conversations[index];
                              final isActive =
                                  conv.id == _currentConversation.id;
                              return Material(
                                color: isActive
                                    ? const Color(0xFF00E5FF).withOpacity(0.12)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () {
                                    Navigator.pop(context);
                                    _loadConversation(conv);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.chat_rounded,
                                          size: 18,
                                          color: isActive
                                              ? const Color(0xFF00E5FF)
                                              : Colors.white.withOpacity(0.5),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                conv.title,
                                                style: GoogleFonts.dmSans(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: isActive
                                                      ? const Color(0xFF00E5FF)
                                                      : Colors.white,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${conv.messages.length} messages',
                                                style: GoogleFonts.dmSans(
                                                  fontSize: 11,
                                                  color: Colors.white
                                                      .withOpacity(0.4),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Delete button
                                        GestureDetector(
                                          onTap: () async {
                                            await ConversationService.deleteConversation(
                                              conv.id,
                                            );
                                            if (isActive)
                                              _initializeConversation();
                                            setDrawerState(
                                              () {},
                                            ); // refresh drawer list
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.all(4),
                                            child: Icon(
                                              Icons.delete_outline_rounded,
                                              size: 18,
                                              color: Colors.white.withOpacity(
                                                0.4,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _loadConversation(Conversation conversation) {
    setState(() {
      _currentConversation = conversation;
      _messages = conversation.messages;
    });

    // Auto-scroll to bottom
    Future.delayed(const Duration(milliseconds: 100), () {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _handleVoiceInput() async {
    if (!mounted) return;

    if (_isListening) {
      // Tap again to stop — text stays in field for review
      await _speech.stop();
      setState(() => _isListening = false);
      return;
    }

    // Always re-init before listening to ensure a fresh Android engine session.
    // This is the fix for "mic starts and immediately closes" on Android.
    await _initSpeech();

    if (!_speechAvailable) {
      if (!mounted) return;
      AppTheme.showCustomSnackBar(
        context,
        'Microphone permission is required for voice input.',
        action: SnackBarAction(
          label: 'Settings',
          textColor: const Color(0xFF00E5FF),
          onPressed: () => openAppSettings(),
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _isListening = true);
    _msgController.clear();

    await _speech.listen(
      onResult: (result) {
        if (mounted) {
          setState(() {
            _msgController.text = result.recognizedWords;
            _msgController.selection = TextSelection.fromPosition(
              TextPosition(offset: _msgController.text.length),
            );
          });
        }
      },
      listenFor: const Duration(minutes: 2),
      pauseFor: const Duration(seconds: 30),
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        cancelOnError: false,
        autoPunctuation: true,
      ),
    );
  }

  // Called when user wants to edit a previously sent message
  void _startEdit(int index) {
    final msg = _messages[index];
    setState(() {
      _editingIndex = index;
      _msgController.text = msg['text'] as String? ?? '';
      _msgController.selection = TextSelection.fromPosition(
        TextPosition(offset: _msgController.text.length),
      );
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingIndex = null;
      _msgController.clear();
    });
  }

  // Unified send: handles text-only, image(s)-only, or text + images
  Future<void> _handleSend() async {
    // If loading, cancel (pause) the current request
    if (_isLoading) {
      setState(() {
        _isLoading = false;
        // Remove the typing indicator by not adding a bot message
      });
      return;
    }

    final text = _msgController.text.trim();
    final hasImages = _pendingImages.isNotEmpty;
    if (text.isEmpty && !hasImages) return;

    // If editing a previous message, re-send from that point
    if (_editingIndex != null) {
      final idx = _editingIndex!;
      setState(() {
        // Trim all messages from the edited one onward
        _messages.removeRange(idx, _messages.length);
        _editingIndex = null;
      });
      _msgController.clear();
      await _sendMessage(text);
      return;
    }

    if (hasImages) {
      final images = List<File>.from(_pendingImages);
      setState(() => _pendingImages.clear());
      await _sendImageMessage(images, caption: text);
      _msgController.clear();
    } else {
      _sendMessage(text);
    }
  }

  Future<void> _openMediaPicker() async {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E212B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _pendingImages.isEmpty ? 'Add media' : 'Add more photos',
                style: GoogleFonts.dmSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              _buildMediaOption(
                ctx,
                Icons.photo_library_rounded,
                'Photo from Gallery',
                'Pick one or more images from your library',
                onTap: () async {
                  Navigator.pop(ctx);
                  // Pick multiple images
                  final List<XFile> files = await _imagePicker.pickMultiImage(
                    imageQuality: 85,
                  );
                  if (files.isNotEmpty && mounted) {
                    setState(() {
                      for (final f in files) {
                        _pendingImages.add(File(f.path));
                      }
                    });
                  }
                },
              ),
              _buildMediaOption(
                ctx,
                Icons.camera_alt_rounded,
                'Take a Photo',
                'Use camera to capture an image',
                onTap: () async {
                  Navigator.pop(ctx);
                  final XFile? file = await _imagePicker.pickImage(
                    source: ImageSource.camera,
                    imageQuality: 85,
                  );
                  if (file != null && mounted) {
                    setState(() => _pendingImages.add(File(file.path)));
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMediaOption(
    BuildContext ctx,
    IconData icon,
    String title,
    String subtitle, {
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFF2A2E3B),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: const Color(0xFF00E5FF), size: 22),
      ),
      title: Text(
        title,
        style: GoogleFonts.dmSans(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.dmSans(color: Colors.white54, fontSize: 12),
      ),
      onTap: onTap,
    );
  }

  Future<void> _sendImageMessage(
    List<File> imageFiles, {
    String caption = '',
  }) async {
    final time =
        '${TimeOfDay.now().hour}:${TimeOfDay.now().minute.toString().padLeft(2, '0')} AM';

    // Show each image as its own bubble (with caption on last one)
    setState(() {
      for (int i = 0; i < imageFiles.length; i++) {
        _messages.add({
          'isBot': false,
          'text': (i == imageFiles.length - 1 && caption.isNotEmpty)
              ? caption
              : '',
          'imagePath': imageFiles[i].path,
          'time': time,
        });
      }
      _isLoading = true;
    });

    await _saveCurrentConversationState();

    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    if (!_hasApiKeyConfigured) {
      _showMissingApiKeyError();
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Build multimodal request using base64 images via HTTP
      final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
      final userText = caption.isNotEmpty
          ? caption
          : 'Please analyze this image and respond empathetically as Luna, a mental health companion.';

      final parts = <Map<String, dynamic>>[];
      for (final file in imageFiles) {
        final bytes = await file.readAsBytes();
        final base64Image = base64Encode(bytes);
        parts.add({'inline_data': {'mime_type': 'image/jpeg', 'data': base64Image}});
      }
      parts.add({'text': userText});

      final httpResponse = await http.post(
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent'),
        headers: {'Content-Type': 'application/json', 'x-goog-api-key': apiKey},
        body: jsonEncode({'contents': [{'parts': parts}]}),
      );

      final String reply;
      if (httpResponse.statusCode == 200) {
        final data = jsonDecode(httpResponse.body);
        reply = data['candidates'][0]['content']['parts'][0]['text'] as String;
      } else {
        final data = jsonDecode(httpResponse.body);
        throw Exception(data['error']['message'] ?? 'HTTP ${httpResponse.statusCode}');
      }
      widget.onLiveStatusChanged?.call(true);

      if (mounted) {
        setState(() {
          _isLoading = false;
          _messages.add({'isBot': true, 'text': reply.trim(), 'time': time});
        });

        Future.delayed(const Duration(milliseconds: 100), () {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });

        _currentConversation = Conversation(
          id: _currentConversation.id,
          title: _currentConversation.messages.isEmpty
              ? (caption.isNotEmpty ? caption : 'Image conversation')
              : _currentConversation.title,
          messages: _messages,
          createdAt: _currentConversation.createdAt,
          lastModified: DateTime.now(),
        );
        await ConversationService.saveConversation(_currentConversation);
      }
    } catch (e) {
      if (!mounted) return;

      final String errorStr = e.toString().toLowerCase();
      final statusCode =
          RegExp(
            r'\b(401|403|404|429|500|502|503)\b',
          ).firstMatch(errorStr)?.group(0) ??
          'unknown';
      debugPrint('AI image send error: $e [status=$statusCode]');
      final bool isAuthError =
          errorStr.contains('unauthorized') ||
          errorStr.contains('invalid') ||
          errorStr.contains('permission') ||
          errorStr.contains('api key');
      final bool isRateLimit =
          errorStr.contains('429') ||
          errorStr.contains('quota') ||
          errorStr.contains('too many requests');

      if (isAuthError) {
        setState(() => _isLoading = false);
        AppTheme.showCustomSnackBar(
          context,
          'Luna could not authenticate with Gemini. Check your GEMINI_API_KEY and Google Cloud billing.',
          isError: true,
        );
      } else if (isRateLimit) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            backgroundColor: const Color(0xFF1E212B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Color(0xFF00E5FF), width: 1),
            ),
            duration: const Duration(seconds: 6),
            content: Row(
              children: [
                const Icon(
                  Icons.hourglass_bottom_rounded,
                  color: Color(0xFF00E5FF),
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Luna needs a breather! 🌙 Your Gemini key may be rate limited or out of quota.',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      color: Colors.white,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        setState(() {
          _isLoading = false;
          _messages.add({
            'isBot': true,
            'text':
                "Something went wrong analyzing the image(s). Please try again. 💙",
            'time': time,
          });
        });

        await _saveCurrentConversationState();
      }
    }
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.only(right: 8),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF1E212B),
            ),
            child: const Icon(
              Icons.smart_toy_rounded,
              color: Color(0xFF00E5FF),
              size: 18,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF1E212B),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(18),
              ),
            ),
            child: Text(
              'Luna is replying...',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: Colors.white54,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final VoidCallback? onEdit;

  const _ChatBubble({required this.message, this.onEdit});

  @override
  Widget build(BuildContext context) {
    final isBot = message['isBot'] as bool;
    final showBreathing = message['showBreathing'] == true;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: isBot
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: isBot
                ? MainAxisAlignment.start
                : MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (isBot) ...[
                Container(
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF1E212B),
                  ),
                  child: const Icon(
                    Icons.smart_toy_rounded,
                    color: Color(0xFF00E5FF),
                    size: 18,
                  ),
                ),
              ],
              Flexible(
                child: Container(
                  padding: message['imagePath'] != null
                      ? const EdgeInsets.all(4)
                      : const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isBot
                        ? const Color(0xFF1E212B)
                        : const Color(0xFF00E5FF),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isBot ? 4 : 18),
                      bottomRight: Radius.circular(isBot ? 18 : 4),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: message['imagePath'] != null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.file(
                                File(message['imagePath'] as String),
                                width: 200,
                                fit: BoxFit.cover,
                              ),
                            ),
                            if ((message['text'] as String?)?.isNotEmpty ==
                                true) ...[
                              const SizedBox(height: 6),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 2,
                                ),
                                child: Text(
                                  message['text'] as String,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 13,
                                    color: isBot
                                        ? Colors.white70
                                        : Colors.black87,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            isBot
                                ? MarkdownBody(
                                    data: message['text'] as String,
                                    styleSheet: MarkdownStyleSheet(
                                      p: GoogleFonts.dmSans(
                                        fontSize: 14,
                                        color: Colors.white,
                                        height: 1.5,
                                      ),
                                      strong: GoogleFonts.dmSans(
                                        fontSize: 14,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        height: 1.5,
                                      ),
                                      em: GoogleFonts.dmSans(
                                        fontSize: 14,
                                        color: Colors.white70,
                                        fontStyle: FontStyle.italic,
                                        height: 1.5,
                                      ),
                                      listBullet: GoogleFonts.dmSans(
                                        fontSize: 14,
                                        color: Colors.white,
                                      ),
                                      blockquote: GoogleFonts.dmSans(
                                        fontSize: 13,
                                        color: Colors.white70,
                                        fontStyle: FontStyle.italic,
                                      ),
                                      code: GoogleFonts.dmMono(
                                        fontSize: 13,
                                        color: const Color(0xFF00E5FF),
                                        backgroundColor: const Color(
                                          0xFF2A2E3B,
                                        ),
                                      ),
                                    ),
                                    shrinkWrap: true,
                                  )
                                : Text(
                                    message['text'] as String,
                                    style: GoogleFonts.dmSans(
                                      fontSize: 14,
                                      color: Colors.black,
                                      height: 1.5,
                                    ),
                                  ),
                            if (message['isLoadingVideo'] == true)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Row(
                                  children: [
                                    const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFF00E5FF),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Finding video...',
                                      style: GoogleFonts.dmSans(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (message['videoData'] != null)
                              VideoSuggestionCard(
                                video: YouTubeVideoData(
                                  id: message['videoData']['id'],
                                  title: message['videoData']['title'],
                                  thumbnailUrl:
                                      message['videoData']['thumbnailUrl'],
                                  author: message['videoData']['author'],
                                  duration: Duration(
                                    seconds:
                                        message['videoData']['durationInSeconds'],
                                  ),
                                ),
                              ),
                          ],
                        ),
                ),
              ),
              if (!isBot) ...[
                Container(
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.only(left: 8),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.textDark,
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ],
            ],
          ),
          Padding(
            padding: EdgeInsets.only(
              left: isBot ? 48 : 0,
              right: isBot ? 0 : 48,
              top: 4,
            ),
            child: Row(
              mainAxisAlignment: isBot
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.end,
              children: [
                Text(
                  message['time'] as String,
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: AppTheme.textLight,
                  ),
                ),
                if (!isBot && onEdit != null) ...[
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: onEdit,
                    child: const Icon(
                      Icons.edit_rounded,
                      size: 13,
                      color: Color(0xFF00E5FF),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (showBreathing) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 48),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E212B),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.air_rounded,
                      color: Color(0xFF00E5FF),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Guided Box\nBreathing',
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E5FF),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'START',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
