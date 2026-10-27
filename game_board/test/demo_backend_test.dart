import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_board/demo/demo_backend.dart';
import 'package:game_board/demo/demo_seed.dart';
import 'package:game_board/models/user.dart';
import 'package:http/http.dart' as http;

/// Checks the demo's fake API speaks the same JSON as game_board_server,
/// and that the app's own User model can read every user it returns.
void main() {
  late DemoBackend backend;
  late http.Client client;
  String? token;

  Future<(int, Map<String, dynamic>)> call(String method, String path,
      {Object? body, bool auth = true}) async {
    final request = http.Request(method, Uri.parse('https://microaardvark.co.uk$path'));
    request.headers['Content-Type'] = 'application/json';
    if (auth && token != null) request.headers['Authorization'] = 'Bearer $token';
    if (body != null) request.body = jsonEncode(body);
    final response = await http.Response.fromStream(await client.send(request));
    return (response.statusCode, jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> logIn() async {
    final (status, data) = await call('POST', '/api/auth/login',
        body: {'email': DemoSeed.demoEmail, 'password': DemoSeed.password}, auth: false);
    expect(status, 200);
    token = data['token'] as String;
  }

  const ids = {
    'LuckyLuna': 'demo-luna',
    'KingMeKev': 'demo-kev',
    'CardSharpSam': 'demo-sam',
    'RiverRaj': 'demo-raj',
    'QueenOfClubs': 'demo-queen',
    'BustedBen': 'demo-ben',
  };
  String idOf(String username) => ids[username]!;

  setUp(() {
    backend = DemoBackend(clock: () => DateTime(2026, 10, 27, 15), latency: Duration.zero);
    client = backend.client;
    token = null;
  });

  group('auth', () {
    test('logs in and returns a user the app can read', () async {
      final (status, data) = await call('POST', '/api/auth/login',
          body: {'email': DemoSeed.demoEmail, 'password': DemoSeed.password}, auth: false);
      expect(status, 200);
      expect(data['token'], isA<String>());
      final user = User.fromJson(data['user'] as Map<String, dynamic>);
      expect(user.username, DemoSeed.demoUsername);
      expect(user.stats['blackjack']['totalPlayed'], 23);
      expect(user.hasProfileImage, isFalse);
    });

    test('rejects a wrong password and other players', () async {
      var (status, data) = await call('POST', '/api/auth/login',
          body: {'email': DemoSeed.demoEmail, 'password': 'nope'}, auth: false);
      expect(status, 401);
      expect(data['error'], 'Invalid credentials');

      (status, data) = await call('POST', '/api/auth/login',
          body: {'email': 'luckyluna@example.com', 'password': DemoSeed.password}, auth: false);
      expect(status, 401);
    });

    test('verify needs a token from this page load', () async {
      var (status, _) = await call('GET', '/api/auth/verify');
      expect(status, 401);

      await logIn();
      final (okStatus, data) = await call('GET', '/api/auth/verify');
      expect(okStatus, 200);
      expect(data['valid'], isTrue);
      User.fromJson(data['user'] as Map<String, dynamic>);

      // A token saved by an earlier visit no longer works after a refresh
      final oldToken = token;
      backend = DemoBackend(latency: Duration.zero);
      client = backend.client;
      token = oldToken;
      (status, _) = await call('GET', '/api/auth/verify');
      expect(status, 401);
    });

    test('sign-up, password change and account deletion are turned off', () async {
      var (status, data) = await call('POST', '/api/auth/signup',
          body: {'username': 'NewPerson', 'email': 'new@example.com', 'password': 'abcdef'},
          auth: false);
      expect(status, 403);
      expect(data['error'], contains('demo'));

      await logIn();
      (status, data) = await call('PUT', '/api/auth/change-password',
          body: {'currentPassword': DemoSeed.password, 'newPassword': 'another1'});
      expect(status, 403);

      (status, data) = await call('DELETE', '/api/auth/account');
      expect(status, 403);
    });

    test('updates the username with the server\'s rules', () async {
      await logIn();
      var (status, data) = await call('PUT', '/api/auth/update-username', body: {'username': 'ab'});
      expect(status, 400);

      (status, data) = await call('PUT', '/api/auth/update-username', body: {'username': 'LuckyLuna'});
      expect(status, 400);
      expect(data['error'], 'Username is already taken');

      (status, data) = await call('PUT', '/api/auth/update-username', body: {'username': 'AceHigh'});
      expect(status, 200);
      expect(User.fromJson(data['user'] as Map<String, dynamic>).username, 'AceHigh');
    });

    test('password reset replies with message, as the server does', () async {
      var (status, data) = await call('POST', '/api/auth/forgot-password',
          body: {'email': DemoSeed.demoEmail}, auth: false);
      expect(status, 200);

      (status, data) = await call('POST', '/api/auth/reset-password',
          body: {'email': DemoSeed.demoEmail, 'code': '123456', 'newPassword': 'abcdef'},
          auth: false);
      expect(status, 400);
      expect(data['message'], isA<String>());
    });
  });

  group('game', () {
    test('update-stats counts results like the server', () async {
      await logIn();
      final (status, data) = await call('PUT', '/api/game/update-stats',
          body: {'gameType': 'checkers', 'bankroll': 0, 'result': 'win'});
      expect(status, 200);
      final stats = (data['user'] as Map)['stats'] as Map;
      expect(stats['checkers']['wins'], 4);
      expect(stats['checkers']['totalPlayed'], 6);
    });
  });

  group('social', () {
    setUp(logIn);

    test('lists friends and requests in the server\'s shape', () async {
      var (status, data) = await call('GET', '/api/social');
      expect(status, 200);
      final names = (data['friends'] as List).map((f) => f['username']).toSet();
      expect(names, {'LuckyLuna', 'KingMeKev', 'CardSharpSam'});

      (status, data) = await call('GET', '/api/social/requests');
      expect((data['received'] as List).single['username'], 'RiverRaj');
      expect((data['sent'] as List).single['username'], 'QueenOfClubs');
      expect((data['received'] as List).single['createdAt'], isA<String>());
    });

    test('search annotates each result', () async {
      final (status, data) = await call('GET', '/api/social/search?username=ra');
      expect(status, 200);
      final raj = (data['users'] as List).firstWhere((u) => u['username'] == 'RiverRaj');
      expect(raj['hasRequestFrom'], isTrue);
      expect(raj['isFriend'], isFalse);

      final (shortStatus, _) = await call('GET', '/api/social/search?username=r');
      expect(shortStatus, 400);
    });

    test('accepting a request makes a friend', () async {
      final raj = idOf('RiverRaj');
      var (status, _) = await call('POST', '/api/social/accept/$raj');
      expect(status, 200);
      var (_, data) = await call('GET', '/api/social');
      expect((data['friends'] as List).map((f) => f['id']), contains(raj));

      (status, _) = await call('POST', '/api/social/accept/$raj');
      expect(status, 400);
    });

    test('send, cancel and duplicate requests follow the server rules', () async {
      final ben = idOf('BustedBen');
      var (status, data) = await call('POST', '/api/social/request', body: {'userId': ben});
      expect(status, 200);
      (status, data) = await call('POST', '/api/social/request', body: {'userId': ben});
      expect(status, 400);
      expect(data['error'], 'Friend request already sent');

      (status, data) = await call('POST', '/api/social/request', body: {'userId': idOf('LuckyLuna')});
      expect(data['error'], 'Already friends with this user');

      (status, _) = await call('DELETE', '/api/social/request/$ben');
      expect(status, 200);
    });

    test('blocking removes the friendship and hides them from search', () async {
      final luna = idOf('LuckyLuna');
      var (status, _) = await call('POST', '/api/social/block/$luna');
      expect(status, 200);

      var (_, data) = await call('GET', '/api/social');
      expect((data['friends'] as List).map((f) => f['id']), isNot(contains(luna)));

      (_, data) = await call('GET', '/api/social/search?username=luna');
      expect(data['users'], isEmpty);

      (_, data) = await call('GET', '/api/social/blocked');
      expect((data['blocked'] as List).single['blockedAt'], isA<String>());

      (status, _) = await call('DELETE', '/api/social/block/$luna');
      expect(status, 200);
    });

    test('removing a friend and reporting', () async {
      final kev = idOf('KingMeKev');
      var (status, _) = await call('DELETE', '/api/social/$kev');
      expect(status, 200);
      (status, _) = await call('DELETE', '/api/social/$kev');
      expect(status, 400);

      (status, _) = await call('POST', '/api/social/report/$kev', body: {'reason': 'spam'});
      expect(status, 200);
    });

    test('unknown routes answer like the server, not with a crash', () async {
      final (status, data) = await call('GET', '/api/nothing/here');
      expect(status, 404);
      expect(data['error'], 'Not found');
    });
  });
}
