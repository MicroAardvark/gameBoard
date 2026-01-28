// lib/services/auth_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String baseUrl = 'https://microaardvark.co.uk/api/auth';

  // =============================
  // SIGN UP
  // =============================
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
  static Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  static Future<void> signOut() async {
    await clearToken();
  }
}
