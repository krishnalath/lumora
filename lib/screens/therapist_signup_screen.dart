import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';

class TherapistSignupScreen extends StatefulWidget {
  const TherapistSignupScreen({super.key});

  @override
  State<TherapistSignupScreen> createState() => _TherapistSignupScreenState();
}

class _TherapistSignupScreenState extends State<TherapistSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _specialtyController = TextEditingController();
  final _phoneController = TextEditingController();
  
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _specialtyController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim().toLowerCase();
      final name = _nameController.text.trim();

      // 1. Check if name already exists in therapist_profiles
      final existingDoc = await FirebaseFirestore.instance
          .collection('therapist_profiles')
          .doc(name)
          .get();

      if (existingDoc.exists) {
        throw Exception('A therapist profile with this name already exists. Please use a different name or login.');
      }

      // 2. Set role to SharedPreferences BEFORE authenticating
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_role', 'therapist');
      await prefs.setString('therapist_name', name);

      // 3. Create Firebase Auth User
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: email,
        password: _passwordController.text,
      );

      // 4. Create Therapist Profile in Firestore
      await FirebaseFirestore.instance
          .collection('therapist_profiles')
          .doc(name)
          .set({
        'name': name,
        'email': email,
        'specialty': _specialtyController.text.trim(),
        'phone': _phoneController.text.trim(),
        'bio': '',
        'isApproved': true, // User requested to allow them to login for now
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 5. Navigate to Dashboard (AuthWrapper will handle it based on stream, but we pop until root)
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_role');
      
      if (mounted) {
        AppTheme.showCustomSnackBar(context, e.toString(), isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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
              Color(0xFFF0ECFA),
              Color(0xFFF6F5F2),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'LUMORA',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textDark,
                        letterSpacing: 8.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.accentLavender.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'THERAPIST ONBOARDING',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.accentLavender,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),

                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.textDark.withOpacity(0.04),
                            blurRadius: 24,
                            spreadRadius: 0,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Create Account',
                            style: GoogleFonts.dmSans(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textDark,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Join Lumora to support mental well-being.',
                            style: GoogleFonts.dmSans(
                              fontSize: 15,
                              color: AppTheme.textMedium,
                            ),
                          ),
                          const SizedBox(height: 32),

                          _buildInputLabel('Full Name'),
                          _buildTextField(
                            controller: _nameController,
                            hintText: 'Dr. John Doe',
                            icon: Icons.person_outline,
                            validator: (v) => v!.isEmpty ? 'Enter your name' : null,
                          ),
                          const SizedBox(height: 20),

                          _buildInputLabel('Email Address'),
                          _buildTextField(
                            controller: _emailController,
                            hintText: 'name@example.com',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) => v!.isEmpty ? 'Enter your email' : null,
                          ),
                          const SizedBox(height: 20),

                          _buildInputLabel('Password'),
                          _buildTextField(
                            controller: _passwordController,
                            hintText: '••••••••••••',
                            icon: Icons.lock_outline,
                            obscureText: _obscurePassword,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                color: AppTheme.textMedium,
                                size: 20,
                              ),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                            validator: (v) => v!.length < 8 ? 'Min 8 characters' : null,
                          ),
                          const SizedBox(height: 20),
                          
                          _buildInputLabel('Specialty'),
                          _buildTextField(
                            controller: _specialtyController,
                            hintText: 'e.g. CBT, Sleep Expert',
                            icon: Icons.psychology_outlined,
                            validator: (v) => v!.isEmpty ? 'Enter your specialty' : null,
                          ),
                          const SizedBox(height: 20),
                          
                          _buildInputLabel('Phone Number'),
                          _buildTextField(
                            controller: _phoneController,
                            hintText: '+1 234 567 890',
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                          ),
                          
                          const SizedBox(height: 40),

                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleSignup,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.accentLavender,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                              ),
                              child: _isLoading 
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    'Create Account',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    TextButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back, size: 18),
                      label: Text(
                        'Back to login',
                        style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.textMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppTheme.textDark,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      style: GoogleFonts.dmSans(
        fontSize: 15,
        color: AppTheme.textDark,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: GoogleFonts.dmSans(
          color: AppTheme.textLight.withOpacity(0.5),
        ),
        prefixIcon: Icon(icon, color: AppTheme.textMedium, size: 22),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: const Color(0xFFF8F9FA),
        contentPadding: const EdgeInsets.symmetric(vertical: 18.0),
        errorStyle: GoogleFonts.dmSans(color: Colors.red[400]),
      ),
    );
  }
}
