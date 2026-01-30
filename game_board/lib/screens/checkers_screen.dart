// checkers_screen.dart - Screen component for Checkers game
// UK English spelling in comments and strings, US spelling for Flutter APIs

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flame/game.dart';
import '../games/checkers_game.dart';
import '../models/user.dart';

class CheckersScreen extends StatefulWidget {
  final User user;
  final String difficulty; // 'easy', 'medium', 'hard'

  const CheckersScreen({
    super.key,
    required this.user,
    this.difficulty = 'medium',
  });

  @override
  State<CheckersScreen> createState() => _CheckersScreenState();
}

class _CheckersScreenState extends State<CheckersScreen> {
  late CheckersGame game;
  bool isGameOver = false;
  String? winner;

  @override
  void initState() {
    super.initState();
    // Lock to portrait mode for checkers
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    
    game = CheckersGame();
    game.onGameOver = _handleGameOver;
  }

  @override
  void dispose() {
    // Restore landscape mode when leaving checkers
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  void _handleGameOver(String winnerColour) {
    setState(() {
      isGameOver = true;
      winner = winnerColour;
    });
    
    _showGameOverDialog();
  }

  void _showGameOverDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Game Over'),
        content: Text(
          winner == 'red' 
            ? 'Congratulations! You won!' 
            : 'AI wins! Better luck next time!',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _resetGame();
            },
            child: const Text('Play Again'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Go back to difficulty screen
            },
            child: const Text('Main Menu'),
          ),
        ],
      ),
    );
  }

  void _resetGame() {
    setState(() {
      isGameOver = false;
      winner = null;
      game = CheckersGame();
      game.onGameOver = _handleGameOver;
    });
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('How to Play'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text(
                'Objective:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text('Capture all opponent pieces or block them from moving.'),
              SizedBox(height: 12),
              Text(
                'Movement:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text('• Regular pieces move diagonally forward'),
              Text('• Kings can move diagonally in any direction'),
              SizedBox(height: 12),
              Text(
                'Capturing:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text('• Jump over opponent pieces to capture them'),
              Text('• Multiple captures in one turn are allowed'),
              Text('• Captures are mandatory when available'),
              SizedBox(height: 12),
              Text(
                'Kings:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text('• Reach the opposite end to become a king'),
              Text('• Kings are marked with a crown'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }

  void _showResignDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resign Game'),
        content: const Text('Are you sure you want to resign? The AI will win.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _handleGameOver('black'); // AI wins
            },
            child: const Text(
              'Resign',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkers'),
        backgroundColor: const Color(0xFF769656),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showHelpDialog,
            tooltip: 'How to Play',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('New Game'),
                  content: const Text('Start a new game? Current progress will be lost.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _resetGame();
                      },
                      child: const Text('New Game'),
                    ),
                  ],
                ),
              );
            },
            tooltip: 'New Game',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.surface,
              theme.colorScheme.surfaceContainerHighest,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Game info panel (top)
              _buildGameInfoPanel(),
              
              // Game board (centre)
              Expanded(
                child: Center(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // Calculate square size for perfect centring
                      final size = constraints.maxWidth < constraints.maxHeight
                          ? constraints.maxWidth * 0.95
                          : constraints.maxHeight * 0.95;
                      
                      return SizedBox(
                        width: size,
                        height: size,
                        child: Container(
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 10,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: GameWidget(game: game),
                        ),
                      );
                    },
                  ),
                ),
              ),
              
              // Action buttons (bottom)
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameInfoPanel() {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildPlayerIndicator('You', Colors.red, 
            game.stateManager.currentPlayer == 'red'),
          
          Column(
            children: [
              const Text(
                'Difficulty',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.difficulty.toUpperCase(),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF769656),
                ),
              ),
            ],
          ),
          
          _buildPlayerIndicator('AI', Colors.black, 
            game.stateManager.currentPlayer == 'black'),
        ],
      ),
    );
  }

  Widget _buildPlayerIndicator(String label, Color pieceColor, bool isActive) {
    return Column(
      children: [
        Container(
          width: 45,
          height: 45,
          decoration: BoxDecoration(
            color: pieceColor,
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive ? Colors.amber : Colors.transparent,
              width: 3,
            ),
            boxShadow: isActive ? [
              BoxShadow(
                color: Colors.amber.withValues(alpha: 0.5),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ] : [],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive ? Colors.black : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _showResignDialog,
              icon: const Icon(Icons.flag, size: 18),
              label: const Text('Resign'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _showHelpDialog,
              icon: const Icon(Icons.info_outline, size: 18),
              label: const Text('Rules'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF769656),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}