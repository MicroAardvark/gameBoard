class User {
  final String id;
  final String username;
  final String email;
  final double bankroll;
  final int playerWins;
  final int dealerWins;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.bankroll,
    required this.playerWins,
    required this.dealerWins,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'],
      email: json['email'],
      bankroll: (json['bankroll'] ?? 1000).toDouble(),
      playerWins: json['playerWins'] ?? 0,
      dealerWins: json['dealerWins'] ?? 0,
    );
  }
}