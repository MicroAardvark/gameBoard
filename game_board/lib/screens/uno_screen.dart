// lib/screens/uno_screen.dart
import 'package:flutter/material.dart';
import 'package:flame/game.dart';

import '../models/user.dart';
import '../games/uno_game.dart';

class UnoScreen extends StatefulWidget {
  final User user;

  const UnoScreen({
    Key? key,
    required this.user,
  }) : super(key: key);

  @override
  State<UnoScreen> createState() => _UnoScreenState();
}

class _UnoScreenState extends State<UnoScreen> {
  late UnoGame _game;

  @override
  void initState() {
    super.initState();
    _game = UnoGame(user: widget.user);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B5E20),
      body: SafeArea(
        child: Stack(
          children: [
            // The Flame game
            GameWidget(game: _game),
            
            // Back button
            Positioned(
              top: 16,
              left: 16,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 32),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ),
            
            // Info button (optional)
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.info_outline, color: Colors.white, size: 28),
                onPressed: () {
                  _showRulesDialog();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRulesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('UNO Rules'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text(
                'How to Play:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text('• Match the card by color or number'),
              Text('• Wild cards can be played anytime'),
              Text('• Draw a card if you can\'t play'),
              SizedBox(height: 12),
              Text(
                'Action Cards:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text('⊘ Skip - Next player loses turn'),
              Text('⇄ Reverse - Change direction'),
              Text('+2 - Next player draws 2 cards'),
              Text('W Wild - Choose any color'),
              Text('+4 Wild - Choose color & next player draws 4'),
              SizedBox(height: 12),
              Text(
                'Win by getting rid of all your cards!',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
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

  @override
  void dispose() {
    _game.onDispose();
    super.dispose();
  }
}