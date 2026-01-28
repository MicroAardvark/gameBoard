import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../models/user.dart';
import '../theme/app_theme.dart';
import 'forgot_pass_screen.dart';

class LoginScreen extends StatefulWidget {
  final Function(User) onLoginSuccess;

  const LoginScreen({super.key, required this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  final _usernameController = TextEditingController();
  bool _isLogin = true;
  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    Map<String, dynamic> result;

    if (_isLogin) {
      // LOGIN
      result = await AuthService.logIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } else {
      // SIGN UP
      if (_passwordController.text != _passwordConfirmController.text) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Passwords do not match.';
        });
        return;
      }
      
      result = await AuthService.signUp(
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    }

    setState(() => _isLoading = false);

    if (result['success']) {
      if (_isLogin) {
        // LOGIN SUCCESS - Navigate to home
        final user = User.fromJson(result['user']);
        widget.onLoginSuccess(user);
      } else {
        // SIGNUP SUCCESS - Show verification dialog
        if (mounted) {
          _showEmailVerificationDialog(result['email'] ?? _emailController.text.trim());
        }
      }
    } else {
      // ERROR
      setState(() => _errorMessage = result['error']);
      
      // If email not verified, show resend option
      if (result['emailNotVerified'] == true && mounted) {
        _showEmailNotVerifiedDialog(result['email'] ?? _emailController.text.trim());
      }
    }
  }

  void _showEmailVerificationDialog(String email) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'Verify Your Email',
          style: TextStyle(
            fontFamily: 'Montserrat',
            color: AppColors.textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.mark_email_read_outlined,
              size: 64,
              color: AppColors.secondaryAmber,
            ),
            SizedBox(height: 20),
            Text(
              'We\'ve sent a verification email to:',
              style: TextStyle(
                fontFamily: 'Inter',
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              email,
              style: TextStyle(
                fontFamily: 'Inter',
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            Text(
              'Please check your email and click the verification link to complete your registration.',
              style: TextStyle(
                fontFamily: 'Inter',
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryNavyDark,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppColors.secondaryAmber,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Check your spam folder if you don\'t see it',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _resendVerificationEmail(email);
            },
            child: Text(
              'Resend Email',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Switch to login mode
              setState(() => _isLogin = true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondaryAmber,
            ),
            child: Text(
              'OK',
              style: TextStyle(color: AppColors.textOnAmber),
            ),
          ),
        ],
      ),
    );
  }

  void _showEmailNotVerifiedDialog(String email) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text(
              'Email Not Verified',
              style: TextStyle(
                fontFamily: 'Montserrat',
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Please verify your email before logging in.',
              style: TextStyle(
                fontFamily: 'Inter',
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Check your inbox at:',
              style: TextStyle(
                fontFamily: 'Inter',
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            SizedBox(height: 4),
            Text(
              email,
              style: TextStyle(
                fontFamily: 'Inter',
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primaryNavyDark,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Didn\'t receive the email? You can request a new one.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _resendVerificationEmail(email);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondaryAmber,
            ),
            child: Text(
              'Resend Email',
              style: TextStyle(color: AppColors.textOnAmber),
            ),
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
          duration: Duration(seconds: 4),
          action: result['success']
              ? SnackBarAction(
                  label: 'OK',
                  textColor: Colors.white,
                  onPressed: () {},
                )
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
          padding: const EdgeInsets.all(24.0),
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _isLogin ? 'Login' : 'Sign Up',
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  if (!_isLogin)
                    TextField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  
                  if (!_isLogin) const SizedBox(height: 16),
                  
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  
                  TextField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 16),

                  if(!_isLogin)
                    TextField(
                      controller: _passwordConfirmController,
                      decoration: const InputDecoration(
                        labelText: 'Confirm Password',
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                    ),
                  const SizedBox(height: 16),
                  
                  if (_errorMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text(
                        _errorMessage,
                        style: const TextStyle(fontFamily: 'Inter', color: Colors.red),
                      ),
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
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.textPrimary,
                              ),
                            )
                          : Text(_isLogin ? 'Login' : 'Sign Up'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isLogin = !_isLogin;
                        _errorMessage = '';
                      });
                    },
                    child: Text(
                      _isLogin
                          ? 'Don\'t have an account? Sign Up'
                          : 'Already have an account? Login',
                    ),
                  ),

                  if (_isLogin)
                  Align(
                    child: TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ForgotPasswordScreen(),
                          ),
                        );
                      },
                      child: Text(
                        'Forgot password?',
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}