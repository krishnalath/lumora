import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import 'therapist_chat_screen.dart';

/// Main dashboard for logged-in therapists.
/// Contains 4 tabs: Appointments, Messages, Insights, Settings.
class TherapistDashboardScreen extends StatefulWidget {
  const TherapistDashboardScreen({super.key});

  @override
  State<TherapistDashboardScreen> createState() =>
      _TherapistDashboardScreenState();
}

class _TherapistDashboardScreenState extends State<TherapistDashboardScreen> {
  int _currentTab = 0;
  String _therapistName = '';
  final _db = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadTherapistName();
  }

  Future<void> _loadTherapistName() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _therapistName = prefs.getString('therapist_name') ?? 'Doctor';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0F14),
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome back,',
                        style: GoogleFonts.dmSans(
                          color: Colors.white54,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        _therapistName,
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.accentLavender.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.verified,
                            color: AppTheme.accentLavender, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          'THERAPIST',
                          style: GoogleFonts.dmSans(
                            color: AppTheme.accentLavender,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(),

            const SizedBox(height: 20),

            // ── Tab Bar ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _buildTab(0, Icons.calendar_today, 'Appointments'),
                  const SizedBox(width: 8),
                  _buildTab(1, Icons.chat_bubble_outline, 'Messages'),
                  const SizedBox(width: 8),
                  _buildTab(2, Icons.insights, 'Insights'),
                  const SizedBox(width: 8),
                  _buildTab(3, Icons.settings, 'Settings'),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Tab Content ──
            Expanded(
              child: IndexedStack(
                index: _currentTab,
                children: [
                  _buildAppointmentsTab(),
                  _buildMessagesTab(),
                  _buildInsightsTab(),
                  _buildSettingsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(int index, IconData icon, String label) {
    final isSelected = _currentTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.accentLavender.withOpacity(0.15)
                : const Color(0xFF1E212B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? AppTheme.accentLavender.withOpacity(0.3)
                  : Colors.transparent,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: isSelected ? AppTheme.accentLavender : Colors.white38,
                  size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.dmSans(
                  color:
                      isSelected ? AppTheme.accentLavender : Colors.white38,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── TAB 1: APPOINTMENTS ─────────────────────────────────────

  Widget _buildAppointmentsTab() {
    if (_therapistName.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.accentLavender));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('care_sessions')
          .where('professionalName', isEqualTo: _therapistName)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.accentLavender),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.event_available,
                    color: Colors.white12, size: 64),
                const SizedBox(height: 16),
                Text(
                  'No appointments yet',
                  style: GoogleFonts.dmSans(
                      color: Colors.white30, fontSize: 16),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final date = (data['date'] as Timestamp?)?.toDate();
            final time = data['time'] as String? ?? '';
            final status = data['status'] as String? ?? 'upcoming';
            final hasBriefing =
                data['briefing'] != null && (data['briefing'] as String).isNotEmpty;
            final briefing = data['briefing'] as String?;
            final sessionTitle = data['patientName'] as String? ?? 'Patient Session';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E212B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppTheme.primary.withOpacity(0.15),
                        child: const Icon(Icons.person,
                            color: AppTheme.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sessionTitle,
                              style: GoogleFonts.dmSans(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              date != null
                                  ? '${date.day}/${date.month}/${date.year} at $time'
                                  : 'Date TBD',
                              style: GoogleFonts.dmSans(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: status == 'upcoming'
                              ? AppTheme.accentGreen.withOpacity(0.15)
                              : Colors.grey.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: GoogleFonts.dmSans(
                            color: status == 'upcoming'
                                ? AppTheme.accentGreen
                                : Colors.grey,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (hasBriefing) ...[
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => _showBriefingSheet(briefing!),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.accentLavender.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.insights,
                                color: AppTheme.accentLavender, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              'View Pre-Session Briefing',
                              style: GoogleFonts.dmSans(
                                color: AppTheme.accentLavender,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            Icon(Icons.arrow_forward_ios,
                                color: AppTheme.accentLavender, size: 12),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ).animate().fadeIn(delay: Duration(milliseconds: 100 * index));
          },
        );
      },
    );
  }

  void _showBriefingSheet(String briefing) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E212B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.insights,
                      color: AppTheme.accentLavender, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Pre-Session Briefing',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D0F14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      briefing,
                      style: GoogleFonts.sourceCodePro(
                        color: Colors.white70,
                        fontSize: 12,
                        height: 1.6,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentLavender,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text('Close',
                      style:
                          GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── TAB 2: MESSAGES ─────────────────────────────────────────

  Widget _buildMessagesTab() {
    if (_therapistName.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.accentLavender));
    }
    // Find all chat threads where the chatId contains the therapist name
    final safeName =
        _therapistName.replaceAll(' ', '_').replaceAll('.', '');

    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('care_chats').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.accentLavender),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        // Filter chats that belong to this therapist
        final myChats = docs.where((doc) {
          return doc.id.contains(safeName);
        }).toList();

        if (myChats.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.chat_bubble_outline,
                    color: Colors.white12, size: 64),
                const SizedBox(height: 16),
                Text(
                  'No messages yet',
                  style: GoogleFonts.dmSans(
                      color: Colors.white30, fontSize: 16),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: myChats.length,
          itemBuilder: (context, index) {
            final chatDoc = myChats[index];
            final data = chatDoc.data() as Map<String, dynamic>;
            final lastMessage = data['lastMessage'] as String? ?? '';
            final chatId = chatDoc.id;

            // Extract a patient identifier from the chatId
            // Format: {uid}_{therapistSafeName}
            final patientId = chatId.replaceAll('_$safeName', '');
            final shortPatient = data['patientName'] as String? ??
                'Patient ${patientId.substring(0, patientId.length.clamp(0, 6))}';

            return GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TherapistChatScreen(
                      chatId: chatId,
                      patientName: shortPatient,
                      therapistName: _therapistName,
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
                      backgroundColor: AppTheme.primary.withOpacity(0.15),
                      child: const Icon(Icons.person,
                          color: AppTheme.primary, size: 20),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            shortPatient,
                            style: GoogleFonts.dmSans(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            lastMessage.length > 40
                                ? '${lastMessage.substring(0, 40)}...'
                                : lastMessage,
                            style: GoogleFonts.dmSans(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.white54),
                  ],
                ),
              ),
            ).animate().fadeIn(delay: Duration(milliseconds: 100 * index));
          },
        );
      },
    );
  }

  // ── TAB 3: INSIGHTS ─────────────────────────────────────────

  Widget _buildInsightsTab() {
    if (_therapistName.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.accentLavender));
    }
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('care_sessions')
          .where('professionalName', isEqualTo: _therapistName)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.accentLavender));
        }
        final docs = snapshot.data?.docs ?? [];
        final totalSessions = docs.length;
        final upcomingSessions =
            docs.where((d) => (d.data() as Map)['status'] == 'upcoming').length;
        final withBriefing = docs
            .where((d) =>
                (d.data() as Map)['briefing'] != null &&
                ((d.data() as Map)['briefing'] as String).isNotEmpty)
            .length;

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Practice Overview',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ).animate().fadeIn(),
              const SizedBox(height: 20),

              // Stats row
              Row(
                children: [
                  _buildStatCard(
                    'Total\nSessions',
                    '$totalSessions',
                    AppTheme.primary,
                  ),
                  const SizedBox(width: 12),
                  _buildStatCard(
                    'Upcoming',
                    '$upcomingSessions',
                    AppTheme.accentGreen,
                  ),
                  const SizedBox(width: 12),
                  _buildStatCard(
                    'With\nBriefing',
                    '$withBriefing',
                    AppTheme.accentLavender,
                  ),
                ],
              ).animate().fadeIn(delay: 200.ms),

              const SizedBox(height: 30),

              // Tip card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E212B),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppTheme.accentLavender.withOpacity(0.15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lightbulb_outline,
                            color: AppTheme.accentLavender, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Practice Tip',
                          style: GoogleFonts.outfit(
                            color: AppTheme.accentLavender,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Patients who share pre-session briefings tend to have more productive sessions. Encourage your patients to enable the "Share insights" toggle when booking.',
                      style: GoogleFonts.dmSans(
                        color: Colors.white54,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 400.ms),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.outfit(
                color: color,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                color: Colors.white54,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── TAB 4: SETTINGS ─────────────────────────────────────────

  Widget _buildSettingsTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1E212B),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppTheme.accentLavender.withOpacity(0.2),
                  child: Icon(Icons.medical_services,
                      color: AppTheme.accentLavender, size: 28),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _therapistName,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Verified Therapist • Lumora',
                      style: GoogleFonts.dmSans(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ).animate().fadeIn(),

          const SizedBox(height: 30),

          // Sign out button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('user_role');
                await prefs.remove('therapist_name');
                await AuthService().signOut();
              },
              icon: const Icon(Icons.logout),
              label: Text('Sign Out',
                  style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent.withOpacity(0.15),
                foregroundColor: Colors.redAccent,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ).animate().fadeIn(delay: 200.ms),
        ],
      ),
    );
  }
}
