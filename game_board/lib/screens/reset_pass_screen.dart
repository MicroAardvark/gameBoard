import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String email;

  const ResetPasswordScreen({
    super.key,
    required this.email,
  });

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _passwordReset = false;
  String _errorMessage = '';
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submitPasswordReset() async {
    if (_codeController.text.length != 6) {
      setState(() => _errorMessage = 'Enter the 6-digit code');
      return;
    }

    if (_newPasswordController.text.length < 6) {
      setState(() => _errorMessage = 'Password must be at least 6 characters');
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      setState(() => _errorMessage = 'Passwords do not match');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final result = await AuthService.resetPasswordWithCode(
        email: widget.email,
        code: _codeController.text.trim(),
        newPassword: _newPasswordController.text,
      );

      setState(() => _isLoading = false);

      if (result['success']) {
        setState(() => _passwordReset = true);
      } else {
        setState(() {
          _errorMessage = result['error'] ?? 'Invalid or expired code';
        });
      }
    } catch (_) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'An error occurred. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryNavyDark,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(
          'Reset Password',
          style: TextStyle(
            fontFamily: 'Montserrat',
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _passwordReset ? _buildSuccessView() : _buildFormView(),
        ),
      ),
    );
  }

  Widget _buildFormView() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Enter Verification Code',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'A 6-digit code was sent to ${widget.email}',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),

          if (_errorMessage.isNotEmpty)
            Text(_errorMessage, style: const TextStyle(color: Colors.red)),

          const SizedBox(height: 12),

          TextField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(
              labelText: 'Verification Code',
            ),
          ),

          const SizedBox(height: 16),

          TextField(
            controller: _newPasswordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'New Password',
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off
                      : Icons.visibility,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),

          const SizedBox(height: 16),

          TextField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            decoration: InputDecoration(
              labelText: 'Confirm Password',
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword
                      ? Icons.visibility_off
                      : Icons.visibility,
                ),
                onPressed: () => setState(
                    () => _obscureConfirmPassword = !_obscureConfirmPassword),
              ),
            ),
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submitPasswordReset,
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Reset Password'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, size: 80, color: Colors.green),
          const SizedBox(height: 24),
          Text(
            'Password Reset Successful',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () =>
                Navigator.popUntil(context, (route) => route.isFirst),
            child: const Text('Back to Login'),
          ),
        ],
      ),
    );
  }
}
