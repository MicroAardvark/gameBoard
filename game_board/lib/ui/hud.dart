// ====================================
// lib/ui/hud.dart
// HUD for single-player blackjack - UPDATED to work with betting side menu
// ====================================
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../games/blackjack_game.dart';
import '../components/text_component.dart';
import '../components/button_component.dart';
import '../models/enums.dart';
import '../theme/app_theme.dart';

class HudManager {
  final BlackjackGame game;

  HudManager(this.game);

  HudPanel? hudPanel;

  InfoTextComponent? bankrollText;
  InfoTextComponent? betText;
  InfoTextComponent? winsText;
  InfoTextComponent? gameResultText;
  InfoTextComponent? playerHandText;
  InfoTextComponent? dealerHandText;

  late List<GameButton> _bettingBtns; // Hidden when using side menu
  late List<GameButton> _playingBtns;
  late List<GameButton> _gameOverBtns;

  bool _hudPanelShown = false;
  bool _useSideMenuForBetting = true; // NEW: Flag to use side menu instead of buttons

  Future<void> setupHUD() async {
    removeHUD();
    await createHUD();
  }

  Future<void> createHUD() async {
    if (_hudPanelShown) return;

    hudPanel = HudPanel(game: game)..priority = BlackjackGame.layerHudPanel;
    game.add(hudPanel!);

    // Info text
    bankrollText = InfoTextComponent(
      text: 'Bankroll',
      position: Vector2(20, game.screenHeight - game.hudPanelHeight + 18),
      fontSize: game.fontSize,
    );
    betText = InfoTextComponent(
      text: 'Bet',
      position: Vector2(20, game.screenHeight - game.hudPanelHeight + 18 + game.fontSize + 6),
      fontSize: game.fontSize,
    );
    winsText = InfoTextComponent(
      text: 'W/L',
      position: Vector2(20, game.screenHeight - game.hudPanelHeight + 18 + (game.fontSize + 6) * 2),
      fontSize: game.fontSize,
    );
    gameResultText = InfoTextComponent(
      text: '',
      position: Vector2(20, 20),
      fontSize: game.fontSize,
    );
    playerHandText = InfoTextComponent(
      text: 'Player Hand',
      position: Vector2(20, 80),
      fontSize: game.fontSize,
    );
    dealerHandText = InfoTextComponent(
      text: 'Dealer Hand',
      position: Vector2(20, 120),
      fontSize: game.fontSize,
    );

    hudPanel!.addAll([
      bankrollText!,
      betText!,
      winsText!,
      gameResultText!,
      playerHandText!,
      dealerHandText!,
    ]);

    // Betting buttons - These are now hidden since we use the side menu
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
          game.startGame();
        },
      ),
    ];

    // Playing buttons
    _playingBtns = [
      GameButton(
        position: Vector2(game.screenWidth * 0.35, game.screenHeight - 70),
        size: Vector2(game.buttonWidth, game.buttonHeight),
        text: 'Hit',
        onTap: () => game.hit(),
      ),
      GameButton(
        position: Vector2(game.screenWidth * 0.55, game.screenHeight - 70),
        size: Vector2(game.buttonWidth, game.buttonHeight),
        text: 'Stand',
        onTap: () => game.stand(),
      ),
      GameButton(
        position: Vector2(game.screenWidth * 0.75, game.screenHeight - 70),
        size: Vector2(game.buttonWidth, game.buttonHeight),
        text: 'Double',
        onTap: () => game.doubleDown(),
      ),
    ];

    // Game over buttons
    _gameOverBtns = [
      GameButton(
        position: Vector2(game.screenWidth * 0.5, game.screenHeight - 70),
        size: Vector2(game.buttonWidth, game.buttonHeight),
        text: 'New Round',
        onTap: () => game.newRound(),
      ),
    ];

    // Add all buttons to the HUD panel but hide them initially
    hudPanel!.addAll(_bettingBtns + _playingBtns + _gameOverBtns);
    _hudPanelShown = true;

    updateHudVisibility();
  }

  void removeHUD() {
    hudPanel?.removeFromParent();
    hudPanel = null;
    _hudPanelShown = false;
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

  void updateHudVisibility() {
    final g = game;

    if (g.gameState == GameState.betting) {
      // IMPORTANT: Hide betting buttons since we're using the side menu
      if (_useSideMenuForBetting) {
        _showOnlyButtons(const []);
      } else {
        // If not using side menu, show betting buttons
        _showOnlyButtons(_bettingBtns);
      }
    } else if (g.gameState == GameState.playing) {
      _showOnlyButtons(_playingBtns);
    } else if (g.gameState == GameState.dealerTurn) {
      _showOnlyButtons(const []);
    } else if (g.gameState == GameState.gameOver) {
      _showOnlyButtons(_gameOverBtns);
    }
  }

  void updateGameResult(String result, {bool isWin = false}) {
    gameResultText?.text = result;
    if (isWin) {
      gameResultText?.textRenderer = TextPaint(
        style: TextStyle(
          fontFamily: 'Montserrat',
          color: AppColors.primaryNavyLight,
          fontSize: game.largeFontSize,
          fontWeight: FontWeight.bold,
        ),
      );
    } else {
      gameResultText?.textRenderer = TextPaint(
        style: TextStyle(
          fontFamily: 'Montserrat',
          color: AppColors.textPrimary,
          fontSize: game.fontSize,
          fontWeight: FontWeight.normal,
        ),
      );
    }
  }
}

// ===========================================
// HUD Panel Background Component
// ===========================================
class HudPanel extends PositionComponent {
  final BlackjackGame game;
  
  HudPanel({required this.game});

  @override
  void render(Canvas canvas) {
    final rect = Rect.fromLTWH(
      0,
      game.screenHeight - game.hudPanelHeight,
      game.screenWidth,
      game.hudPanelHeight,
    );
    
    final paint = Paint()
      ..color = AppColors.primaryNavyDark.withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;
    
    canvas.drawRect(rect, paint);
  }
}