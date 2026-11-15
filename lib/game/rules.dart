/// Move validation and scoring (pure Dart, shared by the UI and the AI).
library;

import 'board.dart';
import 'dictionary.dart';
import 'tiles.dart';

/// One tile placed (or about to be placed) on the board.
class PlacedTile {
  final int row;
  final int col;

  /// Actual board letter (a blank's assigned letter).
  final String letter;
  final bool isBlank;

  const PlacedTile({
    required this.row,
    required this.col,
    required this.letter,
    this.isBlank = false,
  });

  String get key => '$row,$col';

  Map<String, dynamic> toJson() => {
        'r': row,
        'c': col,
        'ch': letter,
        'blank': isBlank,
      };

  factory PlacedTile.fromJson(Map<String, dynamic> json) => PlacedTile(
        row: json['r'] as int,
        col: json['c'] as int,
        letter: json['ch'] as String,
        isBlank: json['blank'] as bool? ?? false,
      );
}

/// A word formed by a move, with its individual score.
class ScoredWord {
  final String word;
  final int score;
  const ScoredWord(this.word, this.score);
}

/// The outcome of validating (and scoring) a move.
class MoveResult {
  final bool valid;
  final String? error;
  final int score;
  final List<ScoredWord> words;
  final bool bingo;

  const MoveResult._(
      this.valid, this.error, this.score, this.words, this.bingo);

  factory MoveResult.ok(int score, List<ScoredWord> words, bool bingo) =>
      MoveResult._(true, null, score, words, bingo);

  factory MoveResult.invalid(String error) =>
      MoveResult._(false, error, 0, const [], false);
}

/// Plain-words version of a move error, for the on-screen coach that
/// teaches new players. Technical errors become friendly guidance.
String friendlyMoveError(String error) {
  if (error.startsWith('Not in dictionary:')) {
    final word = error.substring('Not in dictionary:'.length).trim();
    return '“$word” is not a word. Try different letters.';
  }
  return switch (error) {
    'The first word must cover the center star' =>
      'Your first word must touch the ★ star in the middle.',
    'The first word needs 2+ letters' => 'A word needs at least 2 letters.',
    'Tiles must connect with no gaps' =>
      'No empty squares inside a word — keep your letters side by side.',
    'The word must connect to existing tiles' =>
      'Your word must touch letters that are already on the board.',
    'Tiles must be in one row or column' =>
      'Tiles go in one straight line — one row, or one column.',
    'That square is already taken' => 'That square already has a tile.',
    _ => error,
  };
}

/// Validates and scores [placements] against [board].
///
/// [direction]: 0 = across, 1 = down, null = auto-detect (a single tile
/// tries both directions and keeps the better valid one).
MoveResult evaluateMove({
  required GameBoard board,
  required List<PlacedTile> placements,
  required Dictionary dict,
  required bool isFirstMove,
  int? direction,
}) {
  if (placements.isEmpty) {
    return MoveResult.invalid('Place at least one tile');
  }

  final placedKeys = <String>{};
  for (final p in placements) {
    if (!GameBoard.inBounds(p.row, p.col)) {
      return MoveResult.invalid('Tile is off the board');
    }
    if (board.letterAt(p.row, p.col) != null) {
      return MoveResult.invalid('That square is already taken');
    }
    if (!placedKeys.add(p.key)) {
      return MoveResult.invalid('Two tiles on the same square');
    }
    if (p.letter.length != 1 || !RegExp(r'^[A-Z]$').hasMatch(p.letter)) {
      return MoveResult.invalid('Bad tile letter');
    }
  }

  int? dir = direction;
  if (dir == null) {
    if (placements.length == 1) {
      // Single tile: try across, then down; keep the better valid result.
      final across = _evaluateDirected(
        board: board,
        placements: placements,
        dict: dict,
        isFirstMove: isFirstMove,
        dir: 0,
      );
      final down = _evaluateDirected(
        board: board,
        placements: placements,
        dict: dict,
        isFirstMove: isFirstMove,
        dir: 1,
      );
      if (across.valid && down.valid) {
        return across.score >= down.score ? across : down;
      }
      if (across.valid) return across;
      if (down.valid) return down;
      return MoveResult.invalid(
          down.error ?? across.error ?? 'Not a valid word');
    }
    final sameRow = placements.every((p) => p.row == placements.first.row);
    final sameCol = placements.every((p) => p.col == placements.first.col);
    if (sameRow && !sameCol) {
      dir = 0;
    } else if (sameCol && !sameRow) {
      dir = 1;
    } else {
      return MoveResult.invalid('Tiles must be in one row or column');
    }
  }

  return _evaluateDirected(
    board: board,
    placements: placements,
    dict: dict,
    isFirstMove: isFirstMove,
    dir: dir,
  );
}

MoveResult _evaluateDirected({
  required GameBoard board,
  required List<PlacedTile> placements,
  required Dictionary dict,
  required bool isFirstMove,
  required int dir, // 0 = across, 1 = down
}) {
  final dr = dir == 0 ? 0 : 1;
  final dc = dir == 0 ? 1 : 0;
  final placedKeys = placements.map((p) => p.key).toSet();
  final placedByKey = {for (final p in placements) p.key: p};

  String letterAtRun(int r, int c) {
    final p = placedByKey['$r,$c'];
    if (p != null) return p.letter;
    return board.letterAt(r, c)!;
  }

  // Sort along the direction and extend the run over existing tiles.
  final sorted = List<PlacedTile>.from(placements)
    ..sort(
        (a, b) => dir == 0 ? a.col.compareTo(b.col) : a.row.compareTo(b.row));
  var r0 = sorted.first.row, c0 = sorted.first.col;
  var r1 = sorted.last.row, c1 = sorted.last.col;
  while (true) {
    final nr = r0 - dr, nc = c0 - dc;
    if (!GameBoard.inBounds(nr, nc) || board.letterAt(nr, nc) == null) break;
    r0 = nr;
    c0 = nc;
  }
  while (true) {
    final nr = r1 + dr, nc = c1 + dc;
    if (!GameBoard.inBounds(nr, nc) || board.letterAt(nr, nc) == null) break;
    r1 = nr;
    c1 = nc;
  }

  // The run must have no gaps.
  final runCells = <(int, int)>[];
  var r = r0, c = c0;
  while (true) {
    final isPlaced = placedKeys.contains('$r,$c');
    if (!isPlaced && board.letterAt(r, c) == null) {
      return MoveResult.invalid('Tiles must connect with no gaps');
    }
    runCells.add((r, c));
    if (r == r1 && c == c1) break;
    r += dr;
    c += dc;
  }
  final mainWord = runCells.map((cell) => letterAtRun(cell.$1, cell.$2)).join();

  if (isFirstMove) {
    if (runCells.length < 2) {
      return MoveResult.invalid('The first word needs 2+ letters');
    }
    if (!runCells.any((cell) => cell.$1 == 7 && cell.$2 == 7)) {
      return MoveResult.invalid('The first word must cover the center star');
    }
  } else {
    // Must connect: overlap an existing tile or touch one orthogonally.
    var connected =
        runCells.any((cell) => !placedKeys.contains('${cell.$1},${cell.$2}'));
    if (!connected) {
      const nbrs = [(1, 0), (-1, 0), (0, 1), (0, -1)];
      for (final p in placements) {
        for (final n in nbrs) {
          final nr = p.row + n.$1, nc = p.col + n.$2;
          if (GameBoard.inBounds(nr, nc) &&
              board.letterAt(nr, nc) != null &&
              !placedKeys.contains('$nr,$nc')) {
            connected = true;
            break;
          }
        }
        if (connected) break;
      }
    }
    if (!connected) {
      return MoveResult.invalid('The word must connect to existing tiles');
    }
  }

  int scoreRun(List<(int, int)> cells) {
    var letters = 0;
    var wordMult = 1;
    for (final cell in cells) {
      final idx = GameBoard.index(cell.$1, cell.$2);
      final key = '${cell.$1},${cell.$2}';
      final isNew = placedKeys.contains(key);
      final blank = isNew ? placedByKey[key]!.isBlank : board.isBlank[idx];
      var lv = blank ? 0 : (tileValues[letterAtRun(cell.$1, cell.$2)] ?? 0);
      if (isNew && !board.premiumUsed[idx]) {
        switch (premiumAt(cell.$1, cell.$2)) {
          case Premium.doubleLetter:
            lv *= 2;
          case Premium.tripleLetter:
            lv *= 3;
          case Premium.doubleWord:
            wordMult *= 2;
          case Premium.tripleWord:
            wordMult *= 3;
          case Premium.star:
            wordMult *= 2;
          case Premium.none:
            break;
        }
      }
      letters += lv;
    }
    return letters * wordMult;
  }

  final scoredWords = <ScoredWord>[];
  var total = 0;

  // Main word along the direction of play.
  if (mainWord.length >= 2) {
    if (!dict.contains(mainWord)) {
      return MoveResult.invalid('Not in dictionary: $mainWord');
    }
    final s = scoreRun(runCells);
    scoredWords.add(ScoredWord(mainWord, s));
    total += s;
  }

  // Perpendicular cross words for every placed tile.
  final pdr = dc, pdc = dr;
  for (final p in placements) {
    var ar = p.row - pdr, ac = p.col - pdc;
    final before = <(int, int)>[];
    while (GameBoard.inBounds(ar, ac) && board.letterAt(ar, ac) != null) {
      before.add((ar, ac));
      ar -= pdr;
      ac -= pdc;
    }
    var br = p.row + pdr, bc = p.col + pdc;
    final after = <(int, int)>[];
    while (GameBoard.inBounds(br, bc) && board.letterAt(br, bc) != null) {
      after.add((br, bc));
      br += pdr;
      bc += pdc;
    }
    if (before.isEmpty && after.isEmpty) continue;
    final cells = [...before.reversed, (p.row, p.col), ...after];
    final word = cells.map((cell) => letterAtRun(cell.$1, cell.$2)).join();
    if (!dict.contains(word)) {
      return MoveResult.invalid('Not in dictionary: $word');
    }
    final s = scoreRun(cells);
    scoredWords.add(ScoredWord(word, s));
    total += s;
  }

  if (scoredWords.isEmpty) {
    return MoveResult.invalid('The word must connect to existing tiles');
  }

  final bingo = placements.length == 7;
  if (bingo) total += 50;

  return MoveResult.ok(total, scoredWords, bingo);
}
