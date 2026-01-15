import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String baseUrl = 'http://192.168.0.118:3000/api/auth';
  
  // Sign Up
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
        await _saveToken(data['token']);
        return {'success': true, 'user': data['user']};
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'error': error['error']};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // Log In
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
        return {'success': false, 'error': error['error']};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // Verify Token (Auto-login) - FIXED VERSION
  static Future<Map<String, dynamic>> verifyToken() async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'error': 'No token found'};
      }

      // FIXED: Changed to GET request with Authorization header
      final response = await http.get(
        Uri.parse('$baseUrl/verify'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',  // Token in Authorization header
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Backend returns {valid: true, user: {...}}
        return {'success': true, 'user': data['user']};
      } else {
        await clearToken();
        return {'success': false, 'error': 'Invalid token'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // Update Stats - ALSO FIXED to use Authorization header
  static Future<bool> updateStats({
    required double bankroll,
    required int playerWins,
    required int dealerWins,
  }) async {
    try {
      final token = await getToken();
      if (token == null) return false;

      final response = await http.put(
        Uri.parse('http://51.21.236.10:3000/api/game/update-stats'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',  // Use Authorization header
        },
        body: jsonEncode({
          'bankroll': bankroll,
          'playerWins': playerWins,
          'dealerWins': dealerWins,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Update stats error: $e');
      return false;
    }
  }

  // Token Management
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

  // Sign Out
  static Future<void> signOut() async {
    await clearToken();
  }
}