import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleSignup() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        await AuthService().signUpWithEmailPassword(
          _emailController.text.trim(),
          _passwordController.text,
          _nameController.text.trim(),
        );
        // Just pop the signup screen to return to the Login screen
        if (mounted) {
          AppTheme.showCustomSnackBar(context, 'Account created! Please log in.', isSuccess: true);
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          AppTheme.showCustomSnackBar(context, e.toString(), isError: true);
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your email';
    }
    // Simple email regex validation
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a password';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    final symbolRegex = RegExp(r'[!@#\$&*~`%^()_\-+={\[}\]|\\:;"<,>.?/]');
    if (!symbolRegex.hasMatch(value)) {
      return 'Password must contain at least one symbol';
    }
    return null;
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
              Color(0xFFE8F9FA), // Subtle cyan tint
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
                    // App Name
                    Text(
                      'LUMORA',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textDark,
                        letterSpacing: 8.0,
                      ),
                    ),
                    const SizedBox(height: 48),

                    // Elegant Card for Form
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
                            'Create your account',
                            style: GoogleFonts.dmSans(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textDark,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Join 10,000+ others finding their daily balance.',
                            style: GoogleFonts.dmSans(
                              fontSize: 15,
                              color: AppTheme.textMedium,
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Form Fields
                          _buildInputLabel('Full Name'),
                          _buildTextField(
                            controller: _nameController,
                            hintText: 'Eleanor Shellstrop',
                            icon: Icons.person_outline,
                            validator: (value) =>
                                value == null || value.isEmpty ? 'Please enter your name' : null,
                          ),
                          const SizedBox(height: 24),

                          _buildInputLabel('Email Address'),
                          _buildTextField(
                            controller: _emailController,
                            hintText: 'name@example.com',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            validator: _validateEmail,
                          ),
                          const SizedBox(height: 24),

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
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            validator: _validatePassword,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Must be at least 8 characters with a symbol.',
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              color: AppTheme.textLight,
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Privacy Notice Card
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8F9FA),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.security, color: Color(0xFF00E5FF), size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Your privacy is our priority. Your data is encrypted and never shared. By joining, you agree to our supportive community guidelines.',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 13,
                                      color: AppTheme.textMedium,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 40),

                          // Create Account Button
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _handleSignup,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00E5FF),
                                foregroundColor: Colors.black,
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
                                      color: Colors.black,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Create Account',
                                        style: GoogleFonts.dmSans(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.arrow_forward, size: 20),
                                    ],
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Login Link
                    Center(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.of(context).pop();
                        },
                        child: RichText(
                          text: TextSpan(
                            text: 'Already have an account? ',
                            style: GoogleFonts.dmSans(
                              fontSize: 15,
                              color: AppTheme.textMedium,
                            ),
                            children: [
                              TextSpan(
                                text: 'Log in',
                                style: GoogleFonts.dmSans(
                                  fontSize: 15,
                                  color: AppTheme.textDark,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),

                    // Footer Links
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildFooterLink('PRIVACY POLICY'),
                        _buildFooterLink('TERMS OF SERVICE'),
                        _buildFooterLink('SUPPORT'),
                      ],
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
        fillColor: const Color(0xFFF8F9FA), // Softer, cooler off-white for contrast inside the white card
        contentPadding: const EdgeInsets.symmetric(vertical: 18.0),
        errorStyle: GoogleFonts.dmSans(
          color: Colors.red[400],
        ),
      ),
    );
  }

  Widget _buildFooterLink(String text) {
    return Text(
      text,
      style: GoogleFonts.dmSans(
        fontSize: 11,
        color: AppTheme.textMedium,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
    );
  }
}
