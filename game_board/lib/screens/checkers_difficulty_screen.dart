// checkers_difficulty_screen.dart - Difficulty selection for Checkers
// UK English spelling in comments and strings, US spelling for Flutter APIs

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/user.dart';
import 'checkers_screen.dart';

class CheckersDifficultyScreen extends StatefulWidget {
  final User user;
  
  const CheckersDifficultyScreen({
    super.key,
    required this.user,
  });

  @override
  State<CheckersDifficultyScreen> createState() => _CheckersDifficultyScreenState();
}

class _CheckersDifficultyScreenState extends State<CheckersDifficultyScreen> {
  @override
  void initState() {
    super.initState();
    // Lock to portrait mode for checkers flow
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  @override
  void dispose() {
    // Restore landscape mode when leaving checkers flow
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

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
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
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
                    const SizedBox(height: 30),
                    
                    _buildDifficultyButton(
                      context,
                      'Easy',
                      'Perfect for beginners',
                      Colors.green,
                      Icons.sentiment_satisfied,
                    ),
                    const SizedBox(height: 16),
                    
                    _buildDifficultyButton(
                      context,
                      'Medium',
                      'A balanced challenge',
                      Colors.orange,
                      Icons.sentiment_neutral,
                    ),
                    const SizedBox(height: 16),
                    
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
                user: widget.user,
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