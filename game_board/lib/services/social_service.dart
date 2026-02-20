// lib/services/friends_service.dart
//
// FriendsService — manages all social interactions between users on the platform.
//
// Responsibilities:
//   - User search by username
//   - Friends list retrieval
//   - Friend request management (send, accept, reject, cancel)
//   - Friend removal
//   - User blocking and unblocking
//   - User reporting for inappropriate behaviour
//
// All methods require a valid JWT token from [AuthService] for authentication.
// All methods return a Map<String, dynamic> with at minimum a 'success' boolean.
//
// Base API endpoint: https://microaardvark.co.uk/api/social

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class FriendsService {
  /// Base URL for all social/friends API endpoints.
  static const String baseUrl = 'https://microaardvark.co.uk/api/social';

  // ==================== USER SEARCH ====================

  /// Searches for users by their username.
  ///
  /// Used in the friend search UI to find other players to add. Results
  /// typically exclude the current user and already-added friends, as
  /// determined by the server.
  ///
  /// Parameters:
  ///   - [username]: The search query string to match against usernames.
  ///
  /// Returns:
  ///   - `success: true` with a `users` list on HTTP 200.
  ///   - `success: false` with `error` on failure.
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

  // ==================== FRIENDS LIST ====================

  /// Retrieves the current user's list of confirmed friends.
  ///
  /// Returns:
  ///   - `success: true` with a `friends` list on HTTP 200.
  ///   - `success: false` with `error` on failure.
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

  // ==================== FRIEND REQUESTS ====================

  /// Retrieves all pending friend requests for the current user.
  ///
  /// Returns both incoming requests (awaiting the user's response) and
  /// outgoing requests (sent by the user, awaiting others' responses).
  ///
  /// Returns:
  ///   - `success: true` with `received` and `sent` request lists on HTTP 200.
  ///   - `success: false` with `error` on failure.
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

  /// Sends a friend request to another user.
  ///
  /// Parameters:
  ///   - [userId]: The ID of the user to send the request to.
  ///
  /// Returns:
  ///   - `success: true` with `message` on HTTP 200.
  ///   - `success: false` with `error` (e.g., already friends, request pending) on failure.
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

  /// Accepts an incoming friend request from another user.
  ///
  /// Parameters:
  ///   - [userId]: The ID of the user whose request is being accepted.
  ///
  /// Returns:
  ///   - `success: true` with `message` on HTTP 200.
  ///   - `success: false` with `error` on failure.
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

  /// Rejects an incoming friend request from another user.
  ///
  /// Parameters:
  ///   - [userId]: The ID of the user whose request is being rejected.
  ///
  /// Returns:
  ///   - `success: true` with `message` on HTTP 200.
  ///   - `success: false` with `error` on failure.
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

  /// Removes an existing friend from the current user's friends list.
  ///
  /// This is a mutual removal — the other user also loses this user as a friend.
  ///
  /// Parameters:
  ///   - [userId]: The ID of the friend to remove.
  ///
  /// Returns:
  ///   - `success: true` with `message` on HTTP 200.
  ///   - `success: false` with `error` on failure.
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

  /// Cancels a previously sent friend request that has not yet been accepted.
  ///
  /// Parameters:
  ///   - [userId]: The ID of the user to whom the request was sent.
  ///
  /// Returns:
  ///   - `success: true` with `message` on HTTP 200.
  ///   - `success: false` with `error` on failure.
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

  /// Retrieves the list of users that the current user has blocked.
  ///
  /// Blocked users cannot send friend requests, chat messages, or interact
  /// with the current user within the platform.
  ///
  /// Returns:
  ///   - `success: true` with a `blocked` list on HTTP 200.
  ///   - `success: false` with `error` on failure.
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

  /// Blocks a user, preventing them from interacting with the current user.
  ///
  /// If the blocked user is currently a friend, the friendship is also removed.
  ///
  /// Parameters:
  ///   - [userId]: The ID of the user to block.
  ///
  /// Returns:
  ///   - `success: true` with `message` on HTTP 200.
  ///   - `success: false` with `error` on failure.
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

  /// Removes a block, allowing the previously blocked user to interact again.
  ///
  /// Parameters:
  ///   - [userId]: The ID of the user to unblock.
  ///
  /// Returns:
  ///   - `success: true` with `message` on HTTP 200.
  ///   - `success: false` with `error` on failure.
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

  // ==================== REPORTING METHODS ====================

  /// Reports a user to the platform moderation team for inappropriate behaviour.
  ///
  /// Reports are stored server-side for review in accordance with the platform's
  /// moderation obligations under the UK Online Safety Act 2023.
  ///
  /// Parameters:
  ///   - [userId]: The ID of the user being reported.
  ///   - [reason]: A category string describing the nature of the report.
  ///     Must be one of: 'harassment', 'inappropriate_content', 'cheating',
  ///     'spam', 'offensive_language', 'other'.
  ///   - [message]: Optional additional context provided by the reporter
  ///     (maximum 500 characters).
  ///   - [chatMessageId]: Optional ID of a specific chat message that prompted
  ///     the report, enabling moderators to review the exact content in question.
  ///
  /// Returns:
  ///   - `success: true` with `message` on HTTP 200.
  ///   - `success: false` with `error` on failure.
  static Future<Map<String, dynamic>> reportUser({
    required String userId,
    required String reason,
    String? message,
    String? chatMessageId,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return {'success': false, 'error': 'No authentication token found'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/report/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'reason': reason,
          'message': message,
          'chatMessageId': chatMessageId,
        }),
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
          'error': error['error'] ?? 'Failed to report user',
        };
      }
    } catch (e) {
      print('❌ Report user error: $e');
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }
}