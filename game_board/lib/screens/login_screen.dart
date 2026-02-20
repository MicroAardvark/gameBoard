// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../models/user.dart';
import '../theme/app_theme.dart';
import 'forgot_pass_screen.dart';

/// Combined login / sign-up screen toggled by [_isLogin].
///
/// Authentication is handled by [AuthService], which communicates with the
/// Node.js backend. A successful login calls [onLoginSuccess] so that the
/// parent widget can update its auth state and navigate to [HomeScreen].
///
/// Email verification is enforced by the server: signing up triggers a
/// verification email, and attempting to log in before verifying shows a
/// dialog with a resend option.
class LoginScreen extends StatefulWidget {
  final Function(User) onLoginSuccess;

  const LoginScreen({super.key, required this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController           = TextEditingController();
  final _passwordController        = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  final _usernameController        = TextEditingController();

  bool   _isLogin      = true;
  bool   _isLoading    = false;
  String _errorMessage = '';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() { _isLoading = true; _errorMessage = ''; });

    Map<String, dynamic> result;

    if (_isLogin) {
      result = await AuthService.logIn(
        email:    _emailController.text.trim(),
        password: _passwordController.text,
      );
    } else {
      // Client-side password match check before the API call.
      if (_passwordController.text != _passwordConfirmController.text) {
        setState(() { _isLoading = false; _errorMessage = 'Passwords do not match.'; });
        return;
      }
      result = await AuthService.signUp(
        username: _usernameController.text.trim(),
        email:    _emailController.text.trim(),
        password: _passwordController.text,
      );
    }

    setState(() => _isLoading = false);

    if (result['success']) {
      if (_isLogin) {
        widget.onLoginSuccess(User.fromJson(result['user']));
      } else if (mounted) {
        // Registration succeeded but the user must verify their email before
        // they can log in, so surface the verification dialog rather than
        // navigating directly to home.
        _showEmailVerificationDialog(result['email'] ?? _emailController.text.trim());
      }
    } else {
      setState(() => _errorMessage = result['error']);

      if (result['emailNotVerified'] == true && mounted) {
        _showEmailNotVerifiedDialog(result['email'] ?? _emailController.text.trim());
      }
    }
  }

  /// Shown after a successful sign-up to explain that email verification
  /// is required before the account can be used.
  void _showEmailVerificationDialog(String email) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Verify Your Email',
          style: TextStyle(fontFamily: 'Montserrat', color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mark_email_read_outlined, size: 64, color: AppColors.secondaryAmber),
            const SizedBox(height: 20),
            const Text(
              'We\'ve sent a verification email to:',
              style: TextStyle(fontFamily: 'Inter', color: AppColors.textSecondary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              email,
              style: const TextStyle(fontFamily: 'Inter', color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            const Text(
              'Please check your email and click the verification link to complete your registration.',
              style: TextStyle(fontFamily: 'Inter', color: AppColors.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryNavyDark,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.secondaryAmber, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Check your spam folder if you don\'t see it',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async { Navigator.pop(context); await _resendVerificationEmail(email); },
            child: const Text('Resend Email', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _isLogin = true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondaryAmber),
            child: Text('OK', style: TextStyle(color: AppColors.textOnAmber)),
          ),
        ],
      ),
    );
  }

  /// Shown when a user attempts to log in before verifying their email.
  void _showEmailNotVerifiedDialog(String email) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange),
            const SizedBox(width: 8),
            const Text(
              'Email Not Verified',
              style: TextStyle(fontFamily: 'Montserrat', color: AppColors.textPrimary),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Please verify your email before logging in.',
              style: TextStyle(fontFamily: 'Inter', color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            const Text('Check your inbox at:', style: TextStyle(fontFamily: 'Inter', color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 4),
            Text(email, style: const TextStyle(fontFamily: 'Inter', color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.primaryNavyDark, borderRadius: BorderRadius.circular(6)),
              child: const Text(
                'Didn\'t receive the email? You can request a new one.',
                style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async { Navigator.pop(context); await _resendVerificationEmail(email); },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondaryAmber),
            child: Text('Resend Email', style: TextStyle(color: AppColors.textOnAmber)),
          ),
        ],
      ),
    );
  }

  Future<void> _resendVerificationEmail(String email) async {
    setState(() => _isLoading = true);
    final result = await AuthService.resendVerificationEmail(email: email);
    setState(() => _isLoading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['success']
                ? '✉️ Verification email sent! Please check your inbox.'
                : result['error'] ?? 'Failed to send verification email',
          ),
          backgroundColor: result['success'] ? Colors.green : AppColors.error,
          duration: const Duration(seconds: 4),
          action: result['success']
              ? SnackBarAction(label: 'OK', textColor: Colors.white, onPressed: () {})
              : null,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryNavy,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _isLogin ? 'Login' : 'Sign Up',
                    style: const TextStyle(
                      fontFamily: 'Montserrat', fontSize: 28,
                      fontWeight: FontWeight.bold, color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (!_isLogin) ...[
                    const TextField(decoration: InputDecoration(labelText: 'Username', border: OutlineInputBorder())),
                    const SizedBox(height: 16),
                  ],

                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _passwordController,
                    decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
                    obscureText: true,
                  ),
                  const SizedBox(height: 16),

                  if (!_isLogin) ...[
                    TextField(
                      controller: _passwordConfirmController,
                      decoration: const InputDecoration(labelText: 'Confirm Password', border: OutlineInputBorder()),
                      obscureText: true,
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (_errorMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(_errorMessage, style: const TextStyle(fontFamily: 'Inter', color: Colors.red)),
                    ),

                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.blue,
                        foregroundColor: AppColors.textPrimary,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20, width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textPrimary),
                            )
                          : Text(_isLogin ? 'Login' : 'Sign Up'),
                    ),
                  ),
                  const SizedBox(height: 8),

                  TextButton(
                    onPressed: () => setState(() { _isLogin = !_isLogin; _errorMessage = ''; }),
                    child: Text(_isLogin ? 'Don\'t have an account? Sign Up' : 'Already have an account? Login'),
                  ),

                  if (_isLogin)
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                      ),
                      child: const Text('Forgot password?', style: TextStyle(color: Colors.blue, fontSize: 14)),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}