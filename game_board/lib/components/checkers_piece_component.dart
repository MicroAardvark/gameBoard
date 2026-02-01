// ====================================
// lib/components/checkers_piece_component.dart
// Checkers piece component that renders actual colours (red/black)
// Used by both single-player and multiplayer checkers games
// ====================================

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flame/effects.dart';
import '../games/checkers_game.dart';

/// Represents a single checkers piece on the board
/// Renders actual colours (red/black) based on piece type
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
    size: Vector2.all(36.0), // CheckersConstants.pieceSize
    anchor: Anchor.center,
  );
  
  // Override to only respond to taps on the circular piece
  // This prevents the piece's rectangular hitbox from blocking board taps
  @override
  bool containsLocalPoint(Vector2 point) {
    final pieceCenter = size / 2;
    final pieceRadius = size.x / 2;
    final distance = point.distanceTo(pieceCenter);
    return distance <= pieceRadius;
  }
  
  @override
  void render(Canvas canvas) {
    super.render(canvas);
    
    // Piece type constants (matches both single-player and multiplayer)
    const int redPiece = 1;
    const int redKing = 2;
    const int blackPiece = 3;
    const int blackKing = 4;
    
    // Colour constants
    const Color redPieceColour = Color(0xFFDC143C);
    const Color blackPieceColour = Color(0xFF1C1C1C);
    const Color selectedColour = Color(0xFFFFD700);
    const Color kingBorderColour = Color(0xFFFFD700);
    const double crownSize = 18.0;
    
    // Determine if this is a king piece
    final isKing = pieceType == redKing || pieceType == blackKing;
    
    // Determine actual colour of piece
    final Color pieceColour;
    if (pieceType == redPiece || pieceType == redKing) {
      pieceColour = redPieceColour;  // Red pieces
    } else if (pieceType == blackPiece || pieceType == blackKing) {
      pieceColour = blackPieceColour;  // Black pieces
    } else {
      pieceColour = Colors.grey;  // Fallback (shouldn't happen)
    }
    
    // Draw outer circle (border) if selected
    if (isSelected) {
      final borderPaint = Paint()
        ..color = selectedColour
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
      _drawCrown(canvas, crownSize, kingBorderColour);
    }
  }
  
  /// Draw a crown symbol for king pieces
  void _drawCrown(Canvas canvas, double crownSize, Color kingBorderColour) {
    final crownPaint = Paint()
      ..color = kingBorderColour
      ..style = PaintingStyle.fill;
    
    final crownBorderPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    
    final centerX = size.x / 2;
    final centerY = size.y / 2;
    final crownWidth = crownSize;
    final crownHeight = crownSize * 0.8;
    
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
        EffectController(duration: 0.3),  // 300ms animation
      ),
    );
  }
}

// ====================================
// CONSTANTS (for backward compatibility)
// ====================================

class CheckersConstants {
  // Board dimensions
  static const int boardSize = 8;
  static const double squareSize = 48.0;
  static const double pieceSize = 36.0;
  static const double crownSize = 18.0;
  
  // Colours
  static const Color darkSquare = Color(0xFF000000);
  static const Color lightSquare = Color(0xFFF5F5DC);
  static const Color highlightColour = Color(0xFFFFA500);
  static const Color selectedColour = Color(0xFFFFD700);
  static const Color validMoveColour = Color(0xFF4169E1);
  static const Color kingBorderColour = Color(0xFFFFD700);
  
  // Piece colours
  static const Color playerPieceColour = Color(0xFFDC143C);  // Red (for single-player)
  static const Color aiPieceColour = Color(0xFF1C1C1C);      // Black (for single-player)
  static const Color redPieceColour = Color(0xFFDC143C);     // Red (for multiplayer)
  static const Color blackPieceColour = Color(0xFF1C1C1C);   // Black (for multiplayer)
  
  // Game settings
  static const Duration moveAnimationDuration = Duration(milliseconds: 300);
  static const Duration aiThinkingDelay = Duration(milliseconds: 800);
  
  // Piece types (single-player compatibility)
  static const int emptySquare = 0;
  static const int playerPiece = 1;
  static const int playerKing = 2;
  static const int aiPiece = 3;
  static const int aiKing = 4;
  
  // Piece types (multiplayer - actual colours)
  // Note: These use the same values as single-player for compatibility
  static const int redPiece = 1;
  static const int redKing = 2;
  static const int blackPiece = 3;
  static const int blackKing = 4;
}