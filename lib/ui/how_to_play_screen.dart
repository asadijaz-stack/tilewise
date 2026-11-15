/// Visual, step-by-step guide for brand-new players.
///
/// Written in very simple words and shown with the game's own tiles
/// and colors, so a first-time player understands the whole game
/// before their first move.
library;

import 'package:flutter/material.dart';

import 'widgets.dart';

class HowToPlayScreen extends StatelessWidget {
  const HowToPlayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F3D1F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'How to Play',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
                children: [
                  _step(
                    0,
                    emoji: '🎯',
                    title: 'Make words, score points',
                    body: 'Put your letter tiles on the board to make '
                        'words. The player with the most points at the '
                        'end wins!',
                    visual: _wordTiles(),
                  ),
                  _step(
                    1,
                    emoji: '👆',
                    title: 'Placing tiles',
                    body: 'Drag a tile onto the board — or tap a tile, '
                        'then tap a square. Made a mistake? Tap a tile '
                        'on the board to pick it back up.',
                  ),
                  _step(
                    2,
                    emoji: '★',
                    title: 'The first word',
                    body: 'The very first word must cover the pink ★ '
                        'star in the center of the board, and must '
                        'have 2 or more letters.',
                  ),
                  _step(
                    3,
                    emoji: '🔗',
                    title: 'Words must connect',
                    body: 'After the first word, every new word must '
                        'touch letters already on the board — like a '
                        'crossword puzzle.',
                  ),
                  _step(
                    4,
                    emoji: '🎨',
                    title: 'Bonus squares',
                    body: 'Colored squares boost your score — but '
                        'only the first time a tile lands on them.',
                    visual: _bonusSquares(),
                  ),
                  _step(
                    5,
                    emoji: '✅',
                    title: 'Tap Play Word',
                    body: 'The green bar above your tiles shows your '
                        'word and how many points it makes. If you '
                        'like it, tap the Play Word button.',
                  ),
                  _step(
                    6,
                    emoji: '💡',
                    title: 'Stuck? Tap Hint',
                    body: 'No idea what to play? Tap Hint and the game '
                        'will find a good word with your letters and '
                        'place it for you. Then just tap Play Word.',
                  ),
                  _step(
                    7,
                    emoji: '🔀',
                    title: 'Swap and Pass',
                    body: 'Bad letters? Swap trades them for new ones, '
                        'but it uses your turn. Pass skips your turn '
                        'completely.',
                  ),
                  _step(
                    8,
                    emoji: '🌟',
                    title: 'Bingo! +50 points',
                    body: 'Use all 7 of your tiles in one turn and '
                        'you score 50 extra points. It is called '
                        'a Bingo!',
                  ),
                  _step(
                    9,
                    emoji: '🏆',
                    title: 'How the game ends',
                    body: 'The game ends when the bag of tiles is '
                        'empty and one player plays their last tile — '
                        'or when nobody scores for 6 turns in a row. '
                        'Tiles left in your hand take points away, '
                        'so try to use them all!',
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 16),
              child: BouncyButton(
                gradient: const LinearGradient(
                  colors: [Color(0xFF43A047), Color(0xFF2E7D32)],
                ),
                onTap: () => Navigator.of(context).pop(),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.play_arrow, color: Colors.white, size: 26),
                    SizedBox(width: 10),
                    Text("Let's Play!",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _step(
    int index, {
    required String emoji,
    required String title,
    required String body,
    Widget? visual,
  }) {
    return StaggeredIn(
      index: index,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E4D2B),
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 6),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(emoji, style: const TextStyle(fontSize: 23)),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        body,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14.5,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (visual != null) ...[
              const SizedBox(height: 14),
              Center(child: visual),
            ],
          ],
        ),
      ),
    );
  }

  Widget _wordTiles() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final l in ['C', 'A', 'T'])
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: TileWidget(letter: l, size: 46),
          ),
        const SizedBox(width: 10),
        const Text(
          '= 5 points',
          style: TextStyle(
            color: Colors.amber,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _bonusSquares() {
    const items = <(String, Color, String)>[
      ('DL', Color(0xFF9CCBF5), 'Letter ×2'),
      ('TL', Color(0xFF3D7BC4), 'Letter ×3'),
      ('DW', Color(0xFFF0A8A8), 'Word ×2'),
      ('TW', Color(0xFFD63C3C), 'Word ×3'),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (final (label, color, meaning) in items)
          Column(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                meaning,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
      ],
    );
  }
}
