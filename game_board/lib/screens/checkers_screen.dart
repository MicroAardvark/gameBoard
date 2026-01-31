import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import '../games/checkers_game.dart';

/// Main screen for the Checkers game
class CheckersScreen extends StatefulWidget {
  const CheckersScreen({Key? key}) : super(key: key);
  
  @override
  State<CheckersScreen> createState() => _CheckersScreenState();
}

class _CheckersScreenState extends State<CheckersScreen> {
  late CheckersGame game;
  String statusMessage = 'Your turn - Select a piece';
  bool isPlayerTurn = true;
  String selectedDifficulty = 'Medium';
  
  @override
  void initState() {
    super.initState();
    _initializeGame();
  }
  
  void _initializeGame() {
    game = CheckersGame(
      onGameOver: _handleGameOver,
      onTurnChanged: _handleTurnChanged,
      onStatusUpdate: _handleStatusUpdate,
    );
  }
  
  void _handleGameOver(String winner) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        statusMessage = 'Game Over! $winner wins!';
      });
      _showGameOverDialog(winner);
    });
  }
  
  void _handleTurnChanged(bool playerTurn) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        isPlayerTurn = playerTurn;
      });
    });
  }
  
  void _handleStatusUpdate(String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        statusMessage = message;
      });
    });
  }
  
  void _showGameOverDialog(String winner) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A2332),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFFFA500), width: 2),
        ),
        title: const Text(
          'Game Over',
          style: TextStyle(
            color: Color(0xFFFFD700),
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        content: Text(
          '$winner wins!',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
          ),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _resetGame();
            },
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFFFFA500),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text(
                'Play Again',
                style: TextStyle(
                  color: Color(0xFF1A2332),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Return to game selection
            },
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFF2D3E50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text(
                'Exit',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
        actionsAlignment: MainAxisAlignment.spaceEvenly,
      ),
    );
  }
  
  void _resetGame() {
    setState(() {
      game.resetGame();
      statusMessage = 'Your turn - Select a piece';
      isPlayerTurn = true;
    });
  }
  
  void _showHowToPlayDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A2332),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFFFA500), width: 2),
        ),
        title: const Text(
          'How to Play',
          style: TextStyle(
            color: Color(0xFFFFD700),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '• Tap a piece to select it\n'
                '• Tap a highlighted square to move\n'
                '• Jump over opponent pieces to capture them\n'
                '• Reach the opposite end to become a King\n'
                '• Capture all opponent pieces to win!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFFFFA500),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text(
                'Got it!',
                style: TextStyle(
                  color: Color(0xFF1A2332),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
        actionsAlignment: MainAxisAlignment.center,
      ),
    );
  }
  
  void _showDifficultyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A2332),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFFFA500), width: 2),
        ),
        title: const Text(
          'Select Difficulty',
          style: TextStyle(
            color: Color(0xFFFFD700),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDifficultyButton('Easy'),
            const SizedBox(height: 10),
            _buildDifficultyButton('Medium'),
            const SizedBox(height: 10),
            _buildDifficultyButton('Hard'),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDifficultyButton(String difficulty) {
    final isSelected = selectedDifficulty == difficulty;
    
    return InkWell(
      onTap: () {
        setState(() {
          selectedDifficulty = difficulty;
          game.setDifficulty(difficulty);
        });
        Navigator.of(context).pop();
        _resetGame();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFA500) : const Color(0xFF2D3E50),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFFFFD700) : Colors.transparent,
            width: 2,
          ),
        ),
        child: Text(
          difficulty,
          style: TextStyle(
            color: isSelected ? const Color(0xFF1A2332) : Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      body: SafeArea(
        child: Row(
          children: [
            // Left side panel
            Container(
              width: 80,
              decoration: const BoxDecoration(
                color: Color(0xFF1A2332),
                border: Border(
                  right: BorderSide(
                    color: Color(0xFFFFA500),
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                children: [
                  // Back button at top
                  const SizedBox(height: 8),
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Color(0xFFFFA500), size: 24),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Title
                  const RotatedBox(
                    quarterTurns: 0,
                    child: Text(
                      'Checkers',
                      style: TextStyle(
                        color: Color(0xFFFFD700),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Status and turn indicators in the middle
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Player turn indicator
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: isPlayerTurn ? const Color(0xFF4CAF50) : Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'You',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Difficulty
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2D3E50),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            selectedDifficulty,
                            style: const TextStyle(
                              color: Color(0xFFFFA500),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // AI turn indicator
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: !isPlayerTurn ? const Color(0xFF4CAF50) : Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'AI',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                        
                        const SizedBox(height: 32),
                        
                        // Status message (vertical)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: RotatedBox(
                            quarterTurns: 3,
                            child: Text(
                              statusMessage,
                              style: const TextStyle(
                                color: Color(0xFFFFD700),
                                fontSize: 10,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Action buttons at bottom
                  IconButton(
                    icon: const Icon(Icons.help_outline, color: Color(0xFFFFA500), size: 24),
                    onPressed: _showHowToPlayDialog,
                  ),
                  const SizedBox(height: 8),
                  IconButton(
                    icon: const Icon(Icons.settings, color: Color(0xFFFFA500), size: 24),
                    onPressed: _showDifficultyDialog,
                  ),
                  const SizedBox(height: 8),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Color(0xFFFFA500), size: 24),
                    onPressed: _resetGame,
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            
            // Game board on the right
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: GameWidget(game: game),
              ),
            ),
          ],
        ),
      ),
    );
  }
}