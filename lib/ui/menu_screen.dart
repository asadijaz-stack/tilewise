/// Animated main menu.
library;

import 'package:flutter/material.dart';

import '../game/ai_engine.dart';
import '../game/dictionary.dart';
import 'animated_background.dart';
import 'how_to_play_screen.dart';
import 'setup_screen.dart';
import 'stats_screen.dart';
import 'widgets.dart';

class MenuScreen extends StatelessWidget {
  final Dictionary dict;
  final AiEngine aiEngine;

  const MenuScreen({super.key, required this.dict, required this.aiEngine});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FloatingTilesBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Flipping tile title.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      'TILEWISE'.length,
                      (i) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: FlipIn(
                          index: i,
                          child: TileWidget(letter: 'TILEWISE'[i], size: 38),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const StaggeredIn(
                    index: 8,
                    child: Text(
                      'O F F L I N E   W O R D   G A M E',
                      style: TextStyle(
                        color: Colors.white70,
                        letterSpacing: 3,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 44),
                  StaggeredIn(
                    index: 0,
                    child: BouncyButton(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF43A047), Color(0xFF2E7D32)],
                      ),
                      onTap: () => Navigator.of(context).push(
                        slideRoute(SetupScreen(
                          mode: SetupMode.vsAi,
                          dict: dict,
                          aiEngine: aiEngine,
                        )),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.smart_toy, color: Colors.white, size: 26),
                          SizedBox(width: 12),
                          Text('Play vs Computer',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  StaggeredIn(
                    index: 1,
                    child: BouncyButton(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8D6E3F), Color(0xFF6D4C2F)],
                      ),
                      onTap: () => Navigator.of(context).push(
                        slideRoute(SetupScreen(
                          mode: SetupMode.passPlay,
                          dict: dict,
                          aiEngine: aiEngine,
                        )),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.group, color: Colors.white, size: 26),
                          SizedBox(width: 12),
                          Text('Pass & Play (2–4)',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  StaggeredIn(
                    index: 2,
                    child: BouncyButton(
                      color: Colors.white.withValues(alpha: 0.14),
                      onTap: () => Navigator.of(context).push(
                        slideRoute(const StatsScreen()),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bar_chart, color: Colors.white, size: 24),
                          SizedBox(width: 12),
                          Text('Your Stats',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  StaggeredIn(
                    index: 3,
                    child: BouncyButton(
                      color: Colors.white.withValues(alpha: 0.14),
                      onTap: () => Navigator.of(context).push(
                        slideRoute(const HowToPlayScreen()),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.help_outline,
                              color: Colors.white, size: 24),
                          SizedBox(width: 12),
                          Text('How to Play',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),
                  const StaggeredIn(
                    index: 4,
                    child: Text(
                      'No internet needed • Free forever',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
