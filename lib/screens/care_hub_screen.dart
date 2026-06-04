import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/care_hub_service.dart';
import 'crisis_mode_screen.dart';
import 'professional_chat_screen.dart';

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

  // AI Recommendation state
  bool _isLoadingRecommendation = true;
  Map<String, String> _aiRecommendation = {};

  @override
  void initState() {
    super.initState();
    _loadAIRecommendation();
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
          _selectedProfessional =
              recommendation['professional'] ?? 'Dr. Sarah';
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

    setState(() => _isBooking = true);

    try {
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error booking session: $e')),
        );
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
                child: const Icon(Icons.check_circle_rounded,
                    color: AppTheme.accentGreen, size: 48),
              ),
              const SizedBox(height: 20),
              Text(
                'Session Booked!',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your session with $_selectedProfessional has been scheduled.',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  color: Colors.white54,
                  fontSize: 14,
                ),
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
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text('Done',
                      style:
                          GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
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
                      if (value == 'signout') await AuthService().signOut();
                    },
                    itemBuilder: (context) => [
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
              _buildCrisisModeBanner()
                  .animate()
                  .fadeIn(delay: 100.ms),

              const SizedBox(height: 24),

              // 3. AI Recommendation Card
              _buildAIRecommendationCard()
                  .animate()
                  .fadeIn(delay: 200.ms),

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
              _buildProfessionalsList()
                  .animate()
                  .fadeIn(delay: 300.ms),

              const SizedBox(height: 30),

              // 5. Book a Session
              Text(
                'Book a Session',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 16),
              _buildBookingWidget()
                  .animate()
                  .fadeIn(delay: 400.ms)
                  .slideY(),

              const SizedBox(height: 30),

              // 6. Secure Messaging
              Text(
                'Secure Messaging',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 16),
              _buildSecureMessagesList()
                  .animate()
                  .fadeIn(delay: 500.ms),

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
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CrisisModeScreen()),
        );
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
              child:
                  const Icon(Icons.healing, color: Colors.redAccent, size: 26),
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
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                color: Colors.redAccent, size: 16),
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
                  color: AppTheme.accentLavender, strokeWidth: 2),
            ),
            const SizedBox(width: 16),
            Text(
              'Analyzing your data for a recommendation...',
              style: GoogleFonts.dmSans(color: Colors.white54, fontSize: 13),
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
              Icon(Icons.auto_awesome, color: AppTheme.accentLavender, size: 20),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
      {'name': 'Dr. Sarah', 'specialty': 'CBT Specialist', 'icon': Icons.psychology},
      {'name': 'Mark P.', 'specialty': 'Anxiety Coach', 'icon': Icons.self_improvement},
      {'name': 'Dr. Jane', 'specialty': 'Sleep Expert', 'icon': Icons.nightlight_round},
    ];

    final accentColors = [AppTheme.accentGreen, AppTheme.accentLavender, AppTheme.primary];

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
                _selectedProfessional =
                    professionals[index]['name'] as String;
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
                      CircleAvatar(
                        radius: 28,
                        backgroundColor:
                            accentColors[index].withOpacity(0.18),
                        child: Icon(
                          professionals[index]['icon'] as IconData,
                          color: accentColors[index],
                          size: 28,
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
                            child: const Icon(Icons.auto_awesome,
                                color: Colors.white, size: 12),
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
                icon:
                    const Icon(Icons.calendar_today, color: AppTheme.primary),
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate:
                        DateTime.now().add(const Duration(days: 90)),
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
                icon:
                    const Icon(Icons.access_time, color: AppTheme.primary),
                onPressed: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
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
                    'Book with $_selectedProfessional',
                    style:
                        GoogleFonts.dmSans(fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
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
              border:
                  Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: (chat['color'] as Color).withOpacity(0.15),
                  child: Icon(chat['icon'] as IconData,
                      color: chat['color'] as Color, size: 20),
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
                  child: const Icon(Icons.lock,
                      color: AppTheme.accentGreen, size: 14),
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
