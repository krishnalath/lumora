import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/care_hub_service.dart';
import 'crisis_mode_screen.dart';
import 'professional_chat_screen.dart';
import 'help_support_screen.dart';

class CareHubScreen extends StatefulWidget {
  const CareHubScreen({super.key});

  @override
  State<CareHubScreen> createState() => _CareHubScreenState();
}

class _CareHubScreenState extends State<CareHubScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  String _selectedProfessional = 'Dr. Sarah';
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isBooking = false;
  bool _shareBriefing = false;
  bool _showPendingUserRequests = false;

  // AI Recommendation state
  bool _isLoadingRecommendation = true;
  Map<String, String> _aiRecommendation = {};

  late final Stream<QuerySnapshot> _personalSessionsStream;
  late final Stream<QuerySnapshot> _upcomingSessionsStream;

  @override
  void initState() {
    super.initState();
    _loadAIRecommendation();
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _personalSessionsStream = FirebaseFirestore.instance
        .collection('care_sessions')
        .where('uid', isEqualTo: currentUid)
        .snapshots();
    _upcomingSessionsStream = FirebaseFirestore.instance
        .collection('therapist_sessions')
        .snapshots();
  }

  Future<void> _loadAIRecommendation() async {
    if (mounted) {
      setState(() => _isLoadingRecommendation = true);
    }
    try {
      final recommendation = await CareHubService.getAIRecommendation();
      if (mounted) {
        setState(() {
          _aiRecommendation = recommendation;
          _isLoadingRecommendation = false;
          _selectedProfessional = recommendation['professional'] ?? 'Dr. Sarah';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingRecommendation = false);
      }
    }
  }

  Future<void> _bookSession() async {
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date and time first.')),
      );
      return;
    }

    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return;

    setState(() => _isBooking = true);

    try {
      // Check if user already has an active session
      final activeSessionsQuery = await FirebaseFirestore.instance
          .collection('care_sessions')
          .where('uid', isEqualTo: currentUid)
          .get();

      bool hasActiveSession = false;
      final now = DateTime.now();

      for (var doc in activeSessionsQuery.docs) {
        final data = doc.data();
        final status = data['status'] as String? ?? 'pending';

        if (status != 'rejected') {
          final date = (data['date'] as Timestamp?)?.toDate();
          if (date != null) {
            final timeStr = data['time'] as String? ?? '00:00';
            final parts = timeStr.split(':');
            if (parts.length == 2) {
              final sessionDateTime = DateTime(
                date.year,
                date.month,
                date.day,
                int.tryParse(parts[0]) ?? 0,
                int.tryParse(parts[1]) ?? 0,
              );
              // A session is active until 1 hour after it starts
              if (sessionDateTime.add(const Duration(hours: 1)).isAfter(now)) {
                hasActiveSession = true;
                break;
              }
            }
          }
        }
      }

      if (hasActiveSession) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'You already have an active session request or appointment.',
              ),
            ),
          );
          setState(() => _isBooking = false);
        }
        return;
      }

      String? briefing;
      if (_shareBriefing) {
        briefing = await CareHubService.generateSessionBriefing();
      }

      await _firestoreService.bookCareSession(
        professionalName: _selectedProfessional,
        date: _selectedDate!,
        time: _selectedTime!,
        briefing: briefing,
      );
      if (mounted) {
        _showBookingSuccessDialog();
        setState(() {
          _selectedDate = null;
          _selectedTime = null;
          _shareBriefing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error booking session: $e')));
      }
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  void _showBookingSuccessDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF1E212B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.accentGreen.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppTheme.accentGreen,
                  size: 48,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Session Requested!',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your session with $_selectedProfessional has been requested.',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(color: Colors.white54, fontSize: 14),
              ),
              if (_shareBriefing) ...[
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.accentLavender.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.insights,
                          color: AppTheme.accentLavender, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Insights shared with therapist',
                        style: GoogleFonts.dmSans(
                          color: AppTheme.accentLavender,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    'Done',
                    style: GoogleFonts.dmSans(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
              // 1. Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Care Hub',
                    style: GoogleFonts.outfit(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF161A23),
                      letterSpacing: -0.5,
                    ),
                  ),
                  PopupMenuButton<String>(
                    color: const Color(0xFF1E212B),
                    elevation: 8,
                    onSelected: (value) async {
                      if (value == 'signout') {
                        await AuthService().signOut();
                      } else if (value == 'help') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const HelpSupportScreen(),
                          ),
                        );
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'help',
                        child: Row(
                          children: [
                            const Icon(
                              Icons.help_outline,
                              color: AppTheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Help & Support',
                              style: GoogleFonts.dmSans(
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(height: 1),
                      PopupMenuItem(
                        value: 'signout',
                        child: Row(
                          children: [
                            const Icon(
                              Icons.logout,
                              color: AppTheme.primary,
                              size: 20,
                            ),
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
                    child: const Icon(
                      Icons.person,
                      color: AppTheme.textDark,
                      size: 24,
                    ),
                  ),
                ],
              ).animate().fadeIn(),

              const SizedBox(height: 24),

              // 2. Emergency / Crisis Mode Banner
              _buildCrisisModeBanner().animate().fadeIn(delay: 100.ms),

              const SizedBox(height: 24),

              // 3. AI Recommendation Card
              _buildAIRecommendationCard().animate().fadeIn(delay: 200.ms),

              const SizedBox(height: 30),

              // 4. Verified Professionals
              Text(
                'Verified Professionals',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDark,
                ),
              ).animate().slideX(),
              const SizedBox(height: 16),
              _buildProfessionalsList().animate().fadeIn(delay: 300.ms),

              const SizedBox(height: 30),

              // 5. Request a session
              Text(
                'Request a session',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 16),
              _buildBookingWidget().animate().fadeIn(delay: 400.ms).slideY(),

              const SizedBox(height: 30),

              // 6. Personal Sessions
              Text(
                'Personal Sessions',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDark,
                ),
              ).animate().slideX(),
              const SizedBox(height: 16),
              _buildPersonalSessionsList().animate().fadeIn(delay: 420.ms),

              const SizedBox(height: 30),

              // 7. Upcoming Events
              Text(
                'Upcoming Events',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDark,
                ),
              ).animate().slideX(),
              const SizedBox(height: 16),
              _buildUpcomingSessionsList().animate().fadeIn(delay: 450.ms),

              const SizedBox(height: 30),

              // 7. Secure Messaging
              Text(
                'Secure Messaging',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 16),
              _buildSecureMessagesList().animate().fadeIn(delay: 500.ms),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // ── Crisis Mode Banner ──────────────────────────────────────

  Widget _buildCrisisModeBanner() {
    return GestureDetector(
      onTap: () {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const CrisisModeScreen()));
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.redAccent.withOpacity(0.18),
              Colors.deepOrange.withOpacity(0.10),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.healing,
                color: Colors.redAccent,
                size: 26,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Crisis Mode',
                    style: GoogleFonts.outfit(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap for guided breathing & instant helpline access.',
                    style: GoogleFonts.dmSans(
                      color: Colors.red[900],
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: Colors.redAccent,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  // ── AI Recommendation Card ──────────────────────────────────

  Widget _buildAIRecommendationCard() {
    if (_isLoadingRecommendation) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1E212B),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: AppTheme.accentLavender,
                strokeWidth: 2,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'Analyzing your data for a recommendation...',
                style: GoogleFonts.dmSans(color: Colors.white54, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    final urgency = _aiRecommendation['urgency'] ?? 'LOW';
    final urgencyColor = urgency == 'HIGH'
        ? Colors.redAccent
        : urgency == 'MEDIUM'
        ? Colors.orangeAccent
        : AppTheme.accentGreen;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E212B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.accentLavender.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome,
                color: AppTheme.accentLavender,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'AI Recommendation',
                style: GoogleFonts.outfit(
                  color: AppTheme.accentLavender,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: _loadAIRecommendation,
                child: const Icon(
                  Icons.refresh,
                  color: AppTheme.accentLavender,
                  size: 16,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: urgencyColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  urgency,
                  style: GoogleFonts.dmSans(
                    color: urgencyColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'We recommend ${_aiRecommendation['professional'] ?? 'Dr. Sarah'}',
            style: GoogleFonts.dmSans(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _aiRecommendation['reason'] ?? '',
            style: GoogleFonts.dmSans(
              color: Colors.white54,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ── Professionals List ──────────────────────────────────────

  Widget _buildProfessionalsList() {
    final professionals = [
      {
        'name': 'Dr. Sarah',
        'specialty': 'CBT Specialist',
        'icon': Icons.psychology,
      },
      {
        'name': 'Mark P.',
        'specialty': 'Anxiety Coach',
        'icon': Icons.self_improvement,
      },
      {
        'name': 'Dr. Jane',
        'specialty': 'Sleep Expert',
        'icon': Icons.nightlight_round,
      },
    ];

    final accentColors = [
      AppTheme.accentGreen,
      AppTheme.accentLavender,
      AppTheme.primary,
    ];

    return SizedBox(
      height: 160,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: professionals.length,
        itemBuilder: (context, index) {
          final isSelected =
              _selectedProfessional == professionals[index]['name'];
          final isRecommended =
              _aiRecommendation['professional'] == professionals[index]['name'];

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedProfessional = professionals[index]['name'] as String;
              });
            },
            child: Container(
              width: 140,
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cardGrey,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? AppTheme.primary
                      : AppTheme.primary.withOpacity(0.25),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      GestureDetector(
                        onTap: () => _showTherapistProfile(
                          context,
                          professionals[index]['name'] as String,
                        ),
                        child: CircleAvatar(
                          radius: 28,
                          backgroundColor: accentColors[index].withOpacity(
                            0.18,
                          ),
                          child: Icon(
                            professionals[index]['icon'] as IconData,
                            color: accentColors[index],
                            size: 28,
                          ),
                        ),
                      ),
                      if (isRecommended)
                        Positioned(
                          right: -4,
                          top: -4,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: AppTheme.accentLavender,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.auto_awesome,
                              color: Colors.white,
                              size: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    professionals[index]['name'] as String,
                    style: GoogleFonts.dmSans(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    professionals[index]['specialty'] as String,
                    style: GoogleFonts.dmSans(
                      color: Colors.white54,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Booking Widget ──────────────────────────────────────────

  Widget _buildBookingWidget() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E212B),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          // Date picker row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _selectedDate != null
                    ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                    : 'Select Date',
                style: GoogleFonts.dmSans(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.calendar_today, color: AppTheme.primary),
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 90)),
                    builder: (context, child) {
                      return Theme(
                        data: ThemeData.dark().copyWith(
                          colorScheme: const ColorScheme.dark(
                            primary: AppTheme.primary,
                            surface: AppTheme.cardWhite,
                            onSurface: Colors.white,
                          ),
                          dialogBackgroundColor: AppTheme.cardWhite,
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (date != null) {
                    setState(() => _selectedDate = date);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Time picker row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _selectedTime != null
                    ? _selectedTime!.format(context)
                    : 'Select Time',
                style: GoogleFonts.dmSans(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.access_time, color: AppTheme.primary),
                onPressed: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                    builder: (context, child) {
                      return Theme(
                        data: ThemeData.dark().copyWith(
                          colorScheme: const ColorScheme.dark(
                            primary: AppTheme.primary,
                            surface: AppTheme.cardWhite,
                            onSurface: Colors.white,
                          ),
                          dialogBackgroundColor: AppTheme.cardWhite,
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (time != null) {
                    setState(() => _selectedTime = time);
                  }
                },
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Pre-session briefing toggle
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.accentLavender.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(Icons.insights,
                    color: AppTheme.accentLavender, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Share recent insights with therapist',
                    style: GoogleFonts.dmSans(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                ),
                Switch(
                  value: _shareBriefing,
                  onChanged: (val) =>
                      setState(() => _shareBriefing = val),
                  activeColor: AppTheme.accentLavender,
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Book button
          ElevatedButton(
            onPressed: _isBooking ? null : _bookSession,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentLavender,
              foregroundColor: Colors.black,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _isBooking
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black,
                    ),
                  )
                : Text(
                    'Request with $_selectedProfessional',
                    style: GoogleFonts.dmSans(fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
    );
  }

  // ── Personal Sessions ─────────────────────────────────────────

  Widget _buildPersonalSessionsList() {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return const SizedBox();

    return StreamBuilder<QuerySnapshot>(
      stream: _personalSessionsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.accentLavender),
          );
        }

        final rawDocs = snapshot.data?.docs ?? [];
        final now = DateTime.now();

        // 1. Filter out rejected AND expired sessions
        var validDocs = rawDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final status = data['status'] as String? ?? 'pending';
          if (status == 'rejected') return false;

          final date = (data['date'] as Timestamp?)?.toDate();
          if (date != null) {
            final timeStr = data['time'] as String? ?? '00:00';
            final parts = timeStr.split(':');
            if (parts.length == 2) {
              final sessionDateTime = DateTime(
                date.year,
                date.month,
                date.day,
                int.tryParse(parts[0]) ?? 0,
                int.tryParse(parts[1]) ?? 0,
              );
              // Active until 1 hour after start
              if (!sessionDateTime.add(const Duration(hours: 1)).isAfter(now)) {
                return false; // Expired / Completed
              }
            }
          }
          return true;
        }).toList();

        // 2. Filter based on the toggle tab
        validDocs = validDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final status = data['status'] as String? ?? 'pending';
          if (_showPendingUserRequests) {
            return status == 'pending';
          } else {
            return status == 'accepted' || status == 'upcoming';
          }
        }).toList();

        // Sort locally by creation time
        validDocs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTime = aData['createdAt'] as Timestamp?;
          final bTime = bData['createdAt'] as Timestamp?;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime);
        });

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Toggle Buttons
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E212B),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(4),
              margin: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => _showPendingUserRequests = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: !_showPendingUserRequests
                              ? AppTheme.accentLavender
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Appointments',
                          style: GoogleFonts.dmSans(
                            color: !_showPendingUserRequests
                                ? Colors.black
                                : Colors.white54,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => _showPendingUserRequests = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _showPendingUserRequests
                              ? AppTheme.accentLavender
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Requests',
                          style: GoogleFonts.dmSans(
                            color: _showPendingUserRequests
                                ? Colors.black
                                : Colors.white54,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (validDocs.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E212B),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  _showPendingUserRequests
                      ? 'No pending requests.'
                      : 'No upcoming appointments.',
                  style: GoogleFonts.dmSans(color: Colors.white54),
                  textAlign: TextAlign.center,
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: validDocs.length,
                itemBuilder: (context, index) {
                  final doc = validDocs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final therapistName =
                      data['professionalName'] as String? ?? 'Therapist';
                  final status = data['status'] as String? ?? 'pending';
                  final date = (data['date'] as Timestamp?)?.toDate();
                  final dateStr = date != null
                      ? '${date.day}/${date.month}/${date.year}'
                      : 'TBA';
                  final timeStr = data['time'] as String? ?? 'TBA';

                  Color statusColor;
                  switch (status.toLowerCase()) {
                    case 'accepted':
                      statusColor = AppTheme.accentGreen;
                      break;
                    case 'rejected':
                      statusColor = Colors.redAccent;
                      break;
                    default:
                      statusColor = Colors.orangeAccent;
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
                        CircleAvatar(
                          backgroundColor: AppTheme.accentLavender.withOpacity(
                            0.2,
                          ),
                          child: const Icon(
                            Icons.person,
                            color: AppTheme.accentLavender,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Session with $therapistName',
                                style: GoogleFonts.dmSans(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '$dateStr at $timeStr',
                                style: GoogleFonts.dmSans(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                status.toUpperCase(),
                                style: GoogleFonts.dmSans(
                                  color: statusColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (status.toLowerCase() == 'accepted') ...[
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ProfessionalChatScreen(
                                        professionalName: therapistName,
                                        professionalIcon: Icons.psychology,
                                        accentColor: AppTheme.accentLavender,
                                      ),
                                    ),
                                  );
                                },
                                child: const Icon(
                                  Icons.message,
                                  color: AppTheme.accentLavender,
                                  size: 20,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  // ── Upcoming Sessions & Seminars ────────────────────────────

  Widget _buildUpcomingSessionsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _upcomingSessionsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E212B),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: CircularProgressIndicator(
                color: AppTheme.accentLavender,
                strokeWidth: 2,
              ),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        // Filter to only show future sessions
        final now = DateTime.now();
        final upcoming = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final date = (data['date'] as Timestamp?)?.toDate();
          if (date == null) return true; // show if no date set
          return date.isAfter(now.subtract(const Duration(days: 1)));
        }).toList();

        if (upcoming.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1E212B),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Icon(Icons.event_busy, color: Colors.white12, size: 40),
                const SizedBox(height: 12),
                Text(
                  'No upcoming sessions right now',
                  style: GoogleFonts.dmSans(
                    color: Colors.white30,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        final currentUid = FirebaseAuth.instance.currentUser?.uid;

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: upcoming.length,
          itemBuilder: (context, index) {
            final doc = upcoming[index];
            final data = doc.data() as Map<String, dynamic>;
            final title = data['title'] as String? ?? 'Session';
            final type = data['type'] as String? ?? 'Seminar';
            final rawDescription = data['description'] as String? ?? '';
            final description = rawDescription.isEmpty
                ? 'To Be Announced'
                : rawDescription;
            final therapistName =
                data['therapistName'] as String? ?? 'Therapist';
            final rawVenue = data['venue'] as String? ?? '';
            final venue = rawVenue.isEmpty ? 'TBA' : rawVenue;
            final date = (data['date'] as Timestamp?)?.toDate();
            final dateStr = date != null
                ? '${date.day}/${date.month}/${date.year}'
                : 'TBA';
            final rawTime = data['time'] as String? ?? '';
            final time = rawTime.isEmpty ? 'TBA' : rawTime;
            final maxCapacity = data['maxCapacity'] as int? ?? 0;
            final interestedUsers =
                (data['interestedUsers'] as List<dynamic>?) ?? [];
            final isInterested =
                currentUid != null && interestedUsers.contains(currentUid);

            Color typeColor;
            IconData typeIcon;
            switch (type.toLowerCase()) {
              case 'group session':
                typeColor = AppTheme.accentGreen;
                typeIcon = Icons.groups;
                break;
              case 'workshop':
                typeColor = AppTheme.primary;
                typeIcon = Icons.construction;
                break;
              case 'webinar':
                typeColor = const Color(0xFFFFB347);
                typeIcon = Icons.videocam;
                break;
              default:
                typeColor = AppTheme.accentLavender;
                typeIcon = Icons.campaign;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E212B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: typeColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(typeIcon, color: typeColor, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: GoogleFonts.dmSans(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: typeColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    type.toUpperCase(),
                                    style: GoogleFonts.dmSans(
                                      color: typeColor,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () => _showTherapistProfile(
                                    context,
                                    therapistName,
                                  ),
                                  child: Text(
                                    'by $therapistName',
                                    style: GoogleFonts.dmSans(
                                      color: Colors.white38,
                                      fontSize: 11,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),
                  Text(
                    description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      color: description == 'To Be Announced'
                          ? Colors.white30
                          : Colors.white54,
                      fontStyle: description == 'To Be Announced'
                          ? FontStyle.italic
                          : FontStyle.normal,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Info chips
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      _buildInfoChip(Icons.calendar_today, dateStr),
                      _buildInfoChip(Icons.access_time, time),
                      if (venue == 'TBA')
                        _buildInfoChip(Icons.location_on_outlined, venue)
                      else
                        GestureDetector(
                          onTap: () async {
                            final uri = Uri.parse(
                              'https://maps.google.com/?q=${Uri.encodeComponent(venue)}',
                            );
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri);
                            }
                          },
                          child: _buildInfoChip(
                            Icons.location_on_outlined,
                            venue,
                            isLink: true,
                          ),
                        ),
                      if (maxCapacity > 0)
                        _buildInfoChip(
                          Icons.people_outline,
                          'Max $maxCapacity',
                        ),
                      _buildInfoChip(
                        Icons.favorite,
                        '${interestedUsers.length} interested',
                        colorOverride: interestedUsers.length > 5
                            ? AppTheme.accentLavender
                            : null,
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Show Interest button
                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: ElevatedButton.icon(
                      onPressed: currentUid == null
                          ? null
                          : () async {
                              final docRef = FirebaseFirestore.instance
                                  .collection('therapist_sessions')
                                  .doc(doc.id);
                              if (isInterested) {
                                await docRef.update({
                                  'interestedUsers': FieldValue.arrayRemove([
                                    currentUid,
                                  ]),
                                });
                              } else {
                                await docRef.update({
                                  'interestedUsers': FieldValue.arrayUnion([
                                    currentUid,
                                  ]),
                                });
                              }
                            },
                      icon: Icon(
                        isInterested ? Icons.favorite : Icons.favorite_border,
                        size: 16,
                      ),
                      label: Text(
                        isInterested ? 'Interested' : 'Show Interest',
                        style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isInterested
                            ? AppTheme.accentLavender
                            : AppTheme.accentLavender.withOpacity(0.15),
                        foregroundColor: isInterested
                            ? Colors.white
                            : AppTheme.accentLavender,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInfoChip(
    IconData icon,
    String text, {
    bool isLink = false,
    Color? colorOverride,
  }) {
    final color =
        colorOverride ?? (isLink ? AppTheme.accentLavender : Colors.white54);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: isLink ? color : Colors.white38, size: 13),
        const SizedBox(width: 4),
        Text(
          text,
          style: GoogleFonts.dmSans(
            color: color,
            fontSize: 11,
            decoration: isLink ? TextDecoration.underline : null,
          ),
        ),
      ],
    );
  }

  void _showTherapistProfile(BuildContext context, String therapistName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E212B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          height: 400,
          child: FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('therapist_profiles')
                .doc(therapistName)
                .get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.accentLavender,
                  ),
                );
              }

            final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
            final email = data['email'] as String? ?? 'Contact via CareHub';
            final specialty =
                data['specialty'] as String? ?? 'Verified Therapist';
            final bio = data['bio'] as String? ?? 'No biography available.';

            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(
                  24.0,
                ).copyWith(bottom: MediaQuery.of(context).viewInsets.bottom + 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: AppTheme.accentLavender.withOpacity(
                          0.2,
                        ),
                        child: Icon(
                          Icons.medical_services,
                          color: AppTheme.accentLavender,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              therapistName,
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              specialty,
                              style: GoogleFonts.dmSans(
                                color: AppTheme.accentLavender,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Icon(
                        Icons.email_outlined,
                        color: Colors.white38,
                        size: 18,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          email,
                          style: GoogleFonts.dmSans(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(color: Colors.white.withOpacity(0.08)),
                  const SizedBox(height: 16),
                  Text(
                    'About',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    bio,
                    style: GoogleFonts.dmSans(
                      color: Colors.white54,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
              ),
            );
          },
        ),
      );
    },
  );
  }

  // ── Secure Messaging List ───────────────────────────────────

  Widget _buildSecureMessagesList() {
    final chats = [
      {
        'name': 'Dr. Sarah',
        'specialty': 'CBT Specialist',
        'icon': Icons.psychology,
        'color': AppTheme.accentGreen,
      },
      {
        'name': 'Mark P.',
        'specialty': 'Anxiety Coach',
        'icon': Icons.self_improvement,
        'color': AppTheme.accentLavender,
      },
      {
        'name': 'Dr. Jane',
        'specialty': 'Sleep Expert',
        'icon': Icons.nightlight_round,
        'color': AppTheme.primary,
      },
    ];

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: chats.length,
      itemBuilder: (context, index) {
        final chat = chats[index];
        return GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ProfessionalChatScreen(
                  professionalName: chat['name'] as String,
                  professionalIcon: chat['icon'] as IconData,
                  accentColor: chat['color'] as Color,
                ),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E212B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: (chat['color'] as Color).withOpacity(0.15),
                  child: Icon(
                    chat['icon'] as IconData,
                    color: chat['color'] as Color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        chat['name'] as String,
                        style: GoogleFonts.dmSans(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap to start a secure conversation',
                        style: GoogleFonts.dmSans(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppTheme.accentGreen.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock,
                    color: AppTheme.accentGreen,
                    size: 14,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, color: Colors.white54),
              ],
            ),
          ),
        );
      },
    );
  }
}
