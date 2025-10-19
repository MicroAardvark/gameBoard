import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../games/blackjack_game.dart';
import '../components/text_component.dart';
import '../components/button_component.dart';
import '../models/enums.dart';

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

  late List<GameButton> _bettingBtns;
  late List<GameButton> _playingBtns;
  late List<GameButton> _gameOverBtns;

  bool _hudPanelShown = false;

  // ---------------------------
  // The method blackjack_game.dart expects
  // ---------------------------
  Future<void> setupHUD() async {
    removeHUD();
    await createHUD();
  }

  // ---------------------------
  // Create / Remove HUD
  // ---------------------------
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

    // --- Buttons ---
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

    _gameOverBtns = [
      GameButton(
        position: Vector2(game.screenWidth * 0.5, game.screenHeight - 70),
        size: Vector2(game.buttonWidth, game.buttonHeight),
        text: 'New Round',
        onTap: () => game.newRound(),
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

  // ---------------------------
  // Visibility & state wiring
  // ---------------------------
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
      final canCancel = g.stagedBet > 0;
      final canConfirm = g.stagedBet > 0 || g.currentBet > 0;

      for (final b in _bettingBtns) {
        b.hidden = false;
      }
      _bettingBtns[0].isEnabled = canCancel;
      _bettingBtns[0].hidden = !canCancel; // hide Cancel if not usable
      _bettingBtns[1].isEnabled = canConfirm;

      for (final b in _playingBtns) {
        b.hidden = true;
        b.isEnabled = false;
      }
      for (final b in _gameOverBtns) {
        b.hidden = true;
        b.isEnabled = false;
      }
    } else if (g.gameState == GameState.playing) {
      _showOnlyButtons(_playingBtns);
    } else if (g.gameState == GameState.dealerTurn) {
      _showOnlyButtons(const []);
    } else if (g.gameState == GameState.gameOver) {
      _showOnlyButtons(_gameOverBtns);
    }
  }
}

// -----------------------------
// HudPanel: semi-transparent background strip
// -----------------------------
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
      ..color = Colors.black.withValues(alpha:(0.4))
      ..style = PaintingStyle.fill;
    canvas.drawRect(rect, paint);
  }
}
