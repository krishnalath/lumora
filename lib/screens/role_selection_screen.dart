import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'therapist_login_screen.dart';

/// First screen the user sees when not logged in.
/// Lets them choose between User mode and Therapist mode.
class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF6F5F2),
              Color(0xFFE8F9FA),
              Color(0xFFF6F5F2),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App Name
                  Text(
                    'LUMORA',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textDark,
                      letterSpacing: 8.0,
                    ),
                  ).animate().fadeIn(duration: 600.ms),

                  const SizedBox(height: 12),

                  Text(
                    'Your mental wellness companion',
                    style: GoogleFonts.dmSans(
                      fontSize: 15,
                      color: AppTheme.textMedium,
                    ),
                  ).animate().fadeIn(delay: 200.ms),

                  const SizedBox(height: 60),

                  Text(
                    'Continue as',
                    style: GoogleFonts.dmSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark,
                    ),
                  ).animate().fadeIn(delay: 300.ms),

                  const SizedBox(height: 24),

                  // ── User Card ──
                  _RoleCard(
                    icon: Icons.favorite_outline,
                    title: "I'm looking for support",
                    subtitle: 'Track your wellness, journal, and connect with professionals.',
                    accentColor: AppTheme.primary,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                  ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.15),

                  const SizedBox(height: 20),

                  // ── Therapist Card ──
                  _RoleCard(
                    icon: Icons.medical_services_outlined,
                    title: "I'm a therapist",
                    subtitle: 'Access your patient dashboard, appointments, and messages.',
                    accentColor: AppTheme.accentLavender,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const TherapistLoginScreen()),
                      );
                    },
                  ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.15),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppTheme.textDark.withOpacity(0.04),
              blurRadius: 24,
              spreadRadius: 0,
              offset: const Offset(0, 12),
            ),
          ],
          border: Border.all(
            color: accentColor.withOpacity(0.2),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: accentColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.dmSans(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      color: AppTheme.textMedium,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: accentColor, size: 16),
          ],
        ),
      ),
    );
  }
}
