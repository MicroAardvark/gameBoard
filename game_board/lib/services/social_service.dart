// lib/services/friends_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class FriendsService {
  static const String baseUrl = 'http://192.168.0.118:3000/api/social';
  
  /// Search users by username
  static Future<Map<String, dynamic>> searchUsers(String username) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return {'success': false, 'error': 'No authentication token found'};
      }
      
      final response = await http.get(
        Uri.parse('$baseUrl/search?username=$username'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'users': data['users'],
        };
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'error': error['error'] ?? 'Search failed',
        };
      }
    } catch (e) {
      print('❌ Search users error: $e');
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }
  
  /// Get friends list
  static Future<Map<String, dynamic>> getFriends() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return {'success': false, 'error': 'No authentication token found'};
      }
      
      final response = await http.get(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'friends': data['friends'],
        };
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'error': error['error'] ?? 'Failed to fetch friends',
        };
      }
    } catch (e) {
      print('❌ Get friends error: $e');
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }
  
  /// Get friend requests (received and sent)
  static Future<Map<String, dynamic>> getRequests() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return {'success': false, 'error': 'No authentication token found'};
      }
      
      final response = await http.get(
        Uri.parse('$baseUrl/requests'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'received': data['received'],
          'sent': data['sent'],
        };
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'error': error['error'] ?? 'Failed to fetch requests',
        };
      }
    } catch (e) {
      print('❌ Get requests error: $e');
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }
  
  /// Send friend request
  static Future<Map<String, dynamic>> sendRequest(String userId) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return {'success': false, 'error': 'No authentication token found'};
      }
      
      final response = await http.post(
        Uri.parse('$baseUrl/request'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'userId': userId}),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'message': data['message'],
        };
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'error': error['error'] ?? 'Failed to send request',
        };
      }
    } catch (e) {
      print('❌ Send request error: $e');
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }
  
  /// Accept friend request
  static Future<Map<String, dynamic>> acceptRequest(String userId) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return {'success': false, 'error': 'No authentication token found'};
      }
      
      final response = await http.post(
        Uri.parse('$baseUrl/accept/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'message': data['message'],
        };
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'error': error['error'] ?? 'Failed to accept request',
        };
      }
    } catch (e) {
      print('❌ Accept request error: $e');
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }
  
  /// Reject friend request
  static Future<Map<String, dynamic>> rejectRequest(String userId) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return {'success': false, 'error': 'No authentication token found'};
      }
      
      final response = await http.post(
        Uri.parse('$baseUrl/reject/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'message': data['message'],
        };
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'error': error['error'] ?? 'Failed to reject request',
        };
      }
    } catch (e) {
      print('❌ Reject request error: $e');
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }
  
  /// Remove friend
  static Future<Map<String, dynamic>> removeFriend(String userId) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return {'success': false, 'error': 'No authentication token found'};
      }
      
      final response = await http.delete(
        Uri.parse('$baseUrl/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'message': data['message'],
        };
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'error': error['error'] ?? 'Failed to remove friend',
        };
      }
    } catch (e) {
      print('❌ Remove friend error: $e');
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }
  
  /// Cancel sent friend request
  static Future<Map<String, dynamic>> cancelRequest(String userId) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return {'success': false, 'error': 'No authentication token found'};
      }
      
      final response = await http.delete(
        Uri.parse('$baseUrl/request/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'message': data['message'],
        };
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'error': error['error'] ?? 'Failed to cancel request',
        };
      }
    } catch (e) {
      print('❌ Cancel request error: $e');
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }
  
  // ==================== BLOCKING METHODS ====================
  
  /// Get blocked users list
  static Future<Map<String, dynamic>> getBlocked() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return {'success': false, 'error': 'No authentication token found'};
      }
      
      final response = await http.get(
        Uri.parse('$baseUrl/blocked'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'blocked': data['blocked'],
        };
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'error': error['error'] ?? 'Failed to fetch blocked users',
        };
      }
    } catch (e) {
      print('❌ Get blocked users error: $e');
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }
  
  /// Block a user
  static Future<Map<String, dynamic>> blockUser(String userId) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return {'success': false, 'error': 'No authentication token found'};
      }
      
      final response = await http.post(
        Uri.parse('$baseUrl/block/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'message': data['message'],
        };
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'error': error['error'] ?? 'Failed to block user',
        };
      }
    } catch (e) {
      print('❌ Block user error: $e');
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }
  
  /// Unblock a user
  static Future<Map<String, dynamic>> unblockUser(String userId) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return {'success': false, 'error': 'No authentication token found'};
      }
      
      final response = await http.delete(
        Uri.parse('$baseUrl/block/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'message': data['message'],
        };
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'error': error['error'] ?? 'Failed to unblock user',
        };
      }
    } catch (e) {
      print('❌ Unblock user error: $e');
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }
}