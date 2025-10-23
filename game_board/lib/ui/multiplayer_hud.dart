// ====================================
// lib/ui/multiplayer_hud.dart
// HUD for multiplayer blackjack game - UPDATED TO MATCH SINGLE PLAYER
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
  InfoTextComponent? waitingStatusText;

  // Button groups
  List<GameButton> _waitingBtns = [];
  List<GameButton> _bettingBtns = [];
  List<GameButton> _playingBtns = [];
  List<GameButton> _gameOverBtns = [];

  bool _hudPanelShown = false;

  // ===========================================
  // Setup HUD
  // ===========================================
  Future<void> setupHUD() async {
    removeHUD();
    await createHUD();
  }

  Future<void> createHUD() async {
    if (_hudPanelShown) {
      debugPrint('🎮 [HUD] HUD already shown, skipping creation.');
      return;
    }

    debugPrint('🎨 [HUD] Creating HUD...');

    hudPanel = HudPanel(game: game)..priority = MultiplayerBlackjackGame.layerHudPanel;
    game.add(hudPanel!);

    // UPDATED: Hand labels at top left like single player
    myHandText = InfoTextComponent(
      text: 'Player Hand',
      position: Vector2(20, 20),
      fontSize: game.fontSize,
    );

    dealerHandText = InfoTextComponent(
      text: 'Dealer Hand',
      position: Vector2(20, 50),
      fontSize: game.fontSize,
    );

    // Turn indicator (center top)
    turnIndicatorText = InfoTextComponent(
      text: '',
      position: Vector2(game.screenWidth / 2, 80),
      fontSize: game.largeFontSize,
    );
    turnIndicatorText!.anchor = Anchor.center;

    // Game result (center screen, shown at end)
    gameResultText = InfoTextComponent(
      text: '',
      position: Vector2(game.screenWidth / 2, game.screenHeight / 2 - 100),
      fontSize: game.largeFontSize * 1.5,
    );
    gameResultText!.anchor = Anchor.center;

    // Waiting status text (center of screen)
    waitingStatusText = InfoTextComponent(
      text: 'Waiting for players to ready up...',
      position: Vector2(game.screenWidth / 2, game.screenHeight / 2 - 100),
      fontSize: game.largeFontSize,
    );
    waitingStatusText!.anchor = Anchor.center;

    // Bottom left info
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

    // Room info (top right corner)
    roomInfoText = InfoTextComponent(
      text: 'Room: ...',
      position: Vector2(game.screenWidth - 20, 20),
      fontSize: game.fontSize * 0.7,
    );
    roomInfoText!.anchor = Anchor.topRight;

    playerCountText = InfoTextComponent(
      text: '0/3',
      position: Vector2(game.screenWidth - 20, 40),
      fontSize: game.fontSize * 0.8,
    );
    playerCountText!.anchor = Anchor.topRight;

    // Add text components
    game.addAll([
      bankrollText!,
      betText!,
      roomInfoText!,
      playerCountText!,
      waitingStatusText!,
      turnIndicatorText!,
      gameResultText!,
      myHandText!,
      dealerHandText!,
    ]);

    // ===========================================
    // WAITING BUTTONS
    // ===========================================
    _waitingBtns = [
      GameButton(
        position: Vector2(game.screenWidth * 0.5, game.screenHeight / 2),
        size: Vector2(game.buttonWidth * 1.5, game.buttonHeight * 1.2),
        text: 'Ready',
        onTap: () {
          game.socketService.playerReady(
            roomId: game.roomId,
            userId: game.user.id,
          );
        },
      )..priority = MultiplayerBlackjackGame.layerHudPanel + 1,
    ];

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
      )..priority = MultiplayerBlackjackGame.layerHudPanel + 1,
      GameButton(
        position: Vector2(game.screenWidth * 0.45, game.screenHeight - 70),
        size: Vector2(game.buttonWidth, game.buttonHeight),
        text: 'Confirm',
        onTap: () async {
          await game.confirmStagedToPot();
        },
      )..priority = MultiplayerBlackjackGame.layerHudPanel + 1,
      GameButton(
        position: Vector2(game.screenWidth * 0.65, game.screenHeight - 70),
        size: Vector2(game.buttonWidth, game.buttonHeight),
        text: 'Start',
        onTap: () {
          game.startRound();
        },
      )..priority = MultiplayerBlackjackGame.layerHudPanel + 1,
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
      )..priority = MultiplayerBlackjackGame.layerHudPanel + 1,
      GameButton(
        position: Vector2(game.screenWidth * 0.45, game.screenHeight - 70),
        size: Vector2(game.buttonWidth, game.buttonHeight),
        text: 'Stand',
        onTap: () => game.stand(),
      )..priority = MultiplayerBlackjackGame.layerHudPanel + 1,
      GameButton(
        position: Vector2(game.screenWidth * 0.65, game.screenHeight - 70),
        size: Vector2(game.buttonWidth, game.buttonHeight),
        text: 'Double',
        onTap: () => game.doubleDown(),
      )..priority = MultiplayerBlackjackGame.layerHudPanel + 1,
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
      )..priority = MultiplayerBlackjackGame.layerHudPanel + 1,
      GameButton(
        position: Vector2(game.screenWidth * 0.55, game.screenHeight - 70),
        size: Vector2(game.buttonWidth, game.buttonHeight),
        text: 'Leave',
        onTap: () => game.leaveRoom(),
      )..priority = MultiplayerBlackjackGame.layerHudPanel + 1,
    ];

    game.addAll(_waitingBtns + _bettingBtns + _playingBtns + _gameOverBtns);
    _hudPanelShown = true;

    updateHudVisibility();
  }

  void removeHUD() {
    hudPanel?.removeFromParent();
    hudPanel = null;
    
    bankrollText?.removeFromParent();
    betText?.removeFromParent();
    roomInfoText?.removeFromParent();
    playerCountText?.removeFromParent();
    waitingStatusText?.removeFromParent();
    turnIndicatorText?.removeFromParent();
    gameResultText?.removeFromParent();
    myHandText?.removeFromParent();
    dealerHandText?.removeFromParent();
    
    for (final btn in _waitingBtns) {
      btn.removeFromParent();
    }
    for (final btn in _bettingBtns) {
      btn.removeFromParent();
    }
    for (final btn in _playingBtns) {
      btn.removeFromParent();
    }
    for (final btn in _gameOverBtns) {
      btn.removeFromParent();
    }
    
    _hudPanelShown = false;
  }

  // ===========================================
  // Update HUD Visibility Based on Game State
  // ===========================================
  void updateHudVisibility() {
    final g = game;

    // Hide waiting and result text by default
    waitingStatusText?.textRenderer = TextPaint(
      style: TextStyle(
        color: Colors.transparent,
        fontSize: game.largeFontSize,
      ),
    );

    gameResultText?.textRenderer = TextPaint(
      style: TextStyle(
        color: Colors.transparent,
        fontSize: game.largeFontSize * 1.5,
      ),
    );

    if (g.gameState == GameState.waiting) {
      _showOnlyButtons(_waitingBtns);
      
      // Show waiting status text
      waitingStatusText?.text = 'Waiting for players to ready up...';
      waitingStatusText?.textRenderer = TextPaint(
        style: TextStyle(
          color: Colors.white,
          fontSize: game.largeFontSize,
          fontWeight: FontWeight.bold,
        ),
      );
    }
    else if (g.gameState == GameState.betting) {
      final canCancel = g.stagedBet > 0;
      final canConfirm = g.stagedBet > 0 || g.currentBet > 0;
      final canStart = g.currentBet > 0 && g.isHost;

      _bettingBtns[0].hidden = !canCancel;
      _bettingBtns[0].isEnabled = canCancel;
      
      _bettingBtns[1].hidden = !canConfirm;
      _bettingBtns[1].isEnabled = canConfirm;
      
      _bettingBtns[2].hidden = !canStart;
      _bettingBtns[2].isEnabled = canStart;

      for (final b in _waitingBtns) {
        b.hidden = true;
        b.isEnabled = false;
      }
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

      for (final b in _waitingBtns) {
        b.hidden = true;
        b.isEnabled = false;
      }
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
      _showOnlyButtons(const []);
    } 
    else if (g.gameState == GameState.gameOver) {
      _showOnlyButtons(_gameOverBtns);
    }
  }

  void _showOnlyButtons(List<GameButton> needed) {
    final all = _waitingBtns + _bettingBtns + _playingBtns + _gameOverBtns;
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
    if (game.gameState == GameState.waiting) {
      turnIndicatorText?.text = '';
      return;
    }

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
        turnIndicatorText?.text = '';
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
        fontSize: game.largeFontSize * 1.5,
        fontWeight: FontWeight.bold,
        shadows: [
          Shadow(
            blurRadius: 10.0,
            color: Colors.black.withValues(alpha: 0.7),
            offset: const Offset(2, 2),
          ),
        ],
      ),
    );
  }

  // ===========================================
  // Update Room Info - UPDATED: Simpler display
  // ===========================================
  void updateRoomInfo(String roomId, int playerCount, int maxPlayers) {
    roomInfoText?.text = '${roomId.substring(0, 8)}...';
    playerCountText?.text = '$playerCount/$maxPlayers';
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
    
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.black.withValues(alpha: 0.3),
        Colors.black.withValues(alpha: 0.6),
      ],
    );
    
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.fill;
    
    canvas.drawRect(rect, paint);
    
    final borderPaint = Paint()
      ..color = Colors.amber.withValues(alpha: 0.3)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    
    canvas.drawLine(
      Offset(0, rect.top),
      Offset(game.screenWidth, rect.top),
      borderPaint,
    );
  }
}