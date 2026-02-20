// lib/models/user.dart

/// Represents the authenticated player, carrying identity, balance, and
/// per-game statistics persisted in MongoDB.
///
/// The [bankroll] is the player's in-app currency balance used for betting
/// in Blackjack. Stats are keyed by game name and contain wins, losses, and
/// total games played.
class User {
  final String id;
  final String username;
  final String email;
  final double bankroll;
  final Map<String, dynamic> stats;
  final String? profileImage; // CDN URL; null if the user has not set one.

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.bankroll,
    required this.stats,
    this.profileImage,
  });

  /// Deserialises the user document returned by the authentication API.
  ///
  /// Default stats are provided so that newly registered users without a
  /// stats document still have valid zero-value entries.
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id:       json['id'],
      username: json['username'],
      email:    json['email'],
      bankroll: (json['bankroll'] ?? 1000).toDouble(),
      stats:    json['stats'] ?? {
        'blackjack':   {'wins': 0, 'losses': 0, 'totalPlayed': 0},
        'CrazyEights': {'wins': 0, 'losses': 0, 'totalPlayed': 0},
        // TODO: Remove 'checkers' entry once the server-side schema is updated
        // to reflect that the Checkers game has been removed from the platform.
        'checkers': {'wins': 0, 'losses': 0, 'totalPlayed': 0},
      },
      profileImage: json['profileImage'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id':           id,
      'username':     username,
      'email':        email,
      'bankroll':     bankroll,
      'stats':        stats,
      'profileImage': profileImage,
    };
  }

  // ─── Convenience getters ──────────────────────────────────────────────────

  /// Retained for backwards compatibility with code that predates the
  /// generic stats map; reads directly from the Blackjack sub-document.
  int get playerWins => (stats['blackjack']?['wins'] ?? 0) as int;
  int get dealerWins => (stats['blackjack']?['losses'] ?? 0) as int;

  bool get hasProfileImage => profileImage != null && profileImage!.isNotEmpty;
}