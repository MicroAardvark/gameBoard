// lib/services/auth_service.dart
//
// AuthService — handles all authentication operations for the Microvark platform.
//
// Responsibilities:
//   - User registration (sign up) and login
//   - Email verification and resending of verification emails
//   - Automatic login via stored JWT token verification
//   - User profile retrieval
//   - Account management: username updates, password changes, account deletion
//   - Password reset flow (forgot password → email code → reset)
//   - Persistent token storage using SharedPreferences
//
// All methods return a Map<String, dynamic> with at minimum a 'success' boolean.
// On failure, an 'error' string is included. On success, relevant data is returned.
//
// Base API endpoint: https://microaardvark.co.uk/api/auth

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  /// Base URL for all authentication-related API endpoints.
  static const String baseUrl = 'https://microaardvark.co.uk/api/auth';

  // =============================
  // SIGN UP
  // =============================

  /// Registers a new user account.
  ///
  /// Sends a POST request to /auth/signup with the provided credentials.
  /// On success (HTTP 201), the server sends a verification email to the
  /// provided address. The user must verify their email before they can log in.
  ///
  /// Returns:
  ///   - `success: true` with `message` and `email` on HTTP 201.
  ///   - `success: false` with `error` on HTTP 4xx/5xx or network failure.
  static Future<Map<String, dynamic>> signUp({
    required String username,
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'message': data['message'],
          'email': data['email'],
        };
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'error': error['error']};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // =============================
  // LOG IN
  // =============================

  /// Authenticates an existing user with their email and password.
  ///
  /// On success (HTTP 200), the returned JWT token is persisted locally via
  /// [_saveToken] so subsequent requests can use it without re-authentication.
  ///
  /// If the account exists but the email has not been verified, the server
  /// returns `emailNotVerified: true` so the UI can prompt the user to
  /// resend the verification email.
  ///
  /// Returns:
  ///   - `success: true` with `user` data on HTTP 200.
  ///   - `success: false` with `error`, `emailNotVerified`, and `email` on failure.
  static Future<Map<String, dynamic>> logIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Persist the JWT token for future authenticated requests.
        await _saveToken(data['token']);
        return {'success': true, 'user': data['user']};
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'error': error['error'],
          'emailNotVerified': error['emailNotVerified'] ?? false,
          'email': error['email'],
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // =============================
  // RESEND VERIFICATION EMAIL
  // =============================

  /// Requests the server to resend the email verification link.
  ///
  /// Used when a user attempts to log in before verifying their email,
  /// or when the original verification email was not received.
  ///
  /// Returns:
  ///   - `success: true` with `message` and `email` on HTTP 200.
  ///   - `success: false` with `error` on failure.
  static Future<Map<String, dynamic>> resendVerificationEmail({
    required String email,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/resend-verification'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'],
          'email': data['email'],
        };
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to resend verification email',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // =============================
  // VERIFY TOKEN (AUTO LOGIN)
  // =============================

  /// Attempts to restore a user session using a previously stored JWT token.
  ///
  /// Called on app start to enable automatic login without requiring the user
  /// to re-enter their credentials. If the stored token is invalid or expired,
  /// it is cleared from local storage.
  ///
  /// Returns:
  ///   - `success: true` with `user` data if the token is valid.
  ///   - `success: false` with `error` if no token exists or the token is invalid.
  static Future<Map<String, dynamic>> verifyToken() async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'error': 'No token found'};
      }

      final response = await http.get(
        Uri.parse('$baseUrl/verify'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'user': data['user']};
      } else {
        // Token is invalid or expired; remove it to prevent stale auth state.
        await clearToken();
        return {'success': false, 'error': 'Invalid token'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // =============================
  // GET USER PROFILE
  // =============================

  /// Fetches the current user's profile data from the server.
  ///
  /// Reuses the /auth/verify endpoint as it returns the authenticated
  /// user's data alongside the token validation check.
  ///
  /// Returns:
  ///   - `success: true` with `user` data on success.
  ///   - `success: false` with `error` if unauthenticated or request fails.
  static Future<Map<String, dynamic>> getUserProfile() async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'error': 'No token found'};
      }

      final response = await http.get(
        Uri.parse('$baseUrl/verify'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'user': data['user']};
      } else {
        return {'success': false, 'error': 'Failed to fetch user profile'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // =============================
  // UPDATE STATS
  // =============================

  /// Persists the player's Blackjack statistics to the server.
  ///
  /// Called at the end of a Blackjack session to save the player's current
  /// bankroll and win/loss record. Uses a dedicated game stats endpoint
  /// separate from the auth base URL.
  ///
  /// Parameters:
  ///   - [bankroll]: The player's current balance.
  ///   - [playerWins]: Total number of rounds the player has won.
  ///   - [dealerWins]: Total number of rounds the dealer has won.
  ///
  /// Returns `true` on success (HTTP 200), `false` otherwise.
  static Future<bool> updateStats({
    required double bankroll,
    required int playerWins,
    required int dealerWins,
  }) async {
    try {
      final token = await getToken();
      if (token == null) return false;

      final response = await http.put(
        Uri.parse('https://microaardvark.co.uk/api/game/update-stats'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'bankroll': bankroll,
          'playerWins': playerWins,
          'dealerWins': dealerWins,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // =============================
  // UPDATE USERNAME
  // =============================

  /// Changes the authenticated user's display name.
  ///
  /// The server validates username availability and format.
  ///
  /// Returns:
  ///   - `success: true` with updated `user` data and a `message` on HTTP 200.
  ///   - `success: false` with `error` (e.g., username already taken) on failure.
  static Future<Map<String, dynamic>> updateUsername(String newUsername) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'error': 'No authentication token found'};
      }

      final response = await http.put(
        Uri.parse('$baseUrl/update-username'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'username': newUsername}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'user': data['user'],
          'message': data['message'],
        };
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to update username',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // =============================
  // CHANGE PASSWORD (LOGGED IN)
  // =============================

  /// Changes the password for an authenticated user.
  ///
  /// Requires the user's current password as verification before accepting
  /// the new password. This is the in-session flow; for forgotten passwords,
  /// see [forgotPassword] and [resetPasswordWithCode].
  ///
  /// Returns:
  ///   - `success: true` with updated `user` data and `message` on HTTP 200.
  ///   - `success: false` with `error` (e.g., incorrect current password) on failure.
  static Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'error': 'No authentication token found'};
      }

      final response = await http.put(
        Uri.parse('$baseUrl/change-password'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'user': data['user'],
          'message': data['message'],
        };
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to change password',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // =============================
  // DELETE ACCOUNT
  // =============================

  /// Permanently deletes the authenticated user's account.
  ///
  /// On success, the local auth token is cleared via [signOut] to ensure
  /// the user is fully logged out after account deletion.
  ///
  /// Returns:
  ///   - `success: true` on HTTP 200.
  ///   - `success: false` with `error` on failure.
  static Future<Map<String, dynamic>> deleteAccount() async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'error': 'No authentication token found'};
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/account'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        // Clear local session data after successful account deletion.
        await signOut();
        return {'success': true};
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'error': error['error'] ?? 'Failed to delete account',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // =============================
  // FORGOT PASSWORD (SEND CODE)
  // =============================

  /// Initiates the password reset flow by requesting a verification code.
  ///
  /// The server sends a time-limited numeric code to the provided email address.
  /// This code is then used in [resetPasswordWithCode] to set a new password.
  ///
  /// Returns:
  ///   - `success: true` on HTTP 200.
  ///   - `success: false` with `error` if the email is not registered or request fails.
  static Future<Map<String, dynamic>> forgotPassword({
    required String email,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to send verification code',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error. Please check your connection.',
      };
    }
  }

  // =============================
  // RESET PASSWORD WITH CODE
  // =============================

  /// Completes the password reset flow using the code sent by [forgotPassword].
  ///
  /// The server validates the code against the stored one for the given email.
  /// Codes are time-limited and single-use.
  ///
  /// Parameters:
  ///   - [email]: The email address the reset code was sent to.
  ///   - [code]: The verification code received by email.
  ///   - [newPassword]: The desired new password.
  ///
  /// Returns:
  ///   - `success: true` on HTTP 200.
  ///   - `success: false` with `error` if the code is invalid or expired.
  static Future<Map<String, dynamic>> resetPasswordWithCode({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'code': code,
          'newPassword': newPassword,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Invalid or expired code',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error. Please check your connection.',
      };
    }
  }

  // =============================
  // TOKEN MANAGEMENT
  // =============================

  /// Persists the JWT token to device storage using SharedPreferences.
  ///
  /// Stored under the key 'auth_token'. Called immediately after a
  /// successful login to enable persistent sessions across app restarts.
  static Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  /// Retrieves the stored JWT token from device storage.
  ///
  /// Returns `null` if no token has been saved (i.e., the user is not
  /// logged in or has previously signed out).
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  /// Removes the stored JWT token from device storage.
  ///
  /// Called when a token is found to be invalid/expired, or when the
  /// user explicitly signs out. After this, [getToken] will return null.
  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  /// Signs the user out by clearing their stored authentication token.
  ///
  /// This invalidates the local session. The server-side token remains
  /// valid until it naturally expires; for stateless JWT architectures
  /// this is the expected behaviour.
  static Future<void> signOut() async {
    await clearToken();
  }
}