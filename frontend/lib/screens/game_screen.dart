import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../game/hide_and_seek_game.dart';

class GameScreen extends StatelessWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: GameWidget(game: HideAndSeekGame()));
  }
}
