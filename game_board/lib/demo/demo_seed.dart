/// Made-up players for the demo build. None of these are real people.
///
/// The visitor plays as [demoUsername]. A few of the others are already
/// their friends, one has sent them a friend request and one is waiting
/// on a request they sent, so every tab of the social panel has
/// something in it.
class DemoSeed {
  static const String demoEmail = 'demo@example.com';
  static const String demoUsername = 'DemoPlayer';
  static const String password = 'demo1234';

  static const String demoUserId = 'demo-user';

  /// Builds a fresh set of players. [now] is used for request and block dates.
  static List<DemoUser> generate(DateTime now) {
    DemoUser player(String id, String username) => DemoUser(
          id: id,
          username: username,
          email: '${username.toLowerCase()}@example.com',
        );

    final me = DemoUser(
      id: demoUserId,
      username: demoUsername,
      email: demoEmail,
      password: password,
      bankroll: 1250,
      stats: {
        'blackjack': {'wins': 12, 'losses': 9, 'totalPlayed': 23},
        'CrazyEights': {'wins': 5, 'losses': 4, 'totalPlayed': 9},
        'checkers': {'wins': 3, 'losses': 2, 'totalPlayed': 5},
      },
    );

    final others = [
      player('demo-luna', 'LuckyLuna'),
      player('demo-kev', 'KingMeKev'),
      player('demo-sam', 'CardSharpSam'),
      player('demo-raj', 'RiverRaj'),
      player('demo-queen', 'QueenOfClubs'),
      player('demo-ben', 'BustedBen'),
      player('demo-pairs', 'SplitPairs'),
      player('demo-wes', 'WildcardWes'),
      player('demo-dee', 'DoubleDownDee'),
      player('demo-eights', 'EightsAreWild'),
    ];
    final byName = {for (final u in others) u.username: u};

    // Friends both ways, as the server keeps them
    for (final name in ['LuckyLuna', 'KingMeKev', 'CardSharpSam']) {
      me.friends.add(byName[name]!.id);
      byName[name]!.friends.add(me.id);
    }

    // RiverRaj has asked to be friends
    final raj = byName['RiverRaj']!;
    final askedAt = now.subtract(const Duration(hours: 5));
    raj.sentRequests[me.id] = askedAt;
    me.friendRequests[raj.id] = askedAt;

    // The visitor is waiting on QueenOfClubs
    final queen = byName['QueenOfClubs']!;
    final sentAt = now.subtract(const Duration(days: 1, hours: 2));
    me.sentRequests[queen.id] = sentAt;
    queen.friendRequests[me.id] = sentAt;

    // Some friendships between the others, so search results look lived-in
    void befriend(String a, String b) {
      byName[a]!.friends.add(byName[b]!.id);
      byName[b]!.friends.add(byName[a]!.id);
    }

    befriend('LuckyLuna', 'BustedBen');
    befriend('KingMeKev', 'SplitPairs');
    befriend('WildcardWes', 'DoubleDownDee');

    return [me, ...others];
  }
}

/// One player, shaped like the server's User document.
///
/// Requests and blocks are maps of the other player's id to when it
/// happened, mirroring friendRequests / sentRequests / blockedUsers.
class DemoUser {
  DemoUser({
    required this.id,
    required this.username,
    required this.email,
    this.password,
    this.bankroll = 1000,
    Map<String, Map<String, int>>? stats,
  }) : stats = stats ??
            {
              'blackjack': {'wins': 0, 'losses': 0, 'totalPlayed': 0},
              'CrazyEights': {'wins': 0, 'losses': 0, 'totalPlayed': 0},
              'checkers': {'wins': 0, 'losses': 0, 'totalPlayed': 0},
            };

  final String id;
  String username;
  final String email;

  /// Only the demo account has one; the others can't log in.
  final String? password;

  num bankroll;
  final Map<String, Map<String, int>> stats;

  final Set<String> friends = {};
  final Map<String, DateTime> friendRequests = {}; // received, by sender id
  final Map<String, DateTime> sentRequests = {}; // sent, by recipient id
  final Map<String, DateTime> blockedUsers = {}; // by blocked user's id
}
