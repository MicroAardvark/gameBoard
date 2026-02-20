// lib/models/enums.dart

/// Phases of a Blackjack round, driving which UI controls are active.
enum GameState {
  betting,    // Player is placing their bet before cards are dealt.
  playing,    // Player's turn: hit, stand, double, or split.
  dealerTurn, // Dealer is resolving their hand automatically.
  gameOver,   // Round complete; outcome is being displayed.
  waiting,    // Multiplayer lobby — waiting for other players to be ready.
}

/// The four possible outcomes of a completed Blackjack round.
enum RoundOutcome {
  playerBlackjack, // Natural 21 on the opening deal (pays 3:2).
  playerWin,       // Player beats the dealer without a natural.
  dealerWin,       // Dealer wins or player busts.
  push,            // Tie — bet is returned with no profit or loss.
}

/// Seat positions at the Blackjack table, used for layout calculations.
enum PositionType { left, center, right }