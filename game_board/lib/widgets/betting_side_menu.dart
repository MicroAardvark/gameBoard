// ====================================
// lib/widgets/betting_side_menu.dart
// Collapsible side menu for betting (replaces popup)
// ====================================
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class BettingSideMenu extends StatefulWidget {
  final double currentBankroll;
  final double? minimumBet;
  final double? maximumBet;
  final Function(double betAmount) onConfirm;
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
  final List<double> chipValues = [1, 5, 10, 25, 50, 100];
  double stagedBet = 0.0;
  final List<double> stagedChips = [];

  @override
  void initState() {
    super.initState();
    if (widget.minimumBet != null && widget.minimumBet! > 0) {
      _autoAddMinimumBet();
    }
  }

  void _autoAddMinimumBet() {
    if (widget.minimumBet == null) return;
    double remaining = widget.minimumBet!;
    
    for (int i = chipValues.length - 1; i >= 0; i--) {
      final chipValue = chipValues[i];
      while (remaining >= chipValue && _canAddChip(chipValue)) {
        _addChip(chipValue);
        remaining -= chipValue;
      }
    }
  }

  bool _canAddChip(double chipValue) {
    final newTotal = stagedBet + chipValue;
    if (newTotal > widget.currentBankroll) return false;
    if (widget.maximumBet != null && newTotal > widget.maximumBet!) return false;
    return true;
  }

  void _addChip(double chipValue) {
    if (!_canAddChip(chipValue)) {
      _showError('Cannot add chip: ${_getErrorReason(chipValue)}');
      return;
    }
    
    setState(() {
      stagedBet += chipValue;
      stagedChips.add(chipValue);
    });
  }

  String _getErrorReason(double chipValue) {
    final newTotal = stagedBet + chipValue;
    if (newTotal > widget.currentBankroll) return 'Insufficient bankroll';
    if (widget.maximumBet != null && newTotal > widget.maximumBet!) {
      return 'Exceeds maximum bet (£${widget.maximumBet!.toStringAsFixed(0)})';
    }
    return 'Unknown error';
  }

  void _undoLastChip() {
    if (stagedChips.isEmpty) return;
    setState(() {
      final lastChip = stagedChips.removeLast();
      stagedBet -= lastChip;
    });
  }

  void _clearBet() {
    setState(() {
      stagedBet = 0.0;
      stagedChips.clear();
    });
  }

  void _confirmBet() {
    if (widget.minimumBet != null && stagedBet < widget.minimumBet!) {
      _showError('Minimum bet is £${widget.minimumBet!.toStringAsFixed(0)}');
      return;
    }
    if (stagedBet <= 0) {
      _showError('Please place a bet');
      return;
    }
    widget.onConfirm(stagedBet);
  }

  Color _getChipColor(double value) {
    switch (value.toInt()) {
      case 1: return const Color(0xFFE0E0E0);
      case 5: return Colors.red;
      case 10: return Colors.blue;
      case 25: return AppColors.primaryNavyLight;
      case 50: return Colors.purple;
      case 100: return AppColors.primaryNavyDark;
      default: return Colors.grey;
    }
  }

  Color _getChipTextColor(double value) {
    return value.toInt() == 1 ? Colors.black87 : Colors.white;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;
    final menuWidth = isLandscape ? size.width * 0.35 : size.width * 0.75;
    final remainingBankroll = widget.currentBankroll - stagedBet;

    return Container(
      width: menuWidth,
      height: size.height,
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
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
            // Header
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
                  IconButton(
                    icon: Icon(Icons.close, color: AppColors.textPrimary),
                    onPressed: widget.onClose,
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Bet info
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryNavyDark.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
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
                                  color: remainingBankroll < 0 
                                    ? AppColors.error 
                                    : AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
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

                    // Chips
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

                    GridView.builder(
                      shrinkWrap: true,
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
                        final canAdd = _canAddChip(chipValue);
                        final chipColor = _getChipColor(chipValue);
                        final textColor = _getChipTextColor(chipValue);

                        return GestureDetector(
                          onTap: canAdd ? () => _addChip(chipValue) : null,
                          child: Opacity(
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
                                    Text(
                                      '£${chipValue.toInt()}',
                                      style: TextStyle(
                                        fontFamily: 'Montserrat',
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: textColor,
                                      ),
                                    ),
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

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: stagedChips.isNotEmpty ? _undoLastChip : null,
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

            // Confirm button
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