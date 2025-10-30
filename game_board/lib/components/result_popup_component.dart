// ====================================
// lib/components/result_popup_component.dart
// Centered pop-up for displaying round results
// ====================================
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;

class ResultPopupComponent extends PositionComponent {
  final String mainText;
  final String amountText;
  final bool isWin;
  final VoidCallback? onDismiss;
  
  double _opacity = 0.0;
  double _scale = 0.5;
  late Vector2 _centerPos;
  bool isDismissed = false;
  
  ResultPopupComponent({
    required this.mainText,
    required this.amountText,
    required this.isWin,
    this.onDismiss,
  }) : super(priority: 1000); // Very high priority to render on top

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    // Center of the screen
    _centerPos = Vector2(
      parent!.size.x / 2,
      parent!.size.y / 2,
    );
    
    position = _centerPos;
    anchor = Anchor.center;
    
    // Animate in
    _animateIn();
    
    // Auto-dismiss after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (!isDismissed) {
        dismiss();
      }
    });
  }

  void _animateIn() {
    final startTime = DateTime.now().millisecondsSinceEpoch;
    const duration = 300; // milliseconds
    
    void animate(double dt) {
      final elapsed = DateTime.now().millisecondsSinceEpoch - startTime;
      final progress = (elapsed / duration).clamp(0.0, 1.0);
      
      // Ease out cubic
      final eased = 1 - (1 - progress) * (1 - progress) * (1 - progress);
      
      _opacity = eased;
      _scale = 0.5 + (eased * 0.5); // Scale from 0.5 to 1.0
      
      if (progress >= 1.0) {
        // Animation complete
        return;
      }
    }
    
    // Simple animation using update loop
  }

  void dismiss() {
    if (isDismissed) return;
    isDismissed = true;
    
    final startTime = DateTime.now().millisecondsSinceEpoch;
    const duration = 200;
    
    void animateOut(double dt) {
      final elapsed = DateTime.now().millisecondsSinceEpoch - startTime;
      final progress = (elapsed / duration).clamp(0.0, 1.0);
      
      _opacity = 1.0 - progress;
      _scale = 1.0 - (progress * 0.2);
      
      if (progress >= 1.0) {
        removeFromParent();
        onDismiss?.call();
      }
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    // Smooth animation towards target values
    if (_opacity < 1.0 && !isDismissed) {
      _opacity = (_opacity + dt * 4.0).clamp(0.0, 1.0);
      _scale = 0.5 + (_opacity * 0.5);
    } else if (isDismissed) {
      _opacity = (_opacity - dt * 5.0).clamp(0.0, 1.0);
      _scale = 1.0 - ((1.0 - _opacity) * 0.2);
      
      if (_opacity <= 0.0) {
        removeFromParent();
        onDismiss?.call();
      }
    }
  }

  @override
  void render(Canvas canvas) {
    if (_opacity <= 0.0) return;
    
    final paint = Paint();
    
    // Draw semi-transparent overlay
    paint.color = Colors.black.withValues(alpha: 0.7 * _opacity);
    canvas.drawRect(
      Rect.fromLTWH(
        -parent!.size.x / 2,
        -parent!.size.y / 2,
        parent!.size.x,
        parent!.size.y,
      ),
      paint,
    );
    
    // Apply scale transform
    canvas.save();
    canvas.scale(_scale);
    
    // Calculate dimensions
    final boxWidth = parent!.size.x * 0.6;
    final boxHeight = parent!.size.y * 0.3;
    
    // Draw background box with rounded corners
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset.zero,
        width: boxWidth,
        height: boxHeight,
      ),
      const Radius.circular(20),
    );
    
    // Gradient background
    final gradient = ui.Gradient.linear(
      Offset(0, -boxHeight / 2),
      Offset(0, boxHeight / 2),
      isWin 
          ? [
              Color(0xFF2E7D32).withValues(alpha: 0.95 * _opacity),
              Color(0xFF1B5E20).withValues(alpha: 0.95 * _opacity),
            ]
          : [
              Color(0xFFC62828).withValues(alpha: 0.95 * _opacity),
              Color(0xFF8E0000).withValues(alpha: 0.95 * _opacity),
            ],
    );
    
    paint.shader = gradient;
    canvas.drawRRect(rect, paint);
    
    // Draw border
    paint.shader = null;
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 3;
    paint.color = (isWin ? Colors.greenAccent : Colors.redAccent)
        .withValues(alpha: 0.8 * _opacity);
    canvas.drawRRect(rect, paint);
    
    // Draw icon (emoji)
    final iconStyle = TextStyle(
      fontSize: boxHeight * 0.25,
      color: Colors.white.withValues(alpha: _opacity),
    );
    
    final iconPainter = TextPainter(
      text: TextSpan(
        text: isWin ? '🎉' : '💔',
        style: iconStyle,
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    
    iconPainter.paint(
      canvas,
      Offset(-iconPainter.width / 2, -boxHeight * 0.3),
    );
    
    // Draw main text
    final mainStyle = TextStyle(
      fontSize: boxHeight * 0.15,
      fontWeight: FontWeight.bold,
      color: Colors.white.withValues(alpha: _opacity),
      shadows: [
        Shadow(
          blurRadius: 4,
          color: Colors.black.withValues(alpha: 0.5),
          offset: const Offset(2, 2),
        ),
      ],
    );
    
    final mainPainter = TextPainter(
      text: TextSpan(text: mainText, style: mainStyle),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    
    mainPainter.paint(
      canvas,
      Offset(-mainPainter.width / 2, -boxHeight * 0.05),
    );
    
    // Draw amount text
    final amountStyle = TextStyle(
      fontSize: boxHeight * 0.18,
      fontWeight: FontWeight.bold,
      color: (isWin ? Colors.yellowAccent : Colors.white70)
          .withValues(alpha: _opacity),
      shadows: [
        Shadow(
          blurRadius: 6,
          color: Colors.black.withValues(alpha: 0.6),
          offset: const Offset(2, 2),
        ),
      ],
    );
    
    final amountPainter = TextPainter(
      text: TextSpan(text: amountText, style: amountStyle),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    
    amountPainter.paint(
      canvas,
      Offset(-amountPainter.width / 2, boxHeight * 0.12),
    );
    
    // Draw "Tap to continue" hint
    final hintStyle = TextStyle(
      fontSize: boxHeight * 0.08,
      color: Colors.white60.withValues(alpha: _opacity * 0.8),
      fontStyle: FontStyle.italic,
    );
    
    final hintPainter = TextPainter(
      text: const TextSpan(text: 'Tap to continue', style: hintStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    
    hintPainter.paint(
      canvas,
      Offset(-hintPainter.width / 2, boxHeight * 0.35),
    );
    
    canvas.restore();
  }

  @override
  bool containsLocalPoint(Vector2 point) {
    // Make entire screen tappable to dismiss
    return !isDismissed;
  }
}