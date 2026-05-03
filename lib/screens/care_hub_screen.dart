import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';

class CareHubScreen extends StatelessWidget {
  const CareHubScreen({super.key});

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

              const SizedBox(height: 30),

              // 2. Verified Professionals
              Text(
                'Verified Professionals',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDark,
                ),
              ).animate().slideX(),
              const SizedBox(height: 16),
              _buildProfessionalsList().animate().fadeIn(delay: 200.ms),

              const SizedBox(height: 30),

              // 3. Book Session Calendar Widget
              Text(
                'Book a Session',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 16),
              _buildCalendarWidget().animate().fadeIn(delay: 400.ms).slideY(),

              const SizedBox(height: 30),

              // 4. Secure Messaging
              Text(
                'Secure Messaging',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 16),
              _buildSecureMessagesList().animate().fadeIn(delay: 600.ms),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfessionalsList() {
    return SizedBox(
      height: 160,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        itemBuilder: (context, index) {
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

          final accentOptions = [
            {
              'bg': AppTheme.accentGreen.withOpacity(0.18),
              'icon': AppTheme.accentGreen,
            },
            {
              'bg': AppTheme.accentLavender.withOpacity(0.18),
              'icon': AppTheme.accentLavender,
            },
            {
              'bg': AppTheme.primary.withOpacity(0.18),
              'icon': AppTheme.primary,
            },
          ];

          return Container(
            width: 140,
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardGrey,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.primary.withOpacity(0.25)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: accentOptions[index]['bg'] as Color,
                  child: Icon(
                    professionals[index]['icon'] as IconData,
                    color: accentOptions[index]['icon'] as Color,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  professionals[index]['name'] as String,
                  style: GoogleFonts.dmSans(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
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
          );
        },
      ),
    );
  }

  Widget _buildCalendarWidget() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E212B),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'May 2026',
                style: GoogleFonts.dmSans(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Row(
                children: const [
                  Icon(Icons.chevron_left, color: Colors.white54),
                  SizedBox(width: 16),
                  Icon(Icons.chevron_right, color: Colors.white),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((day) {
              return Text(
                day,
                style: GoogleFonts.dmSans(color: Colors.white54, fontSize: 12),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          // Simplified row for dates
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [11, 12, 13, 14, 15, 16, 17].map((date) {
              bool isSelected = date == 14;
              return Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primary : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    date.toString(),
                    style: GoogleFonts.dmSans(
                      color: isSelected ? Colors.black : Colors.white,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentLavender,
              foregroundColor: Colors.black,
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Book Selected Slot',
              style: GoogleFonts.dmSans(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecureMessagesList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 2,
      itemBuilder: (context, index) {
        final messages = [
          {
            'name': 'Dr. Sarah (Therapist)',
            'text': 'Looking forward to our next session.',
          },
          {'name': 'Lumora Support', 'text': 'Your secure channel is active.'},
        ];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E212B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Row(
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFF2A2E3B),
                child: Icon(Icons.lock, color: AppTheme.accentGreen, size: 16),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      messages[index]['name'] as String,
                      style: GoogleFonts.dmSans(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      messages[index]['text'] as String,
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
        );
      },
    );
  }
}
