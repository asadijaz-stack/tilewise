/// AI move generation: anchor-based trie search (pure Dart, isolate-safe).
///
/// For every "anchor" (an empty square touching existing tiles, or the
/// center on the first move) and both directions, the generator extends a
/// word left through empty squares with rack tiles, then right through
/// empty/new squares and existing tiles, pruning with the trie and with
/// perpendicular cross-checks. Every candidate is validated and scored
/// with the real rules before it is returned.
library;

import 'dart:math';

import 'board.dart';
import 'dictionary.dart';
import 'rules.dart';
import 'tiles.dart';

/// A candidate move found by the generator.
class AiMove {
  final List<PlacedTile> placements;
  final int score;

  AiMove(this.placements, this.score);

  Map<String, dynamic> toJson() => {
        'score': score,
        'tiles': placements.map((p) => p.toJson()).toList(),
      };

  factory AiMove.fromJson(Map<String, dynamic> json) => AiMove(
        (json['tiles'] as List)
            .map((t) => PlacedTile.fromJson((t as Map).cast<String, dynamic>()))
            .toList(),
        json['score'] as int,
      );
}

class MoveGenerator {
  /// Full tournament-style vocabulary.
  final Trie trieFull;
  final Dictionary dictFull;

  /// Common-words vocabulary: plays like a human opponent.
  final Trie trieCommon;
  final Dictionary dictCommon;

  MoveGenerator({
    required this.trieFull,
    required this.dictFull,
    required this.trieCommon,
    required this.dictCommon,
  });

  /// Finds up to [maxMoves] legal moves, best score first.
  /// Stops searching after [budgetMs] (keeps whatever was found).
  /// With [commonOnly], the AI only knows everyday words.
  List<AiMove> generate({
    required GameBoard board,
    required List<String> rack, // '' = blank
    required int budgetMs,
    required int maxMoves,
    bool commonOnly = false,
    int? seed,
  }) {
    final trie = commonOnly ? trieCommon : trieFull;
    final dict = commonOnly ? dictCommon : dictFull;
    final sw = Stopwatch()..start();
    final found = <AiMove>[];
    final seen = <String>{};
    final rng = seed == null ? Random() : Random(seed);

    final firstMove = board.isEmpty;
    final anchors = <(int, int)>[];
    if (firstMove) {
      anchors.add((7, 7));
    } else {
      for (var r = 0; r < 15; r++) {
        for (var c = 0; c < 15; c++) {
          if (board.letterAt(r, c) != null) continue;
          if (_touchesTile(board, r, c)) anchors.add((r, c));
        }
      }
    }

    // Cross-check cache: for an empty square, which letters keep the
    // perpendicular word valid ('r,c,dir' -> allowed letters).
    final crossCache = <String, Set<String>>{};
    Set<String> crossAllowed(int r, int c, int dir) {
      final key = '$r,$c,$dir';
      return crossCache.putIfAbsent(key, () {
        final pdr = dir == 0 ? 1 : 0;
        final pdc = dir == 0 ? 0 : 1;
        var before = '';
        var rr = r - pdr, cc = c - pdc;
        while (GameBoard.inBounds(rr, cc) && board.letterAt(rr, cc) != null) {
          before = '${board.letterAt(rr, cc)}$before';
          rr -= pdr;
          cc -= pdc;
        }
        var after = '';
        rr = r + pdr;
        cc = c + pdc;
        while (GameBoard.inBounds(rr, cc) && board.letterAt(rr, cc) != null) {
          after += board.letterAt(rr, cc)!;
          rr += pdr;
          cc += pdc;
        }
        if (before.isEmpty && after.isEmpty) return Set.of(allLetters);
        final ok = <String>{};
        for (final ch in allLetters) {
          if (dict.contains('$before$ch$after')) ok.add(ch);
        }
        return ok;
      });
    }

    var aborted = false;
    var nodes = 0;
    void tick() {
      if ((nodes++ & 1023) == 0 && sw.elapsedMilliseconds > budgetMs) {
        aborted = true;
      }
    }

    final rackCounts = <String, int>{};
    for (final t in rack) {
      rackCounts[t] = (rackCounts[t] ?? 0) + 1;
    }

    void maybeRecord(List<PlacedTile> placed, int dir) {
      if (placed.isEmpty || aborted) return;
      final key = StringBuffer()..write('$dir:');
      final sorted = List<PlacedTile>.from(placed)
        ..sort((a, b) => a.key.compareTo(b.key));
      for (final p in sorted) {
        key.write('${p.key}${p.letter}${p.isBlank ? '*' : ''};');
      }
      final k = key.toString();
      if (!seen.add(k)) return;
      final res = evaluateMove(
        board: board,
        placements: List<PlacedTile>.from(placed),
        dict: dict,
        isFirstMove: firstMove,
        direction: dir,
      );
      if (res.valid) {
        found.add(AiMove(List<PlacedTile>.from(placed), res.score));
      }
    }

    void extendRight(
      int ar,
      int ac,
      int r,
      int c,
      int dr,
      int dc,
      TrieNode node,
      Map<String, int> counts,
      List<PlacedTile> placed,
    ) {
      if (aborted) return;
      final dir = dr == 0 ? 0 : 1;
      final isAnchor = (r == ar && c == ac);
      if (!GameBoard.inBounds(r, c)) {
        // Ran off the edge: the word ends at the previous square.
        maybeRecord(placed, dir);
        return;
      }
      final existing = board.letterAt(r, c);
      if (existing != null) {
        // The word may also end right before this existing tile.
        if (!isAnchor) maybeRecord(placed, dir);
        final child = node.children[existing];
        if (child == null) return;
        extendRight(ar, ac, r + dr, c + dc, dr, dc, child, counts, placed);
        return;
      }
      // Empty square: the word may end at the previous square...
      if (!isAnchor) maybeRecord(placed, dir);
      // ...or a tile goes here (the anchor must take one).
      final allowed = crossAllowed(r, c, dir);
      final options = counts.entries.where((e) => e.value > 0).toList();
      for (final e in options) {
        tick();
        if (aborted) return;
        final ch = e.key;
        if (ch.isEmpty) {
          for (final l in allowed) {
            final child = node.children[l];
            if (child == null) continue;
            counts[''] = counts['']! - 1;
            placed.add(PlacedTile(row: r, col: c, letter: l, isBlank: true));
            extendRight(ar, ac, r + dr, c + dc, dr, dc, child, counts, placed);
            placed.removeLast();
            counts[''] = counts['']! + 1;
            if (aborted) return;
          }
        } else {
          if (!allowed.contains(ch)) continue;
          final child = node.children[ch];
          if (child == null) continue;
          counts[ch] = counts[ch]! - 1;
          placed.add(PlacedTile(row: r, col: c, letter: ch));
          extendRight(ar, ac, r + dr, c + dc, dr, dc, child, counts, placed);
          placed.removeLast();
          counts[ch] = counts[ch]! + 1;
          if (aborted) return;
        }
      }
    }

    void extendLeft(
      List<(int, int)> leftCells,
      int cellIdx,
      int remaining,
      int ar,
      int ac,
      int dr,
      int dc,
      TrieNode node,
      Map<String, int> counts,
      List<PlacedTile> placed,
    ) {
      if (aborted) return;
      final dir = dr == 0 ? 0 : 1;
      if (remaining == 0) {
        extendRight(ar, ac, ar, ac, dr, dc, node, counts, placed);
        return;
      }
      final cell = leftCells[cellIdx];
      final allowed = crossAllowed(cell.$1, cell.$2, dir);
      final options = counts.entries.where((e) => e.value > 0).toList();
      for (final e in options) {
        tick();
        if (aborted) return;
        final ch = e.key;
        if (ch.isEmpty) {
          for (final l in allowed) {
            final child = node.children[l];
            if (child == null) continue;
            counts[''] = counts['']! - 1;
            placed.add(PlacedTile(
                row: cell.$1, col: cell.$2, letter: l, isBlank: true));
            extendLeft(leftCells, cellIdx + 1, remaining - 1, ar, ac, dr, dc,
                child, counts, placed);
            placed.removeLast();
            counts[''] = counts['']! + 1;
            if (aborted) return;
          }
        } else {
          if (!allowed.contains(ch)) continue;
          final child = node.children[ch];
          if (child == null) continue;
          counts[ch] = counts[ch]! - 1;
          placed.add(PlacedTile(row: cell.$1, col: cell.$2, letter: ch));
          extendLeft(leftCells, cellIdx + 1, remaining - 1, ar, ac, dr, dc,
              child, counts, placed);
          placed.removeLast();
          counts[ch] = counts[ch]! + 1;
          if (aborted) return;
        }
      }
    }

    final shuffledAnchors = List.of(anchors)..shuffle(rng);
    for (final anchor in shuffledAnchors) {
      for (var dir = 0; dir < 2; dir++) {
        if (aborted) break;
        final dr = dir == 0 ? 0 : 1;
        final dc = dir == 0 ? 1 : 0;
        // Empty squares left of the anchor (farthest first).
        final leftCells = <(int, int)>[];
        var rr = anchor.$1 - dr, cc = anchor.$2 - dc;
        while (GameBoard.inBounds(rr, cc) &&
            board.letterAt(rr, cc) == null &&
            leftCells.length < rack.length) {
          leftCells.add((rr, cc));
          rr -= dr;
          cc -= dc;
        }
        // Place 0..N tiles in the contiguous block ending at the anchor.
        for (var k = 0; k <= leftCells.length && !aborted; k++) {
          extendLeft(leftCells, leftCells.length - k, k, anchor.$1, anchor.$2,
              dr, dc, trie.root, Map.of(rackCounts), <PlacedTile>[]);
        }
      }
      if (aborted) break;
    }

    found.sort((a, b) {
      final s = b.score.compareTo(a.score);
      if (s != 0) return s;
      return b.placements.length.compareTo(a.placements.length);
    });
    return found.take(maxMoves).toList();
  }

  bool _touchesTile(GameBoard board, int r, int c) {
    const nbrs = [(1, 0), (-1, 0), (0, 1), (0, -1)];
    for (final n in nbrs) {
      final nr = r + n.$1, nc = c + n.$2;
      if (GameBoard.inBounds(nr, nc) && board.letterAt(nr, nc) != null) {
        return true;
      }
    }
    return false;
  }
}
