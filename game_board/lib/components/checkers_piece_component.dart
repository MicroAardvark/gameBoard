import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flame/effects.dart';
import '../games/checkers_game.dart';

/// Represents a single checkers piece on the board
class CheckersPiece extends PositionComponent {
  final int pieceType;
  final Position boardPosition;
  bool isSelected = false;
  
  CheckersPiece({
    required this.pieceType,
    required this.boardPosition,
    required Vector2 position,
  }) : super(
    position: position,
    size: Vector2.all(CheckersConstants.pieceSize),
    anchor: Anchor.center,
  );
  
  // 🔧 FIX: Override to only respond to taps on the circular piece
  // This prevents the piece's rectangular hitbox from blocking board taps
  @override
  bool containsLocalPoint(Vector2 point) {
    // Only respond to taps within the circular piece area
    final pieceCenter = size / 2;
    final pieceRadius = size.x / 2;
    final distance = point.distanceTo(pieceCenter);
    return distance <= pieceRadius;
  }
  
  @override
  void render(Canvas canvas) {
    super.render(canvas);
    
    final isKing = pieceType == CheckersConstants.playerKing || pieceType == CheckersConstants.aiKing;
    final isPlayer = pieceType == CheckersConstants.playerPiece || pieceType == CheckersConstants.playerKing;
    
    // Determine piece colour
    final Color pieceColour = isPlayer 
        ? CheckersConstants.playerPieceColour 
        : CheckersConstants.aiPieceColour;
    
    // Draw outer circle (border) if selected
    if (isSelected) {
      final borderPaint = Paint()
        ..color = CheckersConstants.selectedColour
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0;
      
      canvas.drawCircle(
        Offset(size.x / 2, size.y / 2),
        size.x / 2,
        borderPaint,
      );
    }
    
    // Draw main piece circle
    final piecePaint = Paint()
      ..color = pieceColour
      ..style = PaintingStyle.fill;
    
    final borderPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    
    canvas.drawCircle(
      Offset(size.x / 2, size.y / 2),
      size.x / 2 - 4,
      piecePaint,
    );
    
    canvas.drawCircle(
      Offset(size.x / 2, size.y / 2),
      size.x / 2 - 4,
      borderPaint,
    );
    
    // Add highlight for 3D effect
    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(
      Offset(size.x / 2 - 8, size.y / 2 - 8),
      size.x / 4,
      highlightPaint,
    );
    
    // Draw crown if king
    if (isKing) {
      _drawCrown(canvas);
    }
  }
  
  /// Draw a crown symbol for king pieces
  void _drawCrown(Canvas canvas) {
    final crownPaint = Paint()
      ..color = CheckersConstants.kingBorderColour
      ..style = PaintingStyle.fill;
    
    final crownBorderPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    
    final centerX = size.x / 2;
    final centerY = size.y / 2;
    final crownWidth = CheckersConstants.crownSize;
    final crownHeight = CheckersConstants.crownSize * 0.8;
    
    // Draw simple crown shape
    final crownPath = Path();
    
    // Base of crown
    crownPath.moveTo(centerX - crownWidth / 2, centerY + crownHeight / 4);
    
    // Left point
    crownPath.lineTo(centerX - crownWidth / 3, centerY - crownHeight / 4);
    
    // Centre point
    crownPath.lineTo(centerX, centerY + crownHeight / 4);
    crownPath.lineTo(centerX, centerY - crownHeight / 2);
    crownPath.lineTo(centerX, centerY + crownHeight / 4);
    
    // Right point
    crownPath.lineTo(centerX + crownWidth / 3, centerY - crownHeight / 4);
    
    // Back to base
    crownPath.lineTo(centerX + crownWidth / 2, centerY + crownHeight / 4);
    crownPath.close();
    
    canvas.drawPath(crownPath, crownPaint);
    canvas.drawPath(crownPath, crownBorderPaint);
  }
  
  /// Animate move to new position
  void animateTo(Vector2 newPosition) {
    add(
      MoveEffect.to(
        newPosition,
        EffectController(duration: CheckersConstants.moveAnimationDuration.inSeconds.toDouble()),
      ),
    );
  }
}