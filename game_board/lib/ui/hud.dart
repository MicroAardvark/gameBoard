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

  List<GameButton> _bettingBtns = [];
  List<GameButton> _playingBtns = [];
  List<GameButton> _gameOverBtns = [];

  bool _hudPanelShown = false;
  bool _useSideMenuForBetting = true; // NEW: Flag to use side menu instead of buttons

  Future<void> setupHUD() async {
    removeHUD();
    await createHUD();
  }

  Future<void> createHUD() async {
    if (_hudPanelShown) return;

    // Simple left margin - button left edge will be at this position
    final leftMargin = 16.0;
    
    const buttonSpacing = 0.12;
    const baseY = 0.35;
    
    _playingBtns = [
      GameButton(
        position: Vector2(
          leftMargin,  // Simple! No calculations needed
          game.screenHeight * baseY
        ),
        size: Vector2(game.buttonWidth, game.buttonHeight),
        text: 'Hit',
        onTap: () => game.hit(),
      )..priority = 100,
      GameButton(
        position: Vector2(
          leftMargin,
          game.screenHeight * (baseY + buttonSpacing)
        ),
        size: Vector2(game.buttonWidth, game.buttonHeight),
        text: 'Stand',
        onTap: () => game.stand(),
      )..priority = 100,
      GameButton(
        position: Vector2(
          leftMargin,
          game.screenHeight * (baseY + buttonSpacing * 2)
        ),
        size: Vector2(game.buttonWidth, game.buttonHeight),
        text: 'Double',
        onTap: () => game.doubleDown(),
      )..priority = 100,
    ];

    _gameOverBtns = [
      GameButton(
        position: Vector2(
          leftMargin,
          game.screenHeight * 0.35
        ),
        size: Vector2(game.buttonWidth, game.buttonHeight),
        text: 'New Round',
        onTap: () => game.newRound(),
      )..priority = 100,
    ];

    game.addAll(_playingBtns + _gameOverBtns);
    _hudPanelShown = true;

    updateHudVisibility();
  }

  void removeHUD() {
    // Remove buttons
    for (final btn in _playingBtns + _gameOverBtns) {
      btn.removeFromParent();
    }
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

    // Simply show/hide buttons based on game state
    // No HUD text updates needed (all in AppBar now)
    if (g.gameState == GameState.betting) {
      _showOnlyButtons(const []);  // Hide all buttons during betting
    } else if (g.gameState == GameState.playing) {
      _showOnlyButtons(_playingBtns);
    } else if (g.gameState == GameState.dealerTurn) {
      _showOnlyButtons(const []);
    } else if (g.gameState == GameState.gameOver) {
      _showOnlyButtons(_gameOverBtns);
    }
  }

  void repositionButtons() {
    final leftMargin = 16.0;
    
    const buttonSpacing = 0.12;
    const baseY = 0.35;
    
    // Reposition playing buttons
    for (int i = 0; i < _playingBtns.length; i++) {
      _playingBtns[i].position = Vector2(
        leftMargin,
        game.screenHeight * (baseY + buttonSpacing * i)
      );
      _playingBtns[i].size = Vector2(game.buttonWidth, game.buttonHeight);
    }
    
    // Reposition game over buttons
    for (int i = 0; i < _gameOverBtns.length; i++) {
      _gameOverBtns[i].position = Vector2(
        leftMargin,
        game.screenHeight * (baseY + buttonSpacing * i)
      );
      _gameOverBtns[i].size = Vector2(game.buttonWidth, game.buttonHeight);
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