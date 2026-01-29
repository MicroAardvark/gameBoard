// checkers_screen.dart - Screen component for Checkers game
// UK English spelling in comments and strings, US spelling for Flutter APIs

import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import '../games/checkers_game.dart';

class CheckersScreen extends StatefulWidget {
  final String difficulty; // 'easy', 'medium', 'hard'

  const CheckersScreen({
    super.key,
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
    game = CheckersGame();
    game.onGameOver = _handleGameOver;
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
          style: const TextStyle(fontSize: 18),
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
              Navigator.of(context).pop(); // Return to menu
            },
            child: const Text('Return to Menu'),
          ),
        ],
      ),
    );
  }

  void _resetGame() {
    setState(() {
      game = CheckersGame();
      game.onGameOver = _handleGameOver;
      isGameOver = false;
      winner = null;
    });
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('How to Play Checkers'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Objective',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text('Capture all opponent pieces or block them from making valid moves.'),
              SizedBox(height: 16),
              
              Text(
                'Movement',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text('• Regular pieces move diagonally forward one square'),
              Text('• Kings (crowned pieces) can move diagonally in any direction'),
              SizedBox(height: 16),
              
              Text(
                'Capturing',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text('• Jump over opponent pieces to capture them'),
              Text('• Chain captures are mandatory if available'),
              Text('• Capturing is compulsory when possible'),
              SizedBox(height: 16),
              
              Text(
                'Promotion',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text('• Reach the opposite end to become a King'),
              Text('• Kings gain the ability to move backwards'),
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
              // Game info panel
              _buildGameInfoPanel(),
              
              // Game board
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: Container(
                      margin: const EdgeInsets.all(16),
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
                  ),
                ),
              ),
              
              // Action buttons
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameInfoPanel() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
              Text(
                'Difficulty',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.difficulty.toUpperCase(),
                style: const TextStyle(
                  fontSize: 16,
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
          width: 40,
          height: 40,
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
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive ? Colors.black : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton.icon(
            onPressed: _showResignDialog,
            icon: const Icon(Icons.flag),
            label: const Text('Resign'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: _showHelpDialog,
            icon: const Icon(Icons.info_outline),
            label: const Text('Rules'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF769656),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Difficulty selection screen
class CheckersDifficultyScreen extends StatelessWidget {
  const CheckersDifficultyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Difficulty'),
        backgroundColor: const Color(0xFF769656),
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
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Choose Your Challenge',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 40),
              
              _buildDifficultyButton(
                context,
                'Easy',
                'Perfect for beginners',
                Colors.green,
                Icons.sentiment_satisfied,
              ),
              const SizedBox(height: 20),
              
              _buildDifficultyButton(
                context,
                'Medium',
                'A balanced challenge',
                Colors.orange,
                Icons.sentiment_neutral,
              ),
              const SizedBox(height: 20),
              
              _buildDifficultyButton(
                context,
                'Hard',
                'For experienced players',
                Colors.red,
                Icons.sentiment_very_dissatisfied,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDifficultyButton(
    BuildContext context,
    String difficulty,
    String description,
    Color buttonColor,
    IconData icon,
  ) {
    return SizedBox(
      width: 280,
      height: 80,
      child: ElevatedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CheckersScreen(
                difficulty: difficulty.toLowerCase(),
              ),
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonColor,
          foregroundColor: Colors.white,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32),
            const SizedBox(width: 16),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  difficulty,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}