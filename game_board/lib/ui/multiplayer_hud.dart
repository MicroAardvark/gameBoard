// ====================================
// lib/ui/multiplayer_hud.dart
// HUD for multiplayer blackjack game
// ====================================
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../games/multiplayer_blackjack_game.dart';
import '../components/text_component.dart';
import '../components/button_component.dart';
import '../models/enums.dart';

class MultiplayerHudManager {
  final MultiplayerBlackjackGame game;

  MultiplayerHudManager(this.game);

  HudPanel? hudPanel;

  // Text components
  InfoTextComponent? bankrollText;
  InfoTextComponent? betText;
  InfoTextComponent? gameResultText;
  InfoTextComponent? myHandText;
  InfoTextComponent? dealerHandText;
  InfoTextComponent? turnIndicatorText;
  InfoTextComponent? roomInfoText;
  InfoTextComponent? playerCountText;

  // Button groups
  late List<GameButton> _bettingBtns;
  late List<GameButton> _playingBtns;
  late List<GameButton> _gameOverBtns;

  bool _hudPanelShown = false;

  // ===========================================
  // Setup HUD
  // ===========================================
  Future<void> setupHUD() async {
    removeHUD();
    await createHUD();
  }

  Future<void> createHUD() async {
    if (_hudPanelShown) return;

    hudPanel = HudPanel(game: game)..priority = MultiplayerBlackjackGame.layerHudPanel;
    game.add(hudPanel!);

    // Info text components
    bankrollText = InfoTextComponent(
      text: 'Bankroll: £0',
      position: Vector2(20, game.screenHeight - game.hudPanelHeight + 18),
      fontSize: game.fontSize,
    );

    betText = InfoTextComponent(
      text: 'Bet: £0 | Staged: £0',
      position: Vector2(20, game.screenHeight - game.hudPanelHeight + 18 + game.fontSize + 6),
      fontSize: game.fontSize,
    );

    roomInfoText = InfoTextComponent(
      text: 'Room: ...',
      position: Vector2(20, game.screenHeight - game.hudPanelHeight + 18 + (game.fontSize + 6) * 2),
      fontSize: game.fontSize * 0.8,
    );

    playerCountText = InfoTextComponent(
      text: 'Players: 0/3',
      position: Vector2(20, game.screenHeight - game.hudPanelHeight + 18 + (game.fontSize + 6) * 3),
      fontSize: game.fontSize * 0.8,
    );

    // Turn indicator (center top)
    turnIndicatorText = InfoTextComponent(
      text: '',
      position: Vector2(game.screenWidth / 2, 50),
      fontSize: game.largeFontSize,
    );
    turnIndicatorText!.anchor = Anchor.center;

    // Game result (top left)
    gameResultText = InfoTextComponent(
      text: '',
      position: Vector2(20, 20),
      fontSize: game.largeFontSize,
    );

    // Hand values
    myHandText = InfoTextComponent(
      text: 'Your Hand',
      position: Vector2(20, 80),
      fontSize: game.fontSize,
    );

    dealerHandText = InfoTextComponent(
      text: 'Dealer Hand',
      position: Vector2(20, 110),
      fontSize: game.fontSize,
    );

    hudPanel!.addAll([
      bankrollText!,
      betText!,
      roomInfoText!,
      playerCountText!,
      turnIndicatorText!,
      gameResultText!,
      myHandText!,
      dealerHandText!,
    ]);

    // ===========================================
    // BETTING BUTTONS
    // ===========================================
    _bettingBtns = [
      GameButton(
        position: Vector2(game.screenWidth * 0.25, game.screenHeight - 70),
        size: Vector2(game.buttonWidth, game.buttonHeight),
        text: 'Cancel',
        onTap: () {
          if (game.stagedBet > 0) {
            game.cancelStaged();
          }
        },
      ),
      GameButton(
        position: Vector2(game.screenWidth * 0.45, game.screenHeight - 70),
        size: Vector2(game.buttonWidth, game.buttonHeight),
        text: 'Confirm',
        onTap: () async {
          await game.confirmStagedToPot();
        },
      ),
      GameButton(
        position: Vector2(game.screenWidth * 0.65, game.screenHeight - 70),
        size: Vector2(game.buttonWidth, game.buttonHeight),
        text: 'Start',
        onTap: () {
          game.startRound();
        },
      ),
    ];

    // ===========================================
    // PLAYING BUTTONS
    // ===========================================
    _playingBtns = [
      GameButton(
        position: Vector2(game.screenWidth * 0.25, game.screenHeight - 70),
        size: Vector2(game.buttonWidth, game.buttonHeight),
        text: 'Hit',
        onTap: () => game.hit(),
      ),
      GameButton(
        position: Vector2(game.screenWidth * 0.45, game.screenHeight - 70),
        size: Vector2(game.buttonWidth, game.buttonHeight),
        text: 'Stand',
        onTap: () => game.stand(),
      ),
      GameButton(
        position: Vector2(game.screenWidth * 0.65, game.screenHeight - 70),
        size: Vector2(game.buttonWidth, game.buttonHeight),
        text: 'Double',
        onTap: () => game.doubleDown(),
      ),
    ];

    // ===========================================
    // GAME OVER BUTTONS
    // ===========================================
    _gameOverBtns = [
      GameButton(
        position: Vector2(game.screenWidth * 0.35, game.screenHeight - 70),
        size: Vector2(game.buttonWidth, game.buttonHeight),
        text: 'Next Round',
        onTap: () => game.newRound(),
      ),
      GameButton(
        position: Vector2(game.screenWidth * 0.55, game.screenHeight - 70),
        size: Vector2(game.buttonWidth, game.buttonHeight),
        text: 'Leave',
        onTap: () => game.leaveRoom(),
      ),
    ];

    hudPanel!.addAll(_bettingBtns + _playingBtns + _gameOverBtns);
    _hudPanelShown = true;

    updateHudVisibility();
  }

  void removeHUD() {
    hudPanel?.removeFromParent();
    hudPanel = null;
    _hudPanelShown = false;
  }

  // ===========================================
  // Update HUD Visibility Based on Game State
  // ===========================================
  void updateHudVisibility() {
    final g = game;

    if (g.gameState == GameState.betting) {
      // Show betting buttons
      final canCancel = g.stagedBet > 0;
      final canConfirm = g.stagedBet > 0 || g.currentBet > 0;
      final canStart = g.currentBet > 0 && g.isHost;

      _bettingBtns[0].hidden = !canCancel;
      _bettingBtns[0].isEnabled = canCancel;
      
      _bettingBtns[1].hidden = !canConfirm;
      _bettingBtns[1].isEnabled = canConfirm;
      
      _bettingBtns[2].hidden = !canStart;
      _bettingBtns[2].isEnabled = canStart;

      // Hide playing and game over buttons
      for (final b in _playingBtns) {
        b.hidden = true;
        b.isEnabled = false;
      }
      for (final b in _gameOverBtns) {
        b.hidden = true;
        b.isEnabled = false;
      }
    } 
    else if (g.gameState == GameState.playing) {
      // Show playing buttons only if it's my turn
      if (g.isMyTurn) {
        for (final b in _playingBtns) {
          b.hidden = false;
          b.isEnabled = true;
        }
      } else {
        for (final b in _playingBtns) {
          b.hidden = true;
          b.isEnabled = false;
        }
      }

      // Hide betting and game over buttons
      for (final b in _bettingBtns) {
        b.hidden = true;
        b.isEnabled = false;
      }
      for (final b in _gameOverBtns) {
        b.hidden = true;
        b.isEnabled = false;
      }
    } 
    else if (g.gameState == GameState.dealerTurn) {
      // Hide all buttons during dealer turn
      _showOnlyButtons(const []);
    } 
    else if (g.gameState == GameState.gameOver) {
      // Show game over buttons
      _showOnlyButtons(_gameOverBtns);
    }
  }

  void _showOnlyButtons(List<GameButton> needed) {
    final all = _bettingBtns + _playingBtns + _gameOverBtns;
    for (final b in all) {
      b.hidden = true;
      b.isEnabled = false;
    }
    for (final b in needed) {
      b.hidden = false;
      b.isEnabled = true;
    }
  }

  // ===========================================
  // Update Turn Indicator
  // ===========================================
  void updateTurnIndicator() {
    if (game.isMyTurn) {
      turnIndicatorText?.text = '🎯 YOUR TURN';
      turnIndicatorText?.textRenderer = TextPaint(
        style: TextStyle(
          color: Colors.greenAccent,
          fontSize: game.largeFontSize,
          fontWeight: FontWeight.bold,
        ),
      );
    } else if (game.currentTurnPlayerId.isNotEmpty) {
      final currentPlayer = game.otherPlayers[game.currentTurnPlayerId];
      if (currentPlayer != null) {
        turnIndicatorText?.text = '⏳ ${currentPlayer.username}\'s turn';
        turnIndicatorText?.textRenderer = TextPaint(
          style: TextStyle(
            color: Colors.orangeAccent,
            fontSize: game.largeFontSize,
            fontWeight: FontWeight.bold,
          ),
        );
      } else {
        turnIndicatorText?.text = '⏳ Waiting...';
        turnIndicatorText?.textRenderer = TextPaint(
          style: TextStyle(
            color: Colors.white70,
            fontSize: game.largeFontSize,
          ),
        );
      }
    } else if (game.gameState == GameState.dealerTurn) {
      turnIndicatorText?.text = '🎰 Dealer\'s Turn';
      turnIndicatorText?.textRenderer = TextPaint(
        style: TextStyle(
          color: Colors.redAccent,
          fontSize: game.largeFontSize,
          fontWeight: FontWeight.bold,
        ),
      );
    } else {
      turnIndicatorText?.text = '';
    }
  }

  // ===========================================
  // Update Game Result Display
  // ===========================================
  void updateGameResult(String result, {bool isWin = false}) {
    gameResultText?.text = result;
    
    Color resultColor;
    if (result.contains('win') || result.contains('Blackjack')) {
      resultColor = Colors.greenAccent;
    } else if (result.contains('Push')) {
      resultColor = Colors.yellowAccent;
    } else if (result.contains('Dealer wins') || result.contains('Busted')) {
      resultColor = Colors.redAccent;
    } else {
      resultColor = Colors.white;
    }

    gameResultText?.textRenderer = TextPaint(
      style: TextStyle(
        color: resultColor,
        fontSize: game.largeFontSize,
        fontWeight: FontWeight.bold,
        shadows: [
          Shadow(
            blurRadius: 10.0,
            color: Colors.black.withValues(alpha:(0.7)),
            offset: const Offset(2, 2),
          ),
        ],
      ),
    );
  }

  // ===========================================
  // Update Room Info
  // ===========================================
  void updateRoomInfo(String roomId, int playerCount, int maxPlayers) {
    roomInfoText?.text = 'Room: ${roomId.substring(0, 8)}...';
    playerCountText?.text = 'Players: $playerCount/$maxPlayers';
  }
}

// ===========================================
// HUD Panel Background
// ===========================================
class HudPanel extends PositionComponent {
  final MultiplayerBlackjackGame game;
  HudPanel({required this.game});

  @override
  void render(Canvas canvas) {
    final rect = Rect.fromLTWH(
      0,
      game.screenHeight - game.hudPanelHeight,
      game.screenWidth,
      game.hudPanelHeight,
    );
    
    // Semi-transparent background with gradient
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.black.withValues(alpha:(0.3)),
        Colors.black.withValues(alpha:(0.6)),
      ],
    );
    
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.fill;
    
    canvas.drawRect(rect, paint);
    
    // Top border line
    final borderPaint = Paint()
      ..color = Colors.amber.withValues(alpha:(0.3))
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    
    canvas.drawLine(
      Offset(0, rect.top),
      Offset(game.screenWidth, rect.top),
      borderPaint,
    );
  }
}

// ===========================================
// Connection Status Indicator (Optional)
// ===========================================
class ConnectionIndicator extends PositionComponent {
  final MultiplayerBlackjackGame game;
  bool isConnected;

  ConnectionIndicator({
    required this.game,
    this.isConnected = true,
  }) : super(priority: MultiplayerBlackjackGame.layerHud);

  @override
  void render(Canvas canvas) {
    final radius = 8.0;
    final position = Offset(game.screenWidth - 30, 30);

    // Circle background
    final bgPaint = Paint()
      ..color = Colors.black.withValues(alpha:(0.5))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(position, radius + 4, bgPaint);

    // Status indicator
    final statusPaint = Paint()
      ..color = isConnected ? Colors.green : Colors.red
      ..style = PaintingStyle.fill;
    canvas.drawCircle(position, radius, statusPaint);

    // Pulse effect when connected
    if (isConnected) {
      final pulsePaint = Paint()
        ..color = Colors.green.withValues(alpha:(0.3))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(position, radius + 6, pulsePaint);
    }
  }

  void updateStatus(bool connected) {
    isConnected = connected;
  }
}