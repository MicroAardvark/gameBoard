// ====================================
// lib/ui/hud.dart
// HUD (Heads-Up Display) for single-player Blackjack
// UPDATED: Refactored to work alongside the betting side menu
// ====================================
//
// HudManager — manages all in-game UI buttons and text overlays for
// the single-player Blackjack Flame game instance.
//
// Responsibilities:
//   - Creating and positioning the Hit, Stand, Double, and New Round buttons.
//   - Showing or hiding button groups based on the current [GameState].
//   - Repositioning buttons when the screen size changes (e.g., orientation change).
//   - Updating the game result text and its style (win vs. loss).
//
// Design Decisions:
//   - Betting buttons are handled externally by a Flutter side menu widget,
//     not by this HUD. The [_useSideMenuForBetting] flag documents this intent.
//   - Stats (bankroll, wins) are displayed in the AppBar rather than as
//     Flame text components, simplifying the HUD considerably.
//   - All buttons are added to the Flame game tree (via [game.addAll]) rather
//     than the Flutter widget tree, ensuring they respond to the Flame
//     tap/input pipeline.
//
// Button Layout:
//   Buttons are positioned along the left edge of the screen at a fixed
//   x-offset (16px left margin), stacked vertically with relative y-positions
//   calculated as a fraction of the screen height. This ensures layout
//   scales correctly across different device screen sizes.

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../games/blackjack_game.dart';
import '../components/text_component.dart';
import '../components/button_component.dart';
import '../models/enums.dart';
import '../theme/app_theme.dart';

// ============================================================================
// HUD MANAGER
// ============================================================================

class HudManager {
  /// Reference to the parent Blackjack game, used to access screen dimensions,
  /// font sizes, and game action methods (hit, stand, etc.).
  final BlackjackGame game;

  HudManager(this.game);

  // ---- HUD Component References ----
  // Nullable references allow us to check whether components have been created
  // before attempting to update or remove them.

  /// The translucent panel rendered behind the HUD area (currently unused
  /// after the AppBar migration but retained for potential future use).
  HudPanel? hudPanel;

  // Stats text components — kept as references for dynamic updates.
  // Currently unused as these values are displayed in the AppBar.
  InfoTextComponent? bankrollText;
  InfoTextComponent? betText;
  InfoTextComponent? winsText;

  /// Displays the round result message (e.g., "You Win!", "Dealer Wins").
  InfoTextComponent? gameResultText;

  /// Displays the player's current hand value.
  InfoTextComponent? playerHandText;

  /// Displays the dealer's current hand value.
  InfoTextComponent? dealerHandText;

  // ---- Button Lists ----
  // Buttons are grouped by the game phase they belong to.
  // This allows [_showOnlyButtons] to efficiently toggle visibility.

  /// Buttons shown during the betting phase.
  /// Currently empty — betting is handled by a Flutter side menu.
  List<GameButton> _bettingBtns = [];

  /// Buttons shown during the player's turn: Hit, Stand, Double.
  List<GameButton> _playingBtns = [];

  /// Buttons shown after a round ends: New Round.
  List<GameButton> _gameOverBtns = [];

  // ---- State Flags ----

  /// Whether the HUD buttons have been added to the Flame component tree.
  bool _hudPanelShown = false;

  /// Flag indicating that the betting phase UI is managed by a Flutter side
  /// menu widget rather than by buttons in this HUD. When true, no betting
  /// buttons are shown during [GameState.betting].
  bool _useSideMenuForBetting = true;

  // ============================================================================
  // HUD LIFECYCLE
  // ============================================================================

  /// Tears down the existing HUD and rebuilds it from scratch.
  ///
  /// Called when the game is reset or the screen dimensions change
  /// significantly enough to require a full re-layout.
  Future<void> setupHUD() async {
    removeHUD();
    await createHUD();
  }

  /// Creates all button components and adds them to the Flame game tree.
  ///
  /// Buttons are initially created in their correct positions and the correct
  /// subset is made visible via [updateHudVisibility] at the end of this method.
  ///
  /// Layout constants:
  ///   - [leftMargin]: Fixed 16px offset from the left edge of the screen.
  ///   - [buttonSpacing]: Vertical gap between buttons as a fraction of screen height.
  ///   - [baseY]: The y-position of the first button as a fraction of screen height.
  Future<void> createHUD() async {
    // Guard against creating duplicate HUD components.
    if (_hudPanelShown) return;

    // Left edge of all buttons, measured from the screen left in logical pixels.
    final leftMargin = 16.0;

    // Fractional vertical gap between stacked buttons (12% of screen height).
    const buttonSpacing = 0.12;

    // Y-position of the first button in the stack (35% down the screen).
    const baseY = 0.35;

    // ---- Playing Phase Buttons (Hit / Stand / Double) ----
    // Shown during [GameState.playing] when the player is making decisions.
    _playingBtns = [
      GameButton(
        position: Vector2(
          leftMargin,
          game.screenHeight * baseY,
        ),
        size: Vector2(game.buttonWidth, game.buttonHeight),
        text: 'Hit',
        onTap: () => game.hit(), // Requests an additional card.
      )..priority = 100,

      GameButton(
        position: Vector2(
          leftMargin,
          game.screenHeight * (baseY + buttonSpacing),
        ),
        size: Vector2(game.buttonWidth, game.buttonHeight),
        text: 'Stand',
        onTap: () => game.stand(), // Ends the player's turn.
      )..priority = 100,

      GameButton(
        position: Vector2(
          leftMargin,
          game.screenHeight * (baseY + buttonSpacing * 2),
        ),
        size: Vector2(game.buttonWidth, game.buttonHeight),
        text: 'Double',
        onTap: () => game.doubleDown(), // Doubles the bet and takes exactly one more card.
      )..priority = 100,
    ];

    // ---- Game Over Button (New Round) ----
    // Shown during [GameState.gameOver] after the round result is shown.
    _gameOverBtns = [
      GameButton(
        position: Vector2(
          leftMargin,
          game.screenHeight * 0.35,
        ),
        size: Vector2(game.buttonWidth, game.buttonHeight),
        text: 'New Round',
        onTap: () => game.newRound(), // Resets the table for the next round.
      )..priority = 100,
    ];

    // Add all buttons to the Flame component tree.
    // Visibility is then controlled individually by [updateHudVisibility].
    game.addAll(_playingBtns + _gameOverBtns);
    _hudPanelShown = true;

    // Apply the correct initial visibility based on the current game state.
    updateHudVisibility();
  }

  /// Removes all HUD buttons from the Flame component tree.
  ///
  /// Called before rebuilding the HUD (in [setupHUD]) or when
  /// navigating away from the game screen.
  void removeHUD() {
    for (final btn in _playingBtns + _gameOverBtns) {
      btn.removeFromParent();
    }
    _hudPanelShown = false;
  }

  // ============================================================================
  // BUTTON VISIBILITY
  // ============================================================================

  /// Hides all buttons, then shows and enables only the [needed] subset.
  ///
  /// This is the core visibility-toggle mechanism. Every button is disabled
  /// and hidden first to ensure a clean state, then the required buttons are
  /// made active. Using the [isEnabled] flag prevents accidental taps on
  /// buttons that are hidden but still technically in the component tree.
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

  /// Updates button visibility to match the current [GameState].
  ///
  /// Should be called whenever the game state changes. The game screen is
  /// responsible for triggering this after state transitions.
  ///
  ///   [GameState.betting]    → All buttons hidden (betting handled by side menu)
  ///   [GameState.playing]    → Hit, Stand, Double shown
  ///   [GameState.dealerTurn] → All buttons hidden (no player input needed)
  ///   [GameState.gameOver]   → New Round button shown
  void updateHudVisibility() {
    final g = game;

    if (g.gameState == GameState.betting) {
      // Betting is handled by the Flutter side menu; no HUD buttons are needed.
      _showOnlyButtons(const []);
    } else if (g.gameState == GameState.playing) {
      _showOnlyButtons(_playingBtns);
    } else if (g.gameState == GameState.dealerTurn) {
      // Dealer plays automatically; player cannot act during this phase.
      _showOnlyButtons(const []);
    } else if (g.gameState == GameState.gameOver) {
      _showOnlyButtons(_gameOverBtns);
    }
  }

  // ============================================================================
  // LAYOUT / REPOSITIONING
  // ============================================================================

  /// Recalculates and applies button positions after a screen size change.
  ///
  /// Called when the game viewport is resized (e.g., orientation change or
  /// window resize on desktop/web). Applies the same layout constants as
  /// [createHUD] to maintain consistent proportional positioning.
  void repositionButtons() {
    final leftMargin = 16.0;

    const buttonSpacing = 0.12;
    const baseY = 0.35;

    // Reposition each playing button using its index in the stack.
    for (int i = 0; i < _playingBtns.length; i++) {
      _playingBtns[i].position = Vector2(
        leftMargin,
        game.screenHeight * (baseY + buttonSpacing * i),
      );
      _playingBtns[i].size = Vector2(game.buttonWidth, game.buttonHeight);
    }

    // Reposition each game-over button using its index in the stack.
    for (int i = 0; i < _gameOverBtns.length; i++) {
      _gameOverBtns[i].position = Vector2(
        leftMargin,
        game.screenHeight * (baseY + buttonSpacing * i),
      );
      _gameOverBtns[i].size = Vector2(game.buttonWidth, game.buttonHeight);
    }
  }

  // ============================================================================
  // GAME RESULT TEXT
  // ============================================================================

  /// Updates the game result text and applies win/loss styling.
  ///
  /// Win results are displayed in the primary navy light colour at a larger
  /// font size to emphasise the positive outcome. Loss results use the
  /// default text colour and standard font size to avoid over-emphasising
  /// a negative result.
  ///
  /// Parameters:
  ///   - [result]: The result string to display (e.g., "You Win! +£50").
  ///   - [isWin]: If `true`, applies the win styling; defaults to loss styling.
  void updateGameResult(String result, {bool isWin = false}) {
    gameResultText?.text = result;

    if (isWin) {
      // Win: larger text in the highlighted navy colour.
      gameResultText?.textRenderer = TextPaint(
        style: TextStyle(
          fontFamily: 'Montserrat',
          color: AppColors.primaryNavyLight,
          fontSize: game.largeFontSize,
          fontWeight: FontWeight.bold,
        ),
      );
    } else {
      // Loss or neutral: standard text styling.
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

// ============================================================================
// HUD PANEL BACKGROUND COMPONENT
// ============================================================================

/// A Flame [PositionComponent] that renders a semi-transparent dark panel
/// across the bottom of the game screen.
///
/// This provides a subtle visual separation between the game canvas (cards,
/// table) and the HUD area (buttons, stats text). The panel's height is
/// controlled by [BlackjackGame.hudPanelHeight].
///
/// Note: This component is currently retained in the codebase but may not
/// be actively added to the game tree since stats have moved to the AppBar.
class HudPanel extends PositionComponent {
  /// Reference to the game for accessing screen dimension properties.
  final BlackjackGame game;

  HudPanel({required this.game});

  /// Renders the semi-transparent panel rectangle on the canvas.
  ///
  /// Positioned at the bottom of the screen, spanning the full width.
  /// Uses a 40% opacity dark navy to subtly darken the area without
  /// fully obscuring the table background beneath.
  @override
  void render(Canvas canvas) {
    final rect = Rect.fromLTWH(
      0,
      game.screenHeight - game.hudPanelHeight, // Top edge of the panel.
      game.screenWidth,
      game.hudPanelHeight,
    );

    final paint = Paint()
      ..color = AppColors.primaryNavyDark.withValues(alpha: 0.4) // 40% opacity overlay.
      ..style = PaintingStyle.fill;

    canvas.drawRect(rect, paint);
  }
}