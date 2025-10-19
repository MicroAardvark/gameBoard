import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../games/blackjack_game.dart';
import '../models/user.dart';

class BlackjackScreen extends StatefulWidget {
  final User user;

  const BlackjackScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<BlackjackScreen> createState() => _BlackjackScreenState();
}

class _BlackjackScreenState extends State<BlackjackScreen> {
  late final BlackjackGame _game;

  @override
  void initState() {
    super.initState();
    _game = BlackjackGame(user: widget.user);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final buttonSize = (size.height * 0.06).clamp(32.0, 48.0);
    final topPadding = size.height * 0.02;
    final leftPadding = size.width * 0.02;
    
    return Scaffold(
      body: Stack(
        children: [
          GameWidget(game: _game),
          
          // Back button overlay
          Positioned(
            top: topPadding,
            left: leftPadding,
            child: SafeArea(
              child: IconButton(
                icon: Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: buttonSize * 0.7,
                ),
                onPressed: () {
                  Navigator.pop(context);
                },
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: (0.5)),
                  padding: EdgeInsets.all(buttonSize * 0.25),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}