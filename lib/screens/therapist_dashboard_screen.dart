import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import 'therapist_chat_screen.dart';
import 'map_picker_screen.dart';

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
  bool _showPendingTherapistRequests = false;
  final _db = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadTherapistName();
  }

  Future<void> _loadTherapistName() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      String rawName = prefs.getString('therapist_name') ?? 'Therapist';

      // Fix for the login race condition: if the name is empty, extract it from the authenticated email!
      if (rawName == 'Therapist') {
        final email = FirebaseAuth.instance.currentUser?.email;
        if (email != null) {
          final prefix = email.split('@')[0];
          rawName = prefix;
        }
      }

      // Auto-correct any casing issues from previous logins without requiring logout
      if (rawName.toLowerCase().contains('sarah')) {
        rawName = 'Dr. Sarah';
      } else if (rawName.toLowerCase().contains('jane')) {
        rawName = 'Dr. Jane';
      } else if (rawName.toLowerCase().contains('mark')) {
        rawName = 'Mark P.';
      } else if (!rawName.startsWith('Dr.') && rawName != 'Therapist') {
        final capitalized = rawName.isNotEmpty
            ? '${rawName[0].toUpperCase()}${rawName.substring(1)}'
            : rawName;
        rawName = 'Dr. $capitalized';
      }

      _therapistName = rawName;
    });
    // Fire the profile load AFTER we set the name
    _loadTherapistProfile();
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.accentLavender.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.verified,
                          color: AppTheme.accentLavender,
                          size: 14,
                        ),
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

            // ── Tab Bar (Grid) ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Row(
                    children: [
                      _buildTab(0, Icons.calendar_today, 'Appointments'),
                      const SizedBox(width: 10),
                      _buildTab(1, Icons.chat_bubble_outline, 'Messages'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _buildTab(2, Icons.event_note, 'Sessions'),
                      const SizedBox(width: 10),
                      _buildTab(3, Icons.settings, 'Settings'),
                    ],
                  ),
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
                  _buildSessionsTab(),
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
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.accentLavender.withOpacity(0.15)
                : const Color(0xFF1E212B),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? AppTheme.accentLavender.withOpacity(0.3)
                  : Colors.transparent,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? AppTheme.accentLavender : Colors.white38,
                size: 22,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: GoogleFonts.dmSans(
                  color: isSelected ? AppTheme.accentLavender : Colors.white38,
                  fontSize: 12,
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
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.accentLavender),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('care_sessions')
          .where('professionalName', isEqualTo: _therapistName)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }
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
          if (_showPendingTherapistRequests) {
            return status == 'pending';
          } else {
            return status == 'accepted' || status == 'upcoming';
          }
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Toggle Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E212B),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(
                          () => _showPendingTherapistRequests = false,
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: !_showPendingTherapistRequests
                                ? AppTheme.accentLavender
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Upcoming Appointments',
                            style: GoogleFonts.dmSans(
                              color: !_showPendingTherapistRequests
                                  ? Colors.black
                                  : Colors.white54,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(
                          () => _showPendingTherapistRequests = true,
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _showPendingTherapistRequests
                                ? AppTheme.accentLavender
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Pending Requests',
                            style: GoogleFonts.dmSans(
                              color: _showPendingTherapistRequests
                                  ? Colors.black
                                  : Colors.white54,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (validDocs.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.event_available,
                        color: Colors.white12,
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _showPendingTherapistRequests
                            ? 'No pending requests'
                            : 'No upcoming appointments',
                        style: GoogleFonts.dmSans(
                          color: Colors.white30,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: validDocs.length,
                  itemBuilder: (context, index) {
                    final doc = validDocs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final date = (data['date'] as Timestamp?)?.toDate();
                    final time = data['time'] as String? ?? '';
                    final status = data['status'] as String? ?? 'pending';
                    final hasBriefing =
                        data['briefing'] != null &&
                        (data['briefing'] as String).isNotEmpty;
                    final briefing = data['briefing'] as String?;
                    final sessionTitle =
                        data['patientName'] as String? ?? 'Patient Session';
                    final patientUid = data['uid'] as String? ?? '';

                    Color statusColor;
                    switch (status.toLowerCase()) {
                      case 'accepted':
                        statusColor = AppTheme.accentGreen;
                        break;
                      case 'rejected':
                        statusColor = Colors.redAccent;
                        break;
                      case 'upcoming':
                        statusColor = AppTheme.accentGreen;
                        break; // Legacy support
                      default:
                        statusColor = Colors.orangeAccent;
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E212B),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.05),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: AppTheme.primary.withOpacity(
                                  0.15,
                                ),
                                child: const Icon(
                                  Icons.person,
                                  color: AppTheme.primary,
                                  size: 20,
                                ),
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
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
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
                            ],
                          ),
                          if (status == 'pending') ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () async {
                                      await doc.reference.update({
                                        'status': 'accepted',
                                      });
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.accentGreen,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    child: Text(
                                      'Accept',
                                      style: GoogleFonts.dmSans(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () async {
                                      await doc.reference.update({
                                        'status': 'rejected',
                                      });
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.redAccent,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    child: Text(
                                      'Reject',
                                      style: GoogleFonts.dmSans(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (status == 'accepted' || status == 'upcoming') ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                if (hasBriefing)
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () =>
                                          _showBriefingSheet(briefing!),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppTheme.accentLavender
                                              .withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.insights,
                                              color: AppTheme.accentLavender,
                                              size: 16,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Briefing',
                                              style: GoogleFonts.dmSans(
                                                color: AppTheme.accentLavender,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                if (hasBriefing) const SizedBox(width: 12),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      final chatId =
                                          '${patientUid}_${_therapistName.replaceAll(' ', '_').replaceAll('.', '')}';
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => TherapistChatScreen(
                                            chatId: chatId,
                                            patientName: sessionTitle,
                                            therapistName: _therapistName,
                                          ),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primary.withOpacity(
                                          0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.message,
                                            color: AppTheme.primary,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Chat',
                                            style: GoogleFonts.dmSans(
                                              color: AppTheme.primary,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ).animate().fadeIn(
                      delay: Duration(milliseconds: 100 * index),
                    );
                  },
                ),
              ),
          ],
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
                  Icon(
                    Icons.insights,
                    color: AppTheme.accentLavender,
                    size: 20,
                  ),
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
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    'Close',
                    style: GoogleFonts.dmSans(fontWeight: FontWeight.bold),
                  ),
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
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.accentLavender),
      );
    }
    // Find all chat threads where the chatId contains the therapist name
    final safeName = _therapistName.replaceAll(' ', '_').replaceAll('.', '');

    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('care_chats').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
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
                const Icon(
                  Icons.chat_bubble_outline,
                  color: Colors.white12,
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  'No messages yet',
                  style: GoogleFonts.dmSans(
                    color: Colors.white30,
                    fontSize: 16,
                  ),
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
            final shortPatient =
                data['patientName'] as String? ??
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
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppTheme.primary.withOpacity(0.15),
                      child: const Icon(
                        Icons.person,
                        color: AppTheme.primary,
                        size: 20,
                      ),
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

  // ── TAB 4: SESSIONS / SEMINARS ──────────────────────────────

  Widget _buildSessionsTab() {
    if (_therapistName.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.accentLavender),
      );
    }

    return Stack(
      children: [
        StreamBuilder<QuerySnapshot>(
          stream: _db
              .collection('therapist_sessions')
              .where('therapistName', isEqualTo: _therapistName)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Error: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                ),
              );
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  color: AppTheme.accentLavender,
                ),
              );
            }

            final docs = snapshot.data?.docs ?? [];

            if (docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.event_note,
                      color: Colors.white12,
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No sessions or seminars yet',
                      style: GoogleFonts.dmSans(
                        color: Colors.white30,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap + to add your first session',
                      style: GoogleFonts.dmSans(
                        color: Colors.white24,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
              ).copyWith(bottom: 80),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data() as Map<String, dynamic>;
                final title = data['title'] as String? ?? 'Untitled Session';
                final type = data['type'] as String? ?? 'Seminar';
                final description = data['description'] as String? ?? '';
                final venue = data['venue'] as String? ?? '';
                final date = (data['date'] as Timestamp?)?.toDate();
                final time = data['time'] as String? ?? '';
                final maxCapacity = data['maxCapacity'] as int? ?? 0;
                final interestedUsers =
                    (data['interestedUsers'] as List<dynamic>?) ?? [];
                final interestedCount = interestedUsers.length;

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
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: typeColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(typeIcon, color: typeColor, size: 20),
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
                              ],
                            ),
                          ),
                          // Edit & Delete
                          IconButton(
                            icon: Icon(
                              Icons.edit_outlined,
                              color: AppTheme.accentLavender,
                              size: 18,
                            ),
                            onPressed: () => _showSessionForm(existingDoc: doc),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: Icon(
                              Icons.delete_outline,
                              color: Colors.redAccent.withOpacity(0.7),
                              size: 18,
                            ),
                            onPressed: () => _confirmDeleteSession(doc.id),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmSans(
                            color: Colors.white54,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      // Date, Time, Venue row
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          if (date != null)
                            _buildSessionChip(
                              Icons.calendar_today,
                              '${date.day}/${date.month}/${date.year}',
                            ),
                          if (time.isNotEmpty)
                            _buildSessionChip(Icons.access_time, time),
                          if (venue.isNotEmpty)
                            GestureDetector(
                              onTap: () async {
                                final uri = Uri.parse(
                                  'https://maps.google.com/?q=${Uri.encodeComponent(venue)}',
                                );
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri);
                                }
                              },
                              child: _buildSessionChip(
                                Icons.location_on_outlined,
                                venue,
                                isLink: true,
                              ),
                            ),
                          if (maxCapacity > 0)
                            _buildSessionChip(
                              Icons.people_outline,
                              'Max $maxCapacity',
                            ),
                          _buildSessionChip(
                            Icons.favorite,
                            '$interestedCount interested',
                            colorOverride: interestedCount > 5
                                ? AppTheme.accentLavender
                                : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: Duration(milliseconds: 80 * index));
              },
            );
          },
        ),
        // FAB for adding new sessions
        Positioned(
          bottom: 20,
          right: 20,
          child: FloatingActionButton(
            onPressed: () => _showSessionForm(),
            backgroundColor: AppTheme.accentLavender,
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildSessionChip(
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

  void _confirmDeleteSession(String docId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E212B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Session?',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'This will permanently remove this session. Users will no longer see it.',
          style: GoogleFonts.dmSans(color: Colors.white54, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.dmSans(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _db.collection('therapist_sessions').doc(docId).delete();
            },
            child: Text(
              'Delete',
              style: GoogleFonts.dmSans(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSessionForm({DocumentSnapshot? existingDoc}) {
    final isEditing = existingDoc != null;
    final existingData = isEditing
        ? existingDoc.data() as Map<String, dynamic>
        : <String, dynamic>{};

    final titleCtrl = TextEditingController(
      text: existingData['title'] as String? ?? '',
    );
    final descCtrl = TextEditingController(
      text: existingData['description'] as String? ?? '',
    );
    final venueCtrl = TextEditingController(
      text: existingData['venue'] as String? ?? '',
    );
    final capacityCtrl = TextEditingController(
      text: (existingData['maxCapacity'] as int?)?.toString() ?? '',
    );

    String selectedType = existingData['type'] as String? ?? 'Seminar';
    DateTime? sessionDate = existingData['date'] != null
        ? (existingData['date'] as Timestamp).toDate()
        : null;
    TimeOfDay? sessionTime;
    if (existingData['time'] != null &&
        (existingData['time'] as String).isNotEmpty) {
      final parts = (existingData['time'] as String).split(':');
      if (parts.length == 2) {
        sessionTime = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 0,
          minute: int.tryParse(parts[1]) ?? 0,
        );
      }
    }

    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E212B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                24,
                24,
                MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Icon(
                          Icons.event_note,
                          color: AppTheme.accentLavender,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          isEditing ? 'Edit Session' : 'New Session / Seminar',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Title
                    _buildFormField(
                      'Title',
                      titleCtrl,
                      'e.g. Stress Management Workshop',
                    ),
                    const SizedBox(height: 14),

                    // Type dropdown
                    Text(
                      'Type',
                      style: GoogleFonts.dmSans(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D0F14),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.08),
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedType,
                          isExpanded: true,
                          dropdownColor: const Color(0xFF1E212B),
                          style: GoogleFonts.dmSans(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          items:
                              [
                                    'Seminar',
                                    'Group Session',
                                    'Workshop',
                                    'Webinar',
                                  ]
                                  .map(
                                    (t) => DropdownMenuItem(
                                      value: t,
                                      child: Text(t),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setModalState(() => selectedType = val);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Description
                    _buildFormField(
                      'Description',
                      descCtrl,
                      'What is this session about?',
                      maxLines: 3,
                    ),
                    const SizedBox(height: 14),

                    // Date & Time row
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate: sessionDate ?? DateTime.now(),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(
                                  const Duration(days: 365),
                                ),
                                builder: (context, child) {
                                  return Theme(
                                    data: ThemeData.dark().copyWith(
                                      colorScheme: const ColorScheme.dark(
                                        primary: AppTheme.primary,
                                        surface: Color(0xFF1E212B),
                                        onSurface: Colors.white,
                                      ),
                                      dialogBackgroundColor: const Color(0xFF1E212B),
                                    ),
                                    child: child!,
                                  );
                                },
                              );
                              if (picked != null) {
                                setModalState(() => sessionDate = picked);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0D0F14),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.08),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_today,
                                    color: AppTheme.accentLavender,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    sessionDate != null
                                        ? '${sessionDate!.day}/${sessionDate!.month}/${sessionDate!.year}'
                                        : 'Pick Date',
                                    style: GoogleFonts.dmSans(
                                      color: sessionDate != null
                                          ? Colors.white
                                          : Colors.white38,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              final picked = await showTimePicker(
                                context: ctx,
                                initialTime: sessionTime ?? TimeOfDay.now(),
                                builder: (context, child) {
                                  return Theme(
                                    data: ThemeData.dark().copyWith(
                                      colorScheme: const ColorScheme.dark(
                                        primary: AppTheme.primary,
                                        surface: Color(0xFF1E212B),
                                        onSurface: Colors.white,
                                      ),
                                      dialogBackgroundColor: const Color(0xFF1E212B),
                                    ),
                                    child: child!,
                                  );
                                },
                              );
                              if (picked != null) {
                                setModalState(() => sessionTime = picked);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0D0F14),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.08),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.access_time,
                                    color: AppTheme.accentLavender,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    sessionTime != null
                                        ? sessionTime!.format(ctx)
                                        : 'Pick Time',
                                    style: GoogleFonts.dmSans(
                                      color: sessionTime != null
                                          ? Colors.white
                                          : Colors.white38,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Venue
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: _buildFormField(
                            'Venue / Location',
                            venueCtrl,
                            'e.g. Online / Room 201',
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () async {
                            final uri = Uri.parse('https://maps.google.com');
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(
                                uri,
                                mode: LaunchMode.externalApplication,
                              );
                            }
                          },
                          icon: const Icon(
                            Icons.map,
                            color: AppTheme.accentLavender,
                            size: 18,
                          ),
                          label: Text(
                            'Find on Maps',
                            style: GoogleFonts.dmSans(
                              color: AppTheme.accentLavender,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 16,
                            ),
                            backgroundColor: AppTheme.accentLavender
                                .withOpacity(0.1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Max Capacity
                    _buildFormField(
                      'Max Capacity (optional)',
                      capacityCtrl,
                      'e.g. 30',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 24),

                    // Submit
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: isSaving
                            ? null
                            : () async {
                                if (titleCtrl.text.trim().isEmpty ||
                                    sessionDate == null ||
                                    selectedType.isEmpty) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Please fill out the Title, Type, and Date fields.',
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                setModalState(() => isSaving = true);

                                final sessionData = {
                                  'therapistName': _therapistName,
                                  'title': titleCtrl.text.trim(),
                                  'type': selectedType,
                                  'description': descCtrl.text.trim(),
                                  'date': Timestamp.fromDate(
                                    DateTime(
                                      sessionDate!.year,
                                      sessionDate!.month,
                                      sessionDate!.day,
                                    ),
                                  ),
                                  'time': sessionTime != null
                                      ? '${sessionTime!.hour}:${sessionTime!.minute.toString().padLeft(2, '0')}'
                                      : '',
                                  'venue': venueCtrl.text.trim(),
                                  'maxCapacity':
                                      int.tryParse(capacityCtrl.text.trim()) ??
                                      0,
                                  'updatedAt': FieldValue.serverTimestamp(),
                                };

                                try {
                                  if (isEditing) {
                                    await _db
                                        .collection('therapist_sessions')
                                        .doc(existingDoc.id)
                                        .update(sessionData);
                                  } else {
                                    sessionData['createdAt'] =
                                        FieldValue.serverTimestamp();
                                    await _db
                                        .collection('therapist_sessions')
                                        .add(sessionData);
                                  }
                                  if (ctx.mounted) Navigator.pop(ctx);
                                } catch (e) {
                                  setModalState(() => isSaving = false);
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(content: Text('Error: $e')),
                                    );
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentLavender,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: isSaving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                isEditing ? 'Update Session' : 'Create Session',
                                style: GoogleFonts.dmSans(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFormField(
    String label,
    TextEditingController ctrl,
    String hint, {
    int maxLines = 1,
    TextInputType? keyboardType,
    Widget? suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.dmSans(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0D0F14),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: TextField(
            controller: ctrl,
            maxLines: maxLines,
            keyboardType: keyboardType,
            style: GoogleFonts.dmSans(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.dmSans(
                color: Colors.white24,
                fontSize: 14,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              suffixIcon: suffix,
            ),
          ),
        ),
      ],
    );
  }

  // ── TAB 5: SETTINGS ─────────────────────────────────────────

  // Editable profile controllers
  final _specialtyController = TextEditingController();
  final _phoneController = TextEditingController();
  final _bioController = TextEditingController();
  bool _isProfileLoaded = false;
  bool _isSavingProfile = false;
  bool _isEditingProfile = false;

  Future<void> _loadTherapistProfile() async {
    if (_therapistName.isEmpty || _isProfileLoaded) return;
    try {
      final doc = await _db
          .collection('therapist_profiles')
          .doc(_therapistName)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        _specialtyController.text = data['specialty'] as String? ?? '';
        _phoneController.text = data['phone'] as String? ?? '';
        _bioController.text = data['bio'] as String? ?? '';
      }
      if (mounted) setState(() => _isProfileLoaded = true);
    } catch (_) {
      if (mounted) setState(() => _isProfileLoaded = true);
    }
  }

  Future<void> _saveTherapistProfile() async {
    if (_therapistName.isEmpty) return;
    setState(() => _isSavingProfile = true);
    try {
      await _db.collection('therapist_profiles').doc(_therapistName).set({
        'name': _therapistName,
        'specialty': _specialtyController.text.trim(),
        'phone': _phoneController.text.trim(),
        'bio': _bioController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Also update SharedPreferences if name-related changes
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Profile updated successfully!',
              style: GoogleFonts.dmSans(color: Colors.white),
            ),
            backgroundColor: AppTheme.accentGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving profile: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSavingProfile = false;
          _isEditingProfile = false;
        });
      }
    }
  }

  Widget _buildSettingsTab() {
    // Trigger profile load on first view
    if (!_isProfileLoaded && _therapistName.isNotEmpty) {
      _loadTherapistProfile();
    }

    return SingleChildScrollView(
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
                  child: Icon(
                    Icons.medical_services,
                    color: AppTheme.accentLavender,
                    size: 28,
                  ),
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

          const SizedBox(height: 24),

          // Editable fields section header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Professional Details',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (!_isEditingProfile)
                TextButton.icon(
                  onPressed: () => setState(() => _isEditingProfile = true),
                  icon: const Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: AppTheme.accentLavender,
                  ),
                  label: Text(
                    'Edit',
                    style: GoogleFonts.dmSans(
                      color: AppTheme.accentLavender,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ).animate().fadeIn(delay: 100.ms),

          const SizedBox(height: 16),

          // Specialty
          _buildProfileField(
            label: 'Specialty',
            controller: _specialtyController,
            hint: 'e.g. CBT Specialist, Sleep Expert',
            icon: Icons.psychology_outlined,
          ).animate().fadeIn(delay: 150.ms),

          const SizedBox(height: 14),

          // Phone
          _buildProfileField(
            label: 'Phone Number',
            controller: _phoneController,
            hint: 'e.g. +91 98765 43210',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ).animate().fadeIn(delay: 200.ms),

          const SizedBox(height: 14),

          // Bio
          _buildProfileField(
            label: 'Bio',
            controller: _bioController,
            hint: 'A short description about your practice...',
            icon: Icons.description_outlined,
            maxLines: 4,
          ).animate().fadeIn(delay: 250.ms),

          if (_isEditingProfile) ...[
            const SizedBox(height: 20),

            // Save & Cancel buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() => _isEditingProfile = false);
                      _loadTherapistProfile(); // Reset to saved values
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: BorderSide(color: Colors.white.withOpacity(0.1)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.dmSans(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSavingProfile ? null : _saveTherapistProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentLavender,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isSavingProfile
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Save Changes',
                            style: GoogleFonts.dmSans(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ).animate().fadeIn(),
          ],

          const SizedBox(height: 32),

          // Help Section
          Text(
            'Help & Support',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ).animate().fadeIn(delay: 300.ms),
          const SizedBox(height: 16),

          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E212B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.accentLavender.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.help_outline,
                  color: AppTheme.accentLavender,
                  size: 22,
                ),
              ),
              title: Text(
                'Contact LUMORA Developers',
                style: GoogleFonts.dmSans(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              subtitle: Text(
                'Have a query or need assistance? Reach out to our team.',
                style: GoogleFonts.dmSans(color: Colors.white54, fontSize: 13),
              ),
              trailing: const Icon(
                Icons.arrow_forward_ios,
                color: Colors.white38,
                size: 14,
              ),
              onTap: () async {
                final Uri emailUri = Uri(
                  scheme: 'mailto',
                  path: 'support@lumora.care',
                  queryParameters: {
                    'subject': 'Support Request - Therapist Portal',
                  },
                );
                if (await canLaunchUrl(emailUri)) {
                  await launchUrl(emailUri);
                } else {
                  if (mounted) {
                    AppTheme.showCustomSnackBar(
                      context,
                      'Could not open email client',
                      isError: true,
                    );
                  }
                }
              },
            ),
          ).animate().fadeIn(delay: 320.ms),

          const SizedBox(height: 32),

          // Divider
          Divider(color: Colors.white.withOpacity(0.08)),

          const SizedBox(height: 16),

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
              label: Text(
                'Sign Out',
                style: GoogleFonts.dmSans(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent.withOpacity(0.15),
                foregroundColor: Colors.redAccent,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ).animate().fadeIn(delay: 350.ms),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildProfileField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.dmSans(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF1E212B),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: _isEditingProfile
              ? TextField(
                  controller: controller,
                  maxLines: maxLines,
                  keyboardType: keyboardType,
                  style: GoogleFonts.dmSans(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: GoogleFonts.dmSans(
                      color: Colors.white24,
                      fontSize: 14,
                    ),
                    prefixIcon: Icon(
                      icon,
                      color: AppTheme.accentLavender,
                      size: 20,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    crossAxisAlignment: maxLines > 1
                        ? CrossAxisAlignment.start
                        : CrossAxisAlignment.center,
                    children: [
                      Icon(icon, color: Colors.white38, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          controller.text.isEmpty
                              ? 'Not specified'
                              : controller.text,
                          style: GoogleFonts.dmSans(
                            color: controller.text.isEmpty
                                ? Colors.white38
                                : Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}
