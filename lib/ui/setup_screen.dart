/// Pre-game setup: vs-computer difficulty or 2–4 pass-and-play players.
library;

import 'package:flutter/material.dart';

import '../game/ai_engine.dart';
import '../game/dictionary.dart';
import '../game/game_state.dart';
import 'animated_background.dart';
import 'board_screen.dart';
import 'widgets.dart';

enum SetupMode { vsAi, passPlay }

/// Everything needed to (re)build a game — also used for rematches.
class GameConfig {
  final SetupMode mode;
  final List<String> playerNames; // humans only, in seat order
  final Difficulty difficulty; // vsAi only

  const GameConfig({
    required this.mode,
    required this.playerNames,
    this.difficulty = Difficulty.medium,
  });
}

class SetupScreen extends StatefulWidget {
  final SetupMode mode;
  final Dictionary dict;
  final AiEngine aiEngine;

  const SetupScreen({
    super.key,
    required this.mode,
    required this.dict,
    required this.aiEngine,
  });

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  int _playerCount = 2;
  Difficulty _difficulty = Difficulty.medium;
  late final List<TextEditingController> _nameControllers;

  @override
  void initState() {
    super.initState();
    _nameControllers = List.generate(
      4,
      (i) => TextEditingController(text: 'Player ${i + 1}'),
    );
  }

  @override
  void dispose() {
    for (final c in _nameControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _start() {
    GameConfig config;
    if (widget.mode == SetupMode.vsAi) {
      config = GameConfig(
        mode: SetupMode.vsAi,
        playerNames: ['You'],
        difficulty: _difficulty,
      );
    } else {
      config = GameConfig(
        mode: SetupMode.passPlay,
        playerNames: List.generate(
          _playerCount,
          (i) => _nameControllers[i].text.trim().isEmpty
              ? 'Player ${i + 1}'
              : _nameControllers[i].text.trim(),
        ),
      );
    }
    final game = _buildGame(config);
    Navigator.of(context).pushReplacement(
      slideRoute(BoardScreen(
          game: game,
          config: config,
          dict: widget.dict,
          aiEngine: widget.aiEngine)),
    );
  }

  GameState _buildGame(GameConfig config) {
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
    return GameState(
        players: players, dict: widget.dict, aiEngine: widget.aiEngine);
  }

  @override
  Widget build(BuildContext context) {
    final isVsAi = widget.mode == SetupMode.vsAi;
    return Scaffold(
      body: FloatingTilesBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Text(
                      isVsAi ? 'Play vs Computer' : 'Pass & Play',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (isVsAi) ...[
                        const StaggeredIn(
                          index: 0,
                          child: Text('Choose difficulty',
                              style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(height: 12),
                        for (var i = 0;
                            i < Difficulty.values.length;
                            i++)
                          Padding(
                            padding:
                                const EdgeInsets.only(bottom: 12),
                            child: StaggeredIn(
                              index: i + 1,
                              child: _difficultyCard(
                                  Difficulty.values[i]),
                            ),
                          ),
                      ] else ...[
                        const StaggeredIn(
                          index: 0,
                          child: Text('How many players?',
                              style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(height: 12),
                        StaggeredIn(
                          index: 1,
                          child: Row(
                            children: [2, 3, 4].map((n) {
                              final selected = _playerCount == n;
                              return Expanded(
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 4),
                                  child: GestureDetector(
                                    onTap: () => setState(
                                        () => _playerCount = n),
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                          milliseconds: 250),
                                      padding:
                                          const EdgeInsets.symmetric(
                                              vertical: 14),
                                      decoration: BoxDecoration(
                                        color: selected
                                            ? const Color(0xFFFFB300)
                                            : Colors.white
                                                .withValues(alpha: 0.12),
                                        borderRadius:
                                            BorderRadius.circular(14),
                                        border: Border.all(
                                          color: selected
                                              ? Colors.white
                                              : Colors.transparent,
                                          width: 2,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          '$n',
                                          style: TextStyle(
                                            color: selected
                                                ? const Color(
                                                    0xFF4A2F16)
                                                : Colors.white,
                                            fontSize: 22,
                                            fontWeight:
                                                FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const StaggeredIn(
                          index: 2,
                          child: Text('Player names',
                              style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(height: 8),
                        for (var i = 0; i < _playerCount; i++)
                          Padding(
                            padding:
                                const EdgeInsets.only(bottom: 10),
                            child: StaggeredIn(
                              index: 3 + i,
                              child: TextField(
                                controller: _nameControllers[i],
                                maxLength: 14,
                                style: const TextStyle(
                                    color: Colors.white),
                                decoration: InputDecoration(
                                  counterText: '',
                                  filled: true,
                                  fillColor: Colors.white
                                      .withValues(alpha: 0.12),
                                  border: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  prefixIcon: Icon(
                                      Icons.person,
                                      color: _chipColor(i)),
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 6),
                        const StaggeredIn(
                          index: 7,
                          child: Text(
                            'Everyone shares this phone — pass it around when the banner tells you whose turn it is.',
                            style: TextStyle(
                                color: Colors.white54, fontSize: 12),
                          ),
                        ),
                      ],
                      const SizedBox(height: 28),
                      StaggeredIn(
                        index: 8,
                        child: BouncyButton(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF43A047),
                              Color(0xFF2E7D32)
                            ],
                          ),
                          onTap: _start,
                          child: const Center(
                            child: Text('Start Game',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
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

  Widget _difficultyCard(Difficulty d) {
    final selected = _difficulty == d;
    return GestureDetector(
      onTap: () => setState(() => _difficulty = d),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFFFB300)
              : Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? Colors.white : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              d == Difficulty.easy
                  ? Icons.sentiment_satisfied
                  : d == Difficulty.medium
                      ? Icons.psychology
                      : Icons.bolt,
              color:
                  selected ? const Color(0xFF4A2F16) : Colors.white,
              size: 30,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    d.label,
                    style: TextStyle(
                      color: selected
                          ? const Color(0xFF4A2F16)
                          : Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    d.blurb,
                    style: TextStyle(
                      color: selected
                          ? const Color(0xFF6B4A26)
                          : Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle,
                  color: Color(0xFF4A2F16)),
          ],
        ),
      ),
    );
  }

  Color _chipColor(int i) =>
      const [Colors.lightBlue, Colors.orange, Colors.purple, Colors.teal][
          i % 4];
}
