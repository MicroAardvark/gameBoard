import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'demo_seed.dart';

/// An in-memory stand-in for the Node/Express REST API, used by demo builds.
///
/// AuthService, SocialService and ImageUploadService send their requests to
/// [client] instead of the network, so every screen, model and error path
/// runs exactly as it does against the real server. Routes, status codes and
/// JSON shapes mirror routes/auth.js, routes/game.js and routes/social.js in
/// game_board_server.
///
/// State lives only in memory: refreshing the page starts again. Tokens
/// carry a per-page-load key, so a token saved by an earlier visit is
/// rejected and the visitor lands back on the login screen.
class DemoBackend {
  DemoBackend({
    DateTime Function()? clock,
    this.latency = const Duration(milliseconds: 250),
  }) : _clock = clock ?? DateTime.now {
    for (final user in DemoSeed.generate(_clock())) {
      _users[user.id] = user;
    }
  }

  /// The backend the app uses in a demo build.
  static final DemoBackend instance = DemoBackend();

  /// A short pause on every request, so loading states still show.
  final Duration latency;
  final DateTime Function() _clock;

  final Map<String, DemoUser> _users = {};

  /// Changes on every page load, so old tokens stop working.
  final String _sessionKey = Random().nextInt(0x7fffffff).toRadixString(36);

  late final http.Client client = MockClient(_handle);

  // ---- Plumbing ----

  Future<http.Response> _handle(http.Request request) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    try {
      return _route(request);
    } on _DemoError catch (e) {
      return _respond(e.status, {'error': e.message, ...e.extra});
    } catch (_) {
      // e.g. a malformed body: answer like the server would, not with a crash
      return _respond(500, {'error': 'Something went wrong in the demo.'});
    }
  }

  http.Response _respond(int status, Map<String, dynamic> body) => http.Response.bytes(
        utf8.encode(jsonEncode(body)),
        status,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

  http.Response _ok(Map<String, dynamic> body) => _respond(200, body);

  Map<String, dynamic> _body(http.Request request) {
    try {
      if (request.body.isEmpty) return {};
      final data = jsonDecode(request.body);
      return data is Map<String, dynamic> ? data : {};
    } catch (_) {
      return {}; // e.g. a multipart photo upload
    }
  }

  String _tokenFor(DemoUser user) => 'demo.$_sessionKey.${user.id}';

  /// The server's authMiddleware: a valid Bearer token or a 401.
  DemoUser _auth(http.Request request) {
    final header = request.headers['authorization'] ?? request.headers['Authorization'];
    final token = header != null && header.startsWith('Bearer ') ? header.substring(7) : null;
    if (token == null || token.isEmpty || token == 'null') {
      throw _DemoError(401, 'No token provided');
    }
    final prefix = 'demo.$_sessionKey.';
    final user = token.startsWith(prefix) ? _users[token.substring(prefix.length)] : null;
    if (user == null) throw _DemoError(401, 'Invalid token');
    return user;
  }

  DemoUser _target(String id) {
    final user = _users[id];
    if (user == null) throw _DemoError(404, 'User not found');
    return user;
  }

  // ---- Response shapes ----

  /// getUserResponse() in routes/auth.js
  Map<String, dynamic> userJson(DemoUser user) => {
        'id': user.id,
        'username': user.username,
        'email': user.email,
        'bankroll': user.bankroll,
        'stats': user.stats,
        'profileImage': null,
      };

  /// formatUserData() in routes/social.js
  Map<String, dynamic> _publicJson(DemoUser user) => {
        'id': user.id,
        'username': user.username,
        'profileImage': null,
      };

  // ---- Routing ----

  http.Response _route(http.Request request) {
    final method = request.method.toUpperCase();
    final parts = request.url.pathSegments.where((s) => s.isNotEmpty).toList();
    if (parts.length < 2 || parts[0] != 'api') throw _DemoError(404, 'Not found');

    final area = parts[1];
    final rest = parts.sublist(2);
    switch (area) {
      case 'auth':
        return _authRoute(method, rest, request);
      case 'game':
        return _gameRoute(method, rest, request);
      case 'social':
        return _socialRoute(method, rest, request);
    }
    throw _DemoError(404, 'Not found');
  }

  // ---- /api/auth ----

  http.Response _authRoute(String method, List<String> rest, http.Request request) {
    final route = '$method ${rest.join('/')}';
    final body = _body(request);

    switch (route) {
      case 'POST signup':
        final username = body['username'] as String?;
        final email = body['email'] as String?;
        final password = body['password'] as String?;
        if ([username, email, password].any((v) => v == null || v.isEmpty)) {
          throw _DemoError(400, 'All fields are required');
        }
        if (password!.length < 6) {
          throw _DemoError(400, 'Password must be at least 6 characters');
        }
        // A new account needs its email verified, and the demo sends no email
        throw _DemoError(403,
            'Creating accounts is turned off in the demo. Use the demo account instead.');

      case 'POST login':
        final email = (body['email'] as String?)?.trim().toLowerCase();
        final password = body['password'] as String?;
        if (email == null || email.isEmpty || password == null || password.isEmpty) {
          throw _DemoError(400, 'Email and password are required');
        }
        DemoUser? user;
        for (final u in _users.values) {
          if (u.email == email) user = u;
        }
        if (user == null || user.password == null || user.password != password) {
          throw _DemoError(401, 'Invalid credentials');
        }
        return _ok({'token': _tokenFor(user), 'user': userJson(user)});

      case 'POST resend-verification':
        final email = body['email'] as String?;
        if (email == null || email.isEmpty) throw _DemoError(400, 'Email is required');
        if (_users.values.any((u) => u.email == email)) {
          throw _DemoError(400, 'Email is already verified');
        }
        return _ok({
          'message': 'If that email exists and is not verified, we sent a verification email.',
        });

      case 'GET verify':
        final user = _auth(request);
        return _ok({'valid': true, 'user': userJson(user)});

      case 'PUT update-username':
        final user = _auth(request);
        final username = body['username'] as String?;
        if (username == null || username.trim().isEmpty) {
          throw _DemoError(400, 'Username is required');
        }
        if (username.length < 3) {
          throw _DemoError(400, 'Username must be at least 3 characters');
        }
        if (username.length > 20) {
          throw _DemoError(400, 'Username must be less than 20 characters');
        }
        final taken = _users.values.any((u) => u.id != user.id && u.username == username.trim());
        if (taken) throw _DemoError(400, 'Username is already taken');
        user.username = username.trim();
        return _ok({'message': 'Username updated successfully', 'user': userJson(user)});

      case 'PUT change-password':
        _auth(request);
        final current = body['currentPassword'] as String?;
        final next = body['newPassword'] as String?;
        if (current == null || current.isEmpty || next == null || next.isEmpty) {
          throw _DemoError(400, 'Current password and new password are required');
        }
        if (next.length < 6) {
          throw _DemoError(400, 'New password must be at least 6 characters');
        }
        throw _DemoError(403, 'Password changes are turned off in the demo.');

      case 'DELETE account':
        _auth(request);
        throw _DemoError(403, 'Deleting the account is turned off in the demo.');

      case 'POST forgot-password':
        // Same reply whether or not the email exists; the demo sends nothing
        return _ok({'message': 'If the email exists, a code has been sent.'});

      case 'POST reset-password':
        // The server replies with `message` here, not `error`
        throw _DemoError(400, 'Password resets are turned off in the demo.',
            extra: {'message': 'Password resets are turned off in the demo.'});

      case 'POST upload-profile-image':
        _auth(request);
        throw _DemoError(403, 'Photo uploads are turned off in the demo.');

      case 'DELETE delete-profile-image':
        _auth(request);
        throw _DemoError(400, 'No profile image to delete');
    }
    throw _DemoError(404, 'Not found');
  }

  // ---- /api/game ----

  http.Response _gameRoute(String method, List<String> rest, http.Request request) {
    final route = '$method ${rest.join('/')}';
    switch (route) {
      case 'PUT update-stats':
        final user = _auth(request);
        final body = _body(request);
        final gameType = body['gameType'] as String?;
        final result = body['result'] as String?;
        // The server $inc's the bankroll by the amount sent
        final bankroll = body['bankroll'];
        if (bankroll is num) user.bankroll += bankroll;
        if (result != null && result.isNotEmpty && gameType != null) {
          final stats = user.stats.putIfAbsent(
              gameType, () => {'wins': 0, 'losses': 0, 'totalPlayed': 0});
          stats['totalPlayed'] = (stats['totalPlayed'] ?? 0) + 1;
          if (result == 'win') stats['wins'] = (stats['wins'] ?? 0) + 1;
          if (result == 'loss') stats['losses'] = (stats['losses'] ?? 0) + 1;
        }
        return _ok({
          'success': true,
          'user': {'bankroll': user.bankroll, 'stats': user.stats},
        });

      case 'GET stats':
        final user = _auth(request);
        return _ok({'_id': user.id, 'bankroll': user.bankroll, 'stats': user.stats});
    }
    throw _DemoError(404, 'Not found');
  }

  // ---- /api/social ----

  http.Response _socialRoute(String method, List<String> rest, http.Request request) {
    final me = _auth(request);
    final body = _body(request);
    final now = _clock();

    // GET /api/social
    if (method == 'GET' && rest.isEmpty) {
      final friends = me.friends.map((id) => _users[id]).whereType<DemoUser>();
      return _ok({'friends': friends.map(_publicJson).toList()});
    }

    if (method == 'GET' && rest.length == 1) {
      switch (rest[0]) {
        case 'search':
          final query = request.url.queryParameters['username'];
          if (query == null || query.length < 2) {
            throw _DemoError(400, 'Username must be at least 2 characters');
          }
          final needle = query.toLowerCase();
          final results = _users.values
              .where((u) =>
                  u.id != me.id &&
                  !me.blockedUsers.containsKey(u.id) &&
                  !u.blockedUsers.containsKey(me.id) &&
                  u.username.toLowerCase().contains(needle))
              .take(20)
              .map((u) => {
                    ..._publicJson(u),
                    'isFriend': me.friends.contains(u.id),
                    'hasRequestFrom': me.friendRequests.containsKey(u.id),
                    'hasSentRequestTo': me.sentRequests.containsKey(u.id),
                    'isBlocked': me.blockedUsers.containsKey(u.id),
                  })
              .toList();
          return _ok({'users': results});

        case 'requests':
          List<Map<String, dynamic>> list(Map<String, DateTime> requests) => [
                for (final entry in requests.entries)
                  if (_users[entry.key] case final other?)
                    {..._publicJson(other), 'createdAt': entry.value.toUtc().toIso8601String()},
              ];
          return _ok({'received': list(me.friendRequests), 'sent': list(me.sentRequests)});

        case 'blocked':
          return _ok({
            'blocked': [
              for (final entry in me.blockedUsers.entries)
                if (_users[entry.key] case final other?)
                  {..._publicJson(other), 'blockedAt': entry.value.toUtc().toIso8601String()},
            ],
          });
      }
    }

    // POST /api/social/request  { userId }
    if (method == 'POST' && rest.length == 1 && rest[0] == 'request') {
      final targetId = body['userId'] as String?;
      if (targetId == null || targetId.isEmpty) throw _DemoError(400, 'User ID is required');
      if (targetId == me.id) throw _DemoError(400, 'Cannot send friend request to yourself');
      final target = _target(targetId);
      if (me.blockedUsers.containsKey(target.id) || target.blockedUsers.containsKey(me.id)) {
        throw _DemoError(403, 'Cannot send friend request to this user');
      }
      if (me.friends.contains(target.id)) throw _DemoError(400, 'Already friends with this user');
      if (me.sentRequests.containsKey(target.id)) {
        throw _DemoError(400, 'Friend request already sent');
      }
      if (me.friendRequests.containsKey(target.id)) {
        throw _DemoError(400, 'This user has already sent you a request');
      }
      me.sentRequests[target.id] = now;
      target.friendRequests[me.id] = now;
      return _ok({'message': 'Friend request sent successfully', 'user': _publicJson(target)});
    }

    if (rest.length == 2) {
      final action = rest[0];
      final targetId = rest[1];

      switch ('$method $action') {
        case 'POST accept':
          final requester = _target(targetId);
          if (!me.friendRequests.containsKey(requester.id)) {
            throw _DemoError(400, 'No friend request from this user');
          }
          me.friendRequests.remove(requester.id);
          requester.sentRequests.remove(me.id);
          me.friends.add(requester.id);
          requester.friends.add(me.id);
          return _ok({'message': 'Friend request accepted', 'user': _publicJson(requester)});

        case 'POST reject':
          final requester = _target(targetId);
          if (!me.friendRequests.containsKey(requester.id)) {
            throw _DemoError(400, 'No friend request from this user');
          }
          me.friendRequests.remove(requester.id);
          requester.sentRequests.remove(me.id);
          return _ok({'message': 'Friend request rejected'});

        case 'DELETE request':
          final target = _target(targetId);
          if (!me.sentRequests.containsKey(target.id)) {
            throw _DemoError(400, 'No pending request to this user');
          }
          me.sentRequests.remove(target.id);
          target.friendRequests.remove(me.id);
          return _ok({'message': 'Friend request cancelled'});

        case 'POST block':
          if (targetId == me.id) throw _DemoError(400, 'Cannot block yourself');
          final target = _target(targetId);
          if (me.blockedUsers.containsKey(target.id)) {
            throw _DemoError(400, 'User is already blocked');
          }
          // Blocking also ends the friendship and any pending requests
          me.friends.remove(target.id);
          target.friends.remove(me.id);
          me.friendRequests.remove(target.id);
          me.sentRequests.remove(target.id);
          target.friendRequests.remove(me.id);
          target.sentRequests.remove(me.id);
          me.blockedUsers[target.id] = now;
          return _ok({'message': 'User blocked successfully', 'user': _publicJson(target)});

        case 'DELETE block':
          final target = _target(targetId);
          if (!me.blockedUsers.containsKey(target.id)) {
            throw _DemoError(400, 'User is not blocked');
          }
          me.blockedUsers.remove(target.id);
          return _ok({'message': 'User unblocked successfully', 'user': _publicJson(target)});

        case 'POST report':
          if (targetId == me.id) throw _DemoError(400, 'Cannot report yourself');
          final reason = body['reason'] as String?;
          if (reason == null || reason.isEmpty) {
            throw _DemoError(400, 'Report reason is required');
          }
          _target(targetId);
          // Nothing is sent anywhere in the demo
          return _ok({
            'message': 'User reported successfully. Our moderation team will review this report.',
          });
      }
    }

    // DELETE /api/social/:userId  (remove a friend)
    if (method == 'DELETE' && rest.length == 1) {
      final friend = _target(rest[0]);
      if (!me.friends.contains(friend.id)) throw _DemoError(400, 'Not friends with this user');
      me.friends.remove(friend.id);
      friend.friends.remove(me.id);
      return _ok({'message': 'Friend removed successfully'});
    }

    throw _DemoError(404, 'Not found');
  }
}

class _DemoError implements Exception {
  _DemoError(this.status, this.message, {this.extra = const {}});

  final int status;
  final String message;
  final Map<String, dynamic> extra;
}
