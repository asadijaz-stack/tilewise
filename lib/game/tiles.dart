/// Tile model and the standard 100-tile English distribution.
library;

import 'dart:math';

/// A single letter tile. [letter] is 'A'..'Z'; empty string means a blank tile.
class Tile {
  final String letter;
  const Tile(this.letter);

  bool get isBlank => letter.isEmpty;

  /// Point value of the tile (blanks are worth 0).
  int get value => tileValues[letter] ?? 0;
}

/// Standard English letter values.
const Map<String, int> tileValues = {
  'A': 1, 'B': 3, 'C': 3, 'D': 2, 'E': 1, 'F': 4, 'G': 2, 'H': 4, 'I': 1,
  'J': 8, 'K': 5, 'L': 1, 'M': 3, 'N': 1, 'O': 1, 'P': 3, 'Q': 10, 'R': 1,
  'S': 1, 'T': 1, 'U': 1, 'V': 4, 'W': 4, 'X': 8, 'Y': 4, 'Z': 10,
};

/// How many of each tile go into the bag (blanks included = 100 total).
const Map<String, int> tileCounts = {
  'A': 9, 'B': 2, 'C': 2, 'D': 4, 'E': 12, 'F': 2, 'G': 3, 'H': 2, 'I': 9,
  'J': 1, 'K': 1, 'L': 4, 'M': 2, 'N': 6, 'O': 8, 'P': 2, 'Q': 1, 'R': 6,
  'S': 4, 'T': 6, 'U': 4, 'V': 2, 'W': 2, 'X': 1, 'Y': 2, 'Z': 1, '': 2,
};

/// All 26 letters, handy for AI cross-checks.
const List<String> allLetters = [
  'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
  'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
];

/// Builds a freshly shuffled 100-tile bag.
List<Tile> newBag({int? seed}) {
  final bag = <Tile>[];
  tileCounts.forEach((letter, count) {
    for (var i = 0; i < count; i++) {
      bag.add(Tile(letter));
    }
  });
  bag.shuffle(seed == null ? Random() : Random(seed));
  return bag;
}
