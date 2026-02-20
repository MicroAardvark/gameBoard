// lib/screens/forgot_pass_screen.dart
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'reset_pass_screen.dart';

/// Step 1 of the two-step password reset flow.
///
/// Validates the email address client-side before hitting the API, then
/// navigates to [ResetPasswordScreen] on success so the user can enter
/// the 6-digit code that was emailed to them.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool   _isLoading    = false;
  String _errorMessage = '';

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submitForgotPassword() async {
    final email = _emailController.text.trim();

    // Basic presence check before the regex so the error message is specific.
    if (email.isEmpty) {
      setState(() => _errorMessage = 'Please enter your email address');
      return;
    }

    // Simple format check — the server validates more thoroughly, but this
    // avoids an unnecessary round-trip for clearly invalid input.
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      setState(() => _errorMessage = 'Please enter a valid email address');
      return;
    }

    setState(() { _isLoading = true; _errorMessage = ''; });

    try {
      final result = await AuthService.forgotPassword(email: email);
      setState(() => _isLoading = false);

      if (result['success']) {
        // Navigate to code-entry screen, passing the email so it can be
        // displayed as a reminder and submitted with the verification code.
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ResetPasswordScreen(email: email)),
          );
        }
      } else {
        setState(() => _errorMessage = result['error'] ?? 'Failed to send verification code');
      }
    } catch (_) {
      setState(() { _isLoading = false; _errorMessage = 'An error occurred. Please try again.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryNavyDark,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Forgot Password',
          style: TextStyle(fontFamily: 'Montserrat', color: AppColors.textPrimary),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Reset Your Password',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  fontFamily: 'Montserrat',
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Enter your email address and we\'ll send you a 6-digit verification code.',
                style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 32),

              if (_errorMessage.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_errorMessage, style: const TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                ),

              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  prefixIcon: const Icon(Icons.email_outlined),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                keyboardType: TextInputType.emailAddress,
                enabled: !_isLoading,
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitForgotPassword,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blue,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Send Code', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}