class User {
  final String id;
  final String username;
  final String email;
  final double bankroll;
  final Map<String, dynamic> stats; // Changed to support multi-game

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.bankroll,
    required this.stats,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'],
      email: json['email'],
      bankroll: (json['bankroll'] ?? 1000).toDouble(),
      stats: json['stats'] ?? {
        'blackjack': {'wins': 0, 'losses': 0, 'totalPlayed': 0},
        'CrazyEights': {'wins': 0, 'losses': 0, 'totalPlayed': 0},
        'checkers': {'wins': 0, 'losses': 0, 'totalPlayed': 0},
      },
    );
  }

  // Helper getters for backwards compatibility
  int get playerWins => (stats['blackjack']?['wins'] ?? 0) as int;
  int get dealerWins => (stats['blackjack']?['losses'] ?? 0) as int;
}