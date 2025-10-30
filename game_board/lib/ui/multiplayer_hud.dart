// ====================================
// lib/ui/multiplayer_hud.dart
// HUD for multiplayer blackjack game - WITH TURN-BASED BETTING SUPPORT
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

  // Text components - MATCHING SINGLE PLAYER
  InfoTextComponent? bankrollText;
  InfoTextComponent? betText;
  InfoTextComponent? gameResultText;  // Top left like single player
  InfoTextComponent? myHandText;      // Below game result (was playerHandText)
  InfoTextComponent? dealerHandText;  // Below player hand
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

    // UPDATED: Match single player layout exactly
    // Game result at top left (20, 20) like single player
    gameResultText = InfoTextComponent(
      text: '',
      position: Vector2(20, 20),
      fontSize: game.fontSize,
    );

    // Player hand below game result (20, 80) like single player  
    myHandText = InfoTextComponent(
      text: 'Player Hand',
      position: Vector2(20, 80),
      fontSize: game.fontSize,
    );

    // Dealer hand below player hand (20, 120) like single player
    dealerHandText = InfoTextComponent(
      text: 'Dealer Hand',
      position: Vector2(20, 120),
      fontSize: game.fontSize,
    );

    // Turn indicator (center top) - multiplayer specific
    turnIndicatorText = InfoTextComponent(
      text: '',
      position: Vector2(game.screenWidth / 2, 160),
      fontSize: game.largeFontSize,
    );
    turnIndicatorText!.anchor = Anchor.center;

    // Waiting status text (center of screen)
    waitingStatusText = InfoTextComponent(
      text: 'Waiting for players to ready up...',
      position: Vector2(game.screenWidth / 2, game.screenHeight / 2 - 100),
      fontSize: game.largeFontSize,
    );
    waitingStatusText!.anchor = Anchor.center;

    // Bottom left info - MATCHING SINGLE PLAYER
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

    // Room info (top right corner) - multiplayer specific
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

    // Add text components to HUD panel like single player
    hudPanel!.addAll([
      bankrollText!,
      betText!,
      gameResultText!,
      myHandText!,
      dealerHandText!,
    ]);
    
    // Add non-panel elements directly to game
    game.addAll([
      roomInfoText!,
      playerCountText!,
      waitingStatusText!,
      turnIndicatorText!,
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
    // BETTING BUTTONS - STACKED VERTICALLY ON LEFT SIDE
    // ===========================================
    final double leftButtonX = game.screenWidth * 0.15;  // 15% from left edge
    final double buttonSpacing = game.screenHeight * 0.10;  // 10% vertical spacing
    final double startY = game.screenHeight * 0.35;  // Start position

    _bettingBtns = [
      // Start button at top (index 0)
      GameButton(
        position: Vector2(leftButtonX, startY),
        size: Vector2(game.buttonWidth, game.buttonHeight),
        text: 'Start',
        onTap: () {
          game.startRound();
        },
      )..priority = MultiplayerBlackjackGame.layerHudPanel + 1,
      // Confirm button in middle (index 1)
      GameButton(
        position: Vector2(leftButtonX, startY + buttonSpacing),
        size: Vector2(game.buttonWidth, game.buttonHeight),
        text: 'Confirm',
        onTap: () async {
          await game.confirmStagedToPot();
        },
      )..priority = MultiplayerBlackjackGame.layerHudPanel + 1,
      // Cancel button at bottom (index 2)
      GameButton(
        position: Vector2(leftButtonX, startY + buttonSpacing * 2),
        size: Vector2(game.buttonWidth, game.buttonHeight),
        text: 'Cancel',
        onTap: () {
          if (game.stagedBet > 0) {
            game.cancelStaged();
          }
        },
      )..priority = MultiplayerBlackjackGame.layerHudPanel + 1,
    ];

    // ===========================================
    // PLAYING BUTTONS - SAME POSITION AS BETTING BUTTONS
    // ===========================================
    _playingBtns = [
      // Hit button in same position as Confirm
      GameButton(
        position: Vector2(leftButtonX, startY + buttonSpacing),
        size: Vector2(game.buttonWidth, game.buttonHeight),
        text: 'Hit',
        onTap: () => game.hit(),
      )..priority = MultiplayerBlackjackGame.layerHudPanel + 1,
      // Stand button in same position as Cancel
      GameButton(
        position: Vector2(leftButtonX, startY + buttonSpacing * 2),
        size: Vector2(game.buttonWidth, game.buttonHeight),
        text: 'Stand',
        onTap: () => game.stand(),
      )..priority = MultiplayerBlackjackGame.layerHudPanel + 1,
      // Double button below Stand
      GameButton(
        position: Vector2(leftButtonX, startY + buttonSpacing * 3),
        size: Vector2(game.buttonWidth, game.buttonHeight),
        text: 'Double',
        onTap: () => game.doubleDown(),
      )..priority = MultiplayerBlackjackGame.layerHudPanel + 1,
    ];

    // ===========================================
    // GAME OVER BUTTONS - SAME POSITION AS BETTING BUTTONS
    // ===========================================
    _gameOverBtns = [
      // Next Round button in same position as Confirm
      GameButton(
        position: Vector2(leftButtonX, startY + buttonSpacing),
        size: Vector2(game.buttonWidth, game.buttonHeight),
        text: 'Next Round',
        onTap: () => game.newRound(),
      )..priority = MultiplayerBlackjackGame.layerHudPanel + 1,
      // Leave button in same position as Cancel
      GameButton(
        position: Vector2(leftButtonX, startY + buttonSpacing * 2),
        size: Vector2(game.buttonWidth, game.buttonHeight),
        text: 'Leave',
        onTap: () => game.leaveRoom(),
      )..priority = MultiplayerBlackjackGame.layerHudPanel + 1,
    ];

    // 🔧 FIX: Don't add any buttons initially - let updateHudVisibility handle it
    
    _hudPanelShown = true;

    updateHudVisibility();
  }

  void removeHUD() {
    hudPanel?.removeFromParent();
    hudPanel = null;
    
    roomInfoText?.removeFromParent();
    playerCountText?.removeFromParent();
    waitingStatusText?.removeFromParent();
    turnIndicatorText?.removeFromParent();
    
    // Remove all buttons
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
  // Update HUD Visibility Based on Game State - WITH TURN-BASED BETTING
  // ===========================================
  void updateHudVisibility() {
    final g = game;
    g.updateChipPaletteState();
    
    if (g.gameState == GameState.waiting) {
      _showOnlyButtons(_waitingBtns);
      if (!game.children.contains(waitingStatusText)) {
        game.add(waitingStatusText!);
      }
      turnIndicatorText?.removeFromParent();
      gameResultText?.text = '';
    } 
    else if (g.gameState == GameState.betting) {
      _showOnlyButtons(_bettingBtns);
      waitingStatusText?.removeFromParent();
      
      // Show turn indicator during betting phase
      if (!game.children.contains(turnIndicatorText)) {
        game.add(turnIndicatorText!);
      }
      
      gameResultText?.text = '';
      
      if (_bettingBtns.length >= 3) {
        // Start button (index 0) - only for host, only when all bets placed
        _bettingBtns[0].isEnabled = g.currentBet > 0 && g.isHost && g.allBetsPlaced;
        _bettingBtns[0].hidden = !g.isHost;
        
        // 🔧 FIX: Confirm button (index 1) - ONLY when it's your turn AND you have staged chips
        _bettingBtns[1].isEnabled = g.stagedBet > 0 && g.isMyTurn;
  
        // Cancel button (index 2)
        _bettingBtns[2].isEnabled = g.stagedBet > 0;
        _bettingBtns[2].hidden = g.stagedBet <= 0;
      }
    } 
    else if (g.gameState == GameState.playing) {
      waitingStatusText?.removeFromParent();
      if (!game.children.contains(turnIndicatorText)) {
        game.add(turnIndicatorText!);
      }
      if (g.isMyTurn) {
        _showOnlyButtons(_playingBtns);
      } else {
        _showOnlyButtons(const []);
      }
    } 
    else if (g.gameState == GameState.dealerTurn) {
      _showOnlyButtons(const []);
      if (!game.children.contains(turnIndicatorText)) {
        game.add(turnIndicatorText!);
      }
    } 
    else if (g.gameState == GameState.gameOver) {
      _showOnlyButtons(_gameOverBtns);
      turnIndicatorText?.removeFromParent();
      
      // 🔧 NEW: Hide/show buttons based on host status
      if (_gameOverBtns.length >= 2) {
        // Next Round button (index 0) - only for host
        _gameOverBtns[0].hidden = !g.isHost;
        
        // Leave button (index 1) - always visible
        _gameOverBtns[1].hidden = false;
      }
    }
  }

  // 🔧 FIX: Actually add/remove buttons from the parent instead of just hiding them
  void _showOnlyButtons(List<GameButton> needed) {
    final all = _waitingBtns + _bettingBtns + _playingBtns + _gameOverBtns;
    
    // Remove all buttons first
    for (final b in all) {
      if (b.parent != null) {
        b.removeFromParent();
      }
    }
    
    // Add only the needed buttons
    for (final b in needed) {
      if (_waitingBtns.contains(b)) {
        game.add(b);  // Waiting buttons go on game
      } else {
        hudPanel?.add(b);  // Other buttons go on hudPanel
      }
      b.hidden = false;
      b.isEnabled = true;
    }
  }

  // ===========================================
  // Update Turn Indicator - WITH BETTING PHASE SUPPORT
  // ===========================================
  void updateTurnIndicator() {
    if (game.gameState == GameState.waiting) {
      turnIndicatorText?.text = '';
      return;
    }

    // NEW: Show turn indicator during betting phase
    if (game.gameState == GameState.betting) {
      if (game.isMyTurn && game.currentBet == 0) {
        turnIndicatorText?.text = '🎯 YOUR TURN TO BET';
        turnIndicatorText?.textRenderer = TextPaint(
          style: TextStyle(
            color: Colors.greenAccent,
            fontSize: game.largeFontSize,
            fontWeight: FontWeight.bold,
          ),
        );
      } else if (game.currentBet > 0) {
        turnIndicatorText?.text = '✅ Bet placed - waiting for others';
        turnIndicatorText?.textRenderer = TextPaint(
          style: TextStyle(
            color: Colors.yellow,
            fontSize: game.fontSize,
            fontWeight: FontWeight.normal,
          ),
        );
      } else if (game.currentTurnPlayerId.isNotEmpty) {
        final currentPlayer = game.otherPlayers[game.currentTurnPlayerId];
        if (currentPlayer != null) {
          turnIndicatorText?.text = '⏳ ${currentPlayer.username} is betting';
          turnIndicatorText?.textRenderer = TextPaint(
            style: TextStyle(
              color: Colors.orangeAccent,
              fontSize: game.fontSize,
              fontWeight: FontWeight.normal,
            ),
          );
        } else {
          turnIndicatorText?.text = '';
        }
      }
      return;
    }

    // Playing phase turn indicators
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
  // Update Game Result Display - MATCHING SINGLE PLAYER
  // ===========================================
  void updateGameResult(String result, {bool isWin = false}) {
    gameResultText?.text = result;
    
    Color resultColor = Colors.white;
    if (result.toLowerCase().contains('win') || result.toLowerCase().contains('blackjack')) {
      resultColor = Colors.green;
    } else if (result.toLowerCase().contains('push')) {
      resultColor = Colors.yellow;
    } else if (result.toLowerCase().contains('dealer') || result.toLowerCase().contains('bust')) {
      resultColor = Colors.red;
    }

    gameResultText?.textRenderer = TextPaint(
      style: TextStyle(
        color: resultColor,
        fontSize: game.fontSize,
        fontWeight: FontWeight.normal,
      ),
    );
  }

  // ===========================================
  // Update Room Info
  // ===========================================
  void updateRoomInfo(String roomId, int playerCount, int maxPlayers) {
    roomInfoText?.text = '${roomId.substring(0, 8)}...';
    playerCountText?.text = '$playerCount/$maxPlayers';
  }
}

// ===========================================
// HUD Panel Background - MATCHING SINGLE PLAYER
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