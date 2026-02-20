// ====================================
// lib/widgets/betting_side_menu.dart
// Collapsible side menu for chip-based betting in Blackjack
//
// PURPOSE:
//   Provides a slide-in panel from the left edge of the screen for placing
//   bets using virtual casino chips. Replaces the earlier modal popup approach
//   to allow players to see the game table whilst deciding their stake.
//
// FEATURES:
//   - Six chip denominations: £1, £5, £10, £25, £50, £100
//   - Greyed-out (disabled) chips when adding them would exceed the bankroll
//     or the table's maximum bet limit
//   - Auto-fills the minimum bet on mount so the player is never below the
//     table minimum without realising
//   - Undo (remove last chip) and Clear (reset entire bet) controls
//   - Confirm button pinned to the footer so it is always reachable without
//     scrolling
//   - Responsive layout: narrower in portrait, wider in landscape
//
// USAGE:
//   Wrap in a Stack and reveal/hide with an AnimatedContainer or Drawer.
//   Example:
//     BettingSideMenu(
//       currentBankroll: 500.0,
//       minimumBet: 10.0,
//       maximumBet: 200.0,
//       onConfirm: (amount) => _placeBet(amount),
//       onClose: () => setState(() => _showBetting = false),
//     )
// ====================================

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A full-height side panel that allows the player to build a bet by tapping
/// chip buttons.  The widget is purely presentational – all bet logic (e.g.
/// deducting from bankroll) is handled by the parent via [onConfirm].
class BettingSideMenu extends StatefulWidget {
  /// The player's current available funds.  Used to prevent over-betting.
  final double currentBankroll;

  /// Optional table minimum.  When set, chips are automatically added on
  /// initialisation to reach this amount, and the confirm button is disabled
  /// until the staged bet meets the minimum.
  final double? minimumBet;

  /// Optional table maximum.  Chips that would push the bet over this limit
  /// are visually disabled.
  final double? maximumBet;

  /// Called with the final bet amount when the player taps "Confirm Bet".
  final Function(double betAmount) onConfirm;

  /// Optional callback invoked when the close (✕) button is pressed so the
  /// parent widget can hide the panel.
  final VoidCallback? onClose;

  const BettingSideMenu({
    super.key,
    required this.currentBankroll,
    this.minimumBet,
    this.maximumBet,
    required this.onConfirm,
    this.onClose,
  });

  @override
  State<BettingSideMenu> createState() => _BettingSideMenuState();
}

class _BettingSideMenuState extends State<BettingSideMenu> {
  // ─── Constants ────────────────────────────────────────────────────────────

  /// Available chip denominations displayed in the grid, ordered ascending so
  /// the greedy minimum-bet algorithm can iterate from the largest denomination
  /// down (see [_autoAddMinimumBet]).
  final List<double> chipValues = [1, 5, 10, 25, 50, 100];

  // ─── State ────────────────────────────────────────────────────────────────

  /// Running total of all chips currently staged (not yet confirmed).
  double stagedBet = 0.0;

  /// Ordered list of chip values that make up the current staged bet.
  /// Used by [_undoLastChip] to remove chips in reverse order.
  final List<double> stagedChips = [];

  // ─── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    // Pre-populate the bet with the minimum if one is set, so the player does
    // not have to manually reach the minimum themselves.
    if (widget.minimumBet != null && widget.minimumBet! > 0) {
      _autoAddMinimumBet();
    }
  }

  // ─── Bet Logic ────────────────────────────────────────────────────────────

  /// Uses a greedy algorithm (largest chip first) to automatically add chips
  /// until the staged bet reaches [widget.minimumBet].
  ///
  /// This mirrors how a dealer would push chips across a table – using the
  /// fewest chips necessary to reach the required total.
  void _autoAddMinimumBet() {
    if (widget.minimumBet == null) return;
    double remaining = widget.minimumBet!;

    // Iterate from the highest chip down to build the minimum bet efficiently.
    for (int i = chipValues.length - 1; i >= 0; i--) {
      final chipValue = chipValues[i];
      // Keep adding this denomination while it still fits.
      while (remaining >= chipValue && _canAddChip(chipValue)) {
        _addChip(chipValue);
        remaining -= chipValue;
      }
    }
  }

  /// Returns `true` if adding [chipValue] to the staged bet would not exceed
  /// either the player's bankroll or the table's maximum bet.
  bool _canAddChip(double chipValue) {
    final newTotal = stagedBet + chipValue;

    // Prevent the player from betting more than they have.
    if (newTotal > widget.currentBankroll) return false;

    // Enforce the table maximum when one is configured.
    if (widget.maximumBet != null && newTotal > widget.maximumBet!) return false;

    return true;
  }

  /// Adds a chip of [chipValue] to the staged bet, or shows an error snackbar
  /// if the chip cannot be added (e.g. bankroll exceeded).
  void _addChip(double chipValue) {
    if (!_canAddChip(chipValue)) {
      _showError('Cannot add chip: ${_getErrorReason(chipValue)}');
      return;
    }

    setState(() {
      stagedBet += chipValue;
      stagedChips.add(chipValue); // Track chip order for undo support.
    });
  }

  /// Returns a human-readable explanation of why [chipValue] cannot be added.
  /// Used to populate the error snackbar message.
  String _getErrorReason(double chipValue) {
    final newTotal = stagedBet + chipValue;
    if (newTotal > widget.currentBankroll) return 'Insufficient bankroll';
    if (widget.maximumBet != null && newTotal > widget.maximumBet!) {
      return 'Exceeds maximum bet (£${widget.maximumBet!.toStringAsFixed(0)})';
    }
    return 'Unknown error';
  }

  /// Removes the most recently added chip, reducing [stagedBet] accordingly.
  /// Does nothing if no chips have been staged yet.
  void _undoLastChip() {
    if (stagedChips.isEmpty) return;
    setState(() {
      final lastChip = stagedChips.removeLast();
      stagedBet -= lastChip;
    });
  }

  /// Resets the staged bet entirely, removing all chips.
  void _clearBet() {
    setState(() {
      stagedBet = 0.0;
      stagedChips.clear();
    });
  }

  /// Validates the staged bet against the table minimum and calls [onConfirm]
  /// if it passes.  Validation errors are shown via a snackbar.
  void _confirmBet() {
    // Enforce minimum bet requirement before confirming.
    if (widget.minimumBet != null && stagedBet < widget.minimumBet!) {
      _showError('Minimum bet is £${widget.minimumBet!.toStringAsFixed(0)}');
      return;
    }

    // Prevent accidentally confirming an empty bet.
    if (stagedBet <= 0) {
      _showError('Please place a bet');
      return;
    }

    widget.onConfirm(stagedBet);
  }

  // ─── Chip Appearance ──────────────────────────────────────────────────────

  /// Maps each chip denomination to its traditional casino chip colour.
  ///
  /// Colour conventions follow standard casino practice:
  ///   £1   – White/silver  |  £5  – Red    |  £10 – Blue
  ///   £25  – Navy light    |  £50 – Purple |  £100 – Navy dark
  Color _getChipColor(double value) {
    switch (value.toInt()) {
      case 1:   return const Color(0xFFE0E0E0); // White/silver
      case 5:   return Colors.red;
      case 10:  return Colors.blue;
      case 25:  return AppColors.primaryNavyLight;
      case 50:  return Colors.purple;
      case 100: return AppColors.primaryNavyDark;
      default:  return Colors.grey;
    }
  }

  /// Returns an appropriate text colour for the chip label so it remains
  /// legible against the chip background.  The £1 white chip uses dark text;
  /// all others use white text.
  Color _getChipTextColor(double value) {
    return value.toInt() == 1 ? Colors.black87 : Colors.white;
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  /// Displays a transient error [message] in a snackbar using the app's error
  /// colour, auto-dismissing after two seconds.
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.error,
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;

    // Panel occupies 35% of width in landscape (less intrusive), 75% in
    // portrait to give enough space for the chip grid.
    final menuWidth = isLandscape ? size.width * 0.35 : size.width * 0.75;

    // How much of the bankroll the player still has available after staging.
    final remainingBankroll = widget.currentBankroll - stagedBet;

    return Container(
      width: menuWidth,
      height: size.height,
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          // Drop shadow on the right edge to lift the panel above the table.
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(4, 0),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────────
            // Title bar with a casino chip icon and a close button.
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryNavyDark,
                border: Border(
                  bottom: BorderSide(
                    color: AppColors.secondaryAmber.withOpacity(0.3),
                    width: 2,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.casino_outlined,
                    color: AppColors.secondaryAmber,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Place Bet',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  // Close button – triggers onClose so the parent can animate
                  // the panel out of view.
                  IconButton(
                    icon: Icon(Icons.close, color: AppColors.textPrimary),
                    onPressed: widget.onClose,
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),

            // ── Scrollable Content ───────────────────────────────────────────
            // Bet summary, chip grid, and action buttons sit inside a
            // scrollable area so nothing is cut off on small screens.
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Bet Summary Card ─────────────────────────────────
                    // Displays the current staged amount and remaining funds.
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryNavyDark.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          // Current staged bet amount.
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Current Bet:',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              Text(
                                '£${stagedBet.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontFamily: 'Montserrat',
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.secondaryAmber,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),

                          // Remaining bankroll after the staged bet is deducted.
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Remaining:',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              Text(
                                '£${remainingBankroll.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                  // Highlight in error colour if somehow negative
                                  // (defensive display only; _canAddChip prevents this).
                                  color: remainingBankroll < 0
                                      ? AppColors.error
                                      : AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),

                          // Show the minimum bet reminder when one is set.
                          if (widget.minimumBet != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Min: £${widget.minimumBet!.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                color: AppColors.textSecondary.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Chip Selection Grid ───────────────────────────────
                    Text(
                      'Select Chips:',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 2-column grid of circular chip buttons.
                    GridView.builder(
                      shrinkWrap: true,
                      // Disable inner scrolling – the outer SingleChildScrollView
                      // handles all scrolling for this panel.
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 1.2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: chipValues.length,
                      itemBuilder: (context, index) {
                        final chipValue = chipValues[index];
                        final canAdd   = _canAddChip(chipValue);
                        final chipColor  = _getChipColor(chipValue);
                        final textColor  = _getChipTextColor(chipValue);

                        return GestureDetector(
                          // Disable taps when the chip cannot be added.
                          onTap: canAdd ? () => _addChip(chipValue) : null,
                          child: Opacity(
                            // Fade the chip to signal it is unavailable.
                            opacity: canAdd ? 1.0 : 0.4,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: chipColor,
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 6,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // Denomination label.
                                    Text(
                                      '£${chipValue.toInt()}',
                                      style: TextStyle(
                                        fontFamily: 'Montserrat',
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: textColor,
                                      ),
                                    ),

                                    // Lock icon shown when the chip is disabled.
                                    if (!canAdd)
                                      Icon(
                                        Icons.lock,
                                        size: 14,
                                        color: textColor.withOpacity(0.5),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 16),

                    // ── Undo / Clear Buttons ──────────────────────────────
                    // Two side-by-side outlined buttons to adjust the bet
                    // without clearing everything.
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            // Disabled when there are no chips to undo.
                            onPressed: stagedChips.isNotEmpty
                                ? _undoLastChip
                                : null,
                            icon: const Icon(Icons.undo, size: 16),
                            label: const Text('Undo'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textPrimary,
                              side: BorderSide(
                                color: AppColors.textSecondary.withOpacity(0.3),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            // Disabled when the bet is already empty.
                            onPressed: stagedBet > 0 ? _clearBet : null,
                            icon: const Icon(Icons.clear, size: 16),
                            label: const Text('Clear'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side: BorderSide(
                                color: AppColors.error.withOpacity(0.3),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Footer: Confirm Button ────────────────────────────────────────
            // Pinned outside the scroll area so it is always visible.
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryNavyDark.withOpacity(0.3),
                border: Border(
                  top: BorderSide(
                    color: AppColors.secondaryAmber.withOpacity(0.3),
                    width: 1,
                  ),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  // Disabled until the player has staged at least one chip.
                  onPressed: stagedBet > 0 ? _confirmBet : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondaryAmber,
                    foregroundColor: AppColors.textOnAmber,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Confirm Bet',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}