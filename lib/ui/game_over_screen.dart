/// Game-over screen: confetti, count-up scores, rematch.
library;

import 'package:flutter/material.dart';

import '../game/ai_engine.dart';
import '../game/dictionary.dart';
import '../game/game_state.dart';
import 'animated_background.dart';
import 'board_screen.dart';
import 'menu_screen.dart';
import 'setup_screen.dart';
import 'widgets.dart';

class GameOverScreen extends StatelessWidget {
  final GameState game;
  final GameConfig config;
  final Dictionary dict;
  final AiEngine aiEngine;

  const GameOverScreen({
    super.key,
    required this.game,
    required this.config,
    required this.dict,
    required this.aiEngine,
  });

  void _rematch(BuildContext context) {
    final players = <Player>[];
    if (config.mode == SetupMode.vsAi) {
      players.add(Player(
          name: 'You',
          isAI: false,
          difficulty: Difficulty.medium,
          colorIndex: 0));
      players.add(Player(
          name: 'Computer',
          isAI: true,
          difficulty: config.difficulty,
          colorIndex: 1));
    } else {
      for (var i = 0; i < config.playerNames.length; i++) {
        players.add(Player(
            name: config.playerNames[i],
            isAI: false,
            difficulty: Difficulty.medium,
            colorIndex: i));
      }
    }
    final newGame =
        GameState(players: players, dict: dict, aiEngine: aiEngine);
    Navigator.of(context).pushReplacement(
      slideRoute(BoardScreen(
          game: newGame,
          config: config,
          dict: dict,
          aiEngine: aiEngine)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final winner = game.winnerIndex ?? 0;
    final ordered = List.generate(game.players.length, (i) => i)
      ..sort((a, b) =>
          game.players[b].score.compareTo(game.players[a].score));
    return Scaffold(
      body: FloatingTilesBackground(
        child: SafeArea(
          child: Stack(
            children: [
              const Confetti(),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 26, vertical: 20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const StaggeredIn(
                        index: 0,
                        child: Text(
                          'GAME OVER',
                          style: TextStyle(
                            color: Colors.white70,
                            letterSpacing: 4,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration:
                            const Duration(milliseconds: 900),
                        curve: Curves.elasticOut,
                        builder: (_, t, __) => Transform.scale(
                          scale: t,
                          child: const Icon(
                            Icons.emoji_events,
                            color: Colors.amber,
                            size: 84,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      StaggeredIn(
                        index: 1,
                        child: Text(
                          '${game.players[winner].name} Wins!',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      if (game.gameOverReason != null)
                        StaggeredIn(
                          index: 2,
                          child: Padding(
                            padding:
                                const EdgeInsets.only(top: 4),
                            child: Text(
                              game.gameOverReason!,
                              style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 13),
                            ),
                          ),
                        ),
                      const SizedBox(height: 22),
                      for (var rank = 0;
                          rank < ordered.length;
                          rank++)
                        Padding(
                          padding:
                              const EdgeInsets.only(bottom: 10),
                          child: StaggeredIn(
                            index: 3 + rank,
                            child: _scoreRow(
                                ordered[rank], rank),
                          ),
                        ),
                      const SizedBox(height: 26),
                      StaggeredIn(
                        index: 7,
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceEvenly,
                          children: [
                            BouncyButton(
                              color:
                                  Colors.white.withValues(alpha: 0.16),
                              onTap: () =>
                                  Navigator.of(context)
                                      .pushReplacement(
                                MaterialPageRoute(
                                  builder: (_) => MenuScreen(
                                      dict: dict,
                                      aiEngine: aiEngine),
                                ),
                              ),
                              child: const Text('Menu',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 17)),
                            ),
                            BouncyButton(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF43A047),
                                  Color(0xFF2E7D32)
                                ],
                              ),
                              onTap: () => _rematch(context),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.refresh,
                                      color: Colors.white),
                                  SizedBox(width: 8),
                                  Text('Rematch',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 17)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scoreRow(int playerIndex, int rank) {
    final p = game.players[playerIndex];
    final medals = ['🥇', '🥈', '🥉', '4th'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: rank == 0 ? Colors.amber : Colors.white24,
          width: rank == 0 ? 2.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Text(medals[rank.clamp(0, 3)],
              style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (p.isAI)
                      const Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Icon(Icons.smart_toy,
                            size: 14, color: Colors.white70),
                      ),
                    Text(p.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16)),
                  ],
                ),
                if (p.bestWord != null)
                  Text(
                    'Best: ${p.bestWord} (+${p.bestWordScore})',
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 12),
                  ),
              ],
            ),
          ),
          TweenAnimationBuilder<int>(
            tween: IntTween(begin: 0, end: p.score),
            duration: const Duration(milliseconds: 1200),
            builder: (_, v, __) => Text(
              '$v',
              style: TextStyle(
                color: rank == 0 ? Colors.amber : Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 26,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
