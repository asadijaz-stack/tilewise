/// 15x15 board model and the standard premium-square layout.
library;

import 'rules.dart' show PlacedTile;

/// Premium squares. [star] is the center square: double-word on first use.
enum Premium { none, doubleLetter, tripleLetter, doubleWord, tripleWord, star }

/// Row strings: t=triple word, d=double word, 3=triple letter,
/// 2=double letter, *=center star, .=normal.
const List<String> _premiumRows = [
  't..2...t...2..t',
  '.d...3...3...d.',
  '..d...2.2...d..',
  '2..d...2...d..2',
  '....d.....d....',
  '.3...3...3...3.',
  '..2...2.2...2..',
  't..2...*...2..t',
  '..2...2.2...2..',
  '.3...3...3...3.',
  '....d.....d....',
  '2..d...2...d..2',
  '..d...2.2...d..',
  '.d...3...3...d.',
  't..2...t...2..t',
];

/// Premium at a board coordinate.
Premium premiumAt(int row, int col) {
  switch (_premiumRows[row][col]) {
    case 't':
      return Premium.tripleWord;
    case 'd':
      return Premium.doubleWord;
    case '3':
      return Premium.tripleLetter;
    case '2':
      return Premium.doubleLetter;
    case '*':
      return Premium.star;
    default:
      return Premium.none;
  }
}

/// Mutable board state: letters, blank flags and consumed premiums.
/// Row-major, 225 cells.
class GameBoard {
  final List<String?> letters = List<String?>.filled(225, null);
  final List<bool> isBlank = List<bool>.filled(225, false);
  final List<bool> premiumUsed = List<bool>.filled(225, false);

  /// Which move number placed each tile (drives tile entrance animations).
  final List<int> moveIds = List<int>.filled(225, 0);

  GameBoard();

  GameBoard.fromLetters(List<String?> source) {
    for (var i = 0; i < 225; i++) {
      letters[i] = source[i];
    }
  }

  static int index(int row, int col) => row * 15 + col;
  static bool inBounds(int row, int col) =>
      row >= 0 && row < 15 && col >= 0 && col < 15;

  String? letterAt(int row, int col) => letters[index(row, col)];

  bool get isEmpty => letters.every((l) => l == null);

  int get filledCount => letters.where((l) => l != null).length;

  /// Permanently commits placements to the board.
  void applyPlacements(List<PlacedTile> placements, {int moveId = 0}) {
    for (final p in placements) {
      final i = index(p.row, p.col);
      letters[i] = p.letter;
      isBlank[i] = p.isBlank;
      moveIds[i] = moveId;
    }
  }

  /// Marks premium squares under [placements] as consumed.
  void consumePremiums(List<PlacedTile> placements) {
    for (final p in placements) {
      premiumUsed[index(p.row, p.col)] = true;
    }
  }

  GameBoard clone() {
    final b = GameBoard();
    b.letters.setAll(0, letters);
    b.isBlank.setAll(0, isBlank);
    b.premiumUsed.setAll(0, premiumUsed);
    b.moveIds.setAll(0, moveIds);
    return b;
  }
}
