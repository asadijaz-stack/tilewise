/// Turn engine: players, bag, scoring and AI turns.
///
/// The UI observes this [ChangeNotifier] and drains [GameEvent]s to drive
/// animations (score popups, shake on invalid moves, banners, confetti).
library;

import 'dart:math';

import 'package:flutter/foundation.dart';

import 'ai.dart';
import 'ai_engine.dart';
import 'board.dart';
import 'dictionary.dart';
import 'rules.dart';
import 'tiles.dart';

enum Difficulty { easy, medium, hard }

extension DifficultyInfo on Difficulty {
  String get label => switch (this) {
        Difficulty.easy => 'Easy',
        Difficulty.medium => 'Medium',
        Difficulty.hard => 'Hard',
      };

  String get blurb => switch (this) {
        Difficulty.easy => 'Plays for fun, misses the big scores.',
        Difficulty.medium => 'Solid club player. Watch the triple words!',
        Difficulty.hard => 'Thinks longer and punishes open boards.',
      };

  /// How long the AI searches, in milliseconds.
  int get budgetMs => switch (this) {
        Difficulty.easy => 300,
        Difficulty.medium => 900,
        Difficulty.hard => 2200,
      };
}

class Player {
  final String name;
  final bool isAI;
  final Difficulty difficulty;
  final int colorIndex;
  int score = 0;

  /// Rack letters; '' is a blank tile.
  final List<String> rack = [];
  String? bestWord;
  int bestWordScore = 0;

  Player({
    required this.name,
    required this.isAI,
    required this.difficulty,
    required this.colorIndex,
  });
}

/// A tile the human has staged on the board this turn (not yet submitted).
class StagedTile {
  final int rackIndex;
  final String letter; // blank's assigned letter, or the tile's own letter
  final bool isBlank;
  StagedTile({
    required this.rackIndex,
    required this.letter,
    required this.isBlank,
  });
}

// ---------------------------------------------------------------------------
// Events (drained by the UI to drive animations)
// ---------------------------------------------------------------------------

sealed class GameEvent {}

class ScorePopupEvent extends GameEvent {
  final int playerIndex;
  final int points;
  final bool bingo;
  ScorePopupEvent(this.playerIndex, this.points, this.bingo);
}

class InvalidMoveEvent extends GameEvent {
  final String message;
  InvalidMoveEvent(this.message);
}

class TurnBannerEvent extends GameEvent {
  final int playerIndex;
  TurnBannerEvent(this.playerIndex);
}

class ThinkingEvent extends GameEvent {
  final bool thinking;
  ThinkingEvent(this.thinking);
}

class InfoEvent extends GameEvent {
  final String message;
  InfoEvent(this.message);
}

class GameOverEvent extends GameEvent {}

// ---------------------------------------------------------------------------

class GameState extends ChangeNotifier {
  final GameBoard board = GameBoard();
  final List<Tile> bag;
  final List<Player> players;
  final Dictionary dict;
  final AiEngine? aiEngine;

  int turn = 0;
  bool firstMove = true;
  bool gameOver = false;
  String? gameOverReason;
  int consecutivePasses = 0;

  /// Increments every time tiles land (drives tile entrance animations).
  int moveId = 0;
  int? winnerIndex;

  /// Announcement of the last AI move, e.g. 'Computer played QUIZ — 32 pts'.
  String? aiMoveLabel;

  /// Board cells of the last AI move ('row,col'), highlighted in amber.
  final Set<String> lastAiMoveKeys = {};

  int _announceToken = 0;

  /// Staged placements this turn: 'row,col' -> tile.
  final Map<String, StagedTile> staged = {};

  /// Rack indices currently sitting on the board as staged tiles.
  final Set<int> stagedRackIndices = {};

  /// Tap-selected rack index for the tap-to-place flow.
  int? selectedRackIndex;

  /// Exchange-mode selection.
  final Set<int> exchangeSelection = {};
  bool exchangeMode = false;

  bool _aiThinking = false;
  final List<GameEvent> _events = [];

  GameState({
    required this.players,
    required this.dict,
    required this.aiEngine,
    int? seed,
  }) : bag = newBag(seed: seed) {
    for (final p in players) {
      _drawTiles(p, 7);
    }
  }

  Player get currentPlayer => players[turn];

  bool get canStage => !gameOver && !currentPlayer.isAI && !_aiThinking;

  List<GameEvent> drainEvents() {
    final copy = List<GameEvent>.of(_events);
    _events.clear();
    return copy;
  }

  void _emit(GameEvent e) {
    _events.add(e);
    notifyListeners();
  }

  void _drawTiles(Player p, int n) {
    for (var i = 0; i < n && bag.isNotEmpty; i++) {
      p.rack.add(bag.removeLast().letter);
    }
  }

  int _rackValue(List<String> rack) =>
      rack.fold(0, (sum, l) => sum + (tileValues[l] ?? 0));

  // ------------------------- human staging -------------------------

  /// Stages a rack tile onto a board cell.
  /// Returns false when the placement is not allowed right now.
  /// Blank tiles need [blankLetter].
  bool stageTile(int rackIndex, int row, int col, {String? blankLetter}) {
    if (!canStage) return false;
    if (rackIndex < 0 || rackIndex >= currentPlayer.rack.length) return false;
    if (stagedRackIndices.contains(rackIndex)) return false;
    if (!GameBoard.inBounds(row, col) || board.letterAt(row, col) != null) {
      return false;
    }
    final key = '$row,$col';
    if (staged.containsKey(key)) return false;
    final raw = currentPlayer.rack[rackIndex];
    if (raw.isEmpty) {
      if (blankLetter == null || blankLetter.isEmpty) return false;
      staged[key] =
          StagedTile(rackIndex: rackIndex, letter: blankLetter, isBlank: true);
    } else {
      staged[key] =
          StagedTile(rackIndex: rackIndex, letter: raw, isBlank: false);
    }
    stagedRackIndices.add(rackIndex);
    selectedRackIndex = null;
    notifyListeners();
    return true;
  }

  /// Returns a staged tile to the rack.
  void unstageTile(int row, int col) {
    final key = '$row,$col';
    final s = staged.remove(key);
    if (s != null) {
      stagedRackIndices.remove(s.rackIndex);
      notifyListeners();
    }
  }

  void clearStaged() {
    if (staged.isEmpty && selectedRackIndex == null) return;
    staged.clear();
    stagedRackIndices.clear();
    selectedRackIndex = null;
    notifyListeners();
  }

  void selectRack(int rackIndex) {
    if (!canStage) return;
    if (rackIndex < 0 ||
        rackIndex >= currentPlayer.rack.length ||
        stagedRackIndices.contains(rackIndex)) {
      return;
    }
    selectedRackIndex = selectedRackIndex == rackIndex ? null : rackIndex;
    notifyListeners();
  }

  /// The currently staged tiles, as placements.
  List<PlacedTile> stagedPlacements() {
    return staged.entries.map((e) {
      final parts = e.key.split(',');
      final s = e.value;
      return PlacedTile(
        row: int.parse(parts[0]),
        col: int.parse(parts[1]),
        letter: s.letter,
        isBlank: s.isBlank,
      );
    }).toList();
  }

  /// Live preview of the staged tiles: the word(s) and score if the
  /// move were submitted now, or the reason it is not legal yet.
  /// Null when nothing is staged.
  MoveResult? previewStaged() {
    if (staged.isEmpty) return null;
    return evaluateMove(
      board: board,
      placements: stagedPlacements(),
      dict: dict,
      isFirstMove: firstMove,
    );
  }

  /// Stages every tile of [placements] (e.g. a hinted move), matching
  /// each placement to a rack tile. All-or-nothing: returns false and
  /// stages nothing when the rack cannot supply a tile.
  bool stageMove(List<PlacedTile> placements) {
    if (!canStage || placements.isEmpty) return false;
    final rack = currentPlayer.rack;
    final used = <int>{...stagedRackIndices};
    final plan = <(int, PlacedTile)>[];
    for (final p in placements) {
      var found = -1;
      for (var i = 0; i < rack.length; i++) {
        if (used.contains(i)) continue;
        final ok = p.isBlank ? rack[i].isEmpty : rack[i] == p.letter;
        if (ok) {
          found = i;
          break;
        }
      }
      if (found < 0) return false;
      used.add(found);
      plan.add((found, p));
    }
    for (final (rackIndex, p) in plan) {
      final ok = stageTile(rackIndex, p.row, p.col,
          blankLetter: p.isBlank ? p.letter : null);
      if (!ok) {
        clearStaged();
        return false;
      }
    }
    return true;
  }

  /// Submits the staged tiles as the current player's move.
  void submitMove() {
    if (!canStage || staged.isEmpty) return;
    final placements = stagedPlacements();
    final res = evaluateMove(
      board: board,
      placements: placements,
      dict: dict,
      isFirstMove: firstMove,
    );
    if (!res.valid) {
      _emit(InvalidMoveEvent(res.error ?? 'Invalid move'));
      return;
    }
    final player = currentPlayer;
    moveId++;
    board.applyPlacements(placements, moveId: moveId);
    board.consumePremiums(placements);
    player.score += res.score;
    for (final w in res.words) {
      if (w.score > player.bestWordScore) {
        player.bestWordScore = w.score;
        player.bestWord = w.word;
      }
    }
    final used = staged.values.map((s) => s.rackIndex).toList()
      ..sort((a, b) => b.compareTo(a));
    for (final i in used) {
      player.rack.removeAt(i);
    }
    _drawTiles(player, used.length);
    _afterMove(res.score, res.bingo);
  }

  /// Shows the AI's move (label + tile highlight) for a few seconds.
  /// Call [clearAiMoveAnnouncement] to hide it sooner.
  void announceAiMove(String label, List<PlacedTile> placements) {
    final token = ++_announceToken;
    aiMoveLabel = label;
    lastAiMoveKeys
      ..clear()
      ..addAll(placements.map((p) => p.key));
    notifyListeners();
    Future.delayed(const Duration(seconds: 5), () {
      if (token == _announceToken) clearAiMoveAnnouncement();
    });
  }

  void clearAiMoveAnnouncement() {
    if (aiMoveLabel == null && lastAiMoveKeys.isEmpty) return;
    aiMoveLabel = null;
    lastAiMoveKeys.clear();
    notifyListeners();
  }

  void _afterMove(int score, bool bingo) {
    clearAiMoveAnnouncement();
    staged.clear();
    stagedRackIndices.clear();
    selectedRackIndex = null;
    exchangeMode = false;
    exchangeSelection.clear();
    consecutivePasses = 0;
    firstMove = false;
    final playedIndex = turn;
    _emit(ScorePopupEvent(playedIndex, score, bingo));
    _nextTurn();
  }

  void _nextTurn() {
    if (_checkGameEnd()) return;
    turn = (turn + 1) % players.length;
    if (currentPlayer.isAI) {
      _runAiTurn();
    } else {
      _emit(TurnBannerEvent(turn));
    }
  }

  // ------------------------- pass / exchange -------------------------

  /// Official end-game rule: the game ends after SIX consecutive
  /// scoreless turns (passes, exchanges, or turns with no play).
  static const int scorelessTurnsToEndGame = 6;

  /// Registers a scoreless turn. Returns true when the game just ended.
  bool _registerScorelessTurn() {
    consecutivePasses++;
    if (consecutivePasses >= scorelessTurnsToEndGame) {
      _endGame('Six scoreless turns in a row');
      return true;
    }
    return false;
  }

  void passTurn() {
    if (!canStage) return;
    clearAiMoveAnnouncement();
    clearStaged();
    _emit(InfoEvent('${currentPlayer.name} passes'));
    if (_registerScorelessTurn()) return;
    _nextTurn();
  }

  void toggleExchangeMode() {
    if (!canStage) return;
    exchangeMode = !exchangeMode;
    exchangeSelection.clear();
    notifyListeners();
  }

  void toggleExchangeTile(int rackIndex) {
    if (!exchangeMode || !canStage) return;
    if (!exchangeSelection.remove(rackIndex)) {
      exchangeSelection.add(rackIndex);
    }
    notifyListeners();
  }

  void confirmExchange() {
    if (!canStage || !exchangeMode || exchangeSelection.isEmpty) return;
    if (bag.length < 7) {
      _emit(InvalidMoveEvent('Not enough tiles left to exchange'));
      return;
    }
    final player = currentPlayer;
    final idxs = exchangeSelection.toList()..sort((a, b) => b.compareTo(a));
    final returned = <String>[];
    for (final i in idxs) {
      returned.add(player.rack.removeAt(i));
    }
    _drawTiles(player, returned.length);
    for (final letter in returned) {
      bag.add(Tile(letter));
    }
    bag.shuffle();
    clearAiMoveAnnouncement();
    exchangeMode = false;
    exchangeSelection.clear();
    _emit(InfoEvent('${player.name} swaps ${returned.length} tiles'));
    if (_registerScorelessTurn()) return;
    _nextTurn();
  }

  void shuffleRack() {
    if (!canStage) return;
    currentPlayer.rack.shuffle();
    notifyListeners();
  }

  // ------------------------- AI -------------------------

  /// Picks the AI's move with human-like fallibility per difficulty.
  /// [moves] must be sorted best-first (the generator guarantees this).
  AiMove _pickMove(List<AiMove> moves, Difficulty difficulty, Random rng) {
    switch (difficulty) {
      case Difficulty.easy:
        // Plays like a casual beginner: picks from the weaker half
        // of the ideas it found.
        final weaker = moves.sublist(moves.length ~/ 2);
        return weaker[rng.nextInt(weaker.length)];
      case Difficulty.medium:
        // Solid club player: usually the best move, but punts into
        // the top 8 about a third of the time.
        if (moves.length > 1 && rng.nextDouble() < 0.35) {
          final top = moves.take(8).toList();
          return top[rng.nextInt(top.length)];
        }
        return moves.first;
      case Difficulty.hard:
        // Near-optimal, with a rare human slip into the top 3.
        if (moves.length > 1 && rng.nextDouble() < 0.15) {
          final top = moves.take(3).toList();
          return top[rng.nextInt(top.length)];
        }
        return moves.first;
    }
  }

  Future<void> _runAiTurn() async {
    if (gameOver) return;
    _aiThinking = true;
    _emit(ThinkingEvent(true));
    // Let the thinking indicator paint before the heavy work starts.
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (gameOver) return;

    List<AiMove> moves = const [];
    try {
      final engine = aiEngine;
      if (engine != null) {
        final res = await engine.findMoves(
          board: board,
          rack: currentPlayer.rack.toList(),
          budgetMs: currentPlayer.difficulty.budgetMs,
          // Easy and Medium only know everyday words, like a human
          // opponent. Hard gets the full tournament vocabulary.
          commonVocabulary: currentPlayer.difficulty != Difficulty.hard,
        );
        moves = res.moves;
      }
    } catch (_) {
      moves = const [];
    }

    _aiThinking = false;
    _emit(ThinkingEvent(false));
    if (gameOver) return;

    AiMove? chosen;
    if (moves.isNotEmpty) {
      chosen = _pickMove(moves, currentPlayer.difficulty, Random());
    }

    if (chosen == null) {
      if (bag.length >= 7 && currentPlayer.rack.isNotEmpty) {
        final n = min(currentPlayer.rack.length, 7);
        final returned = currentPlayer.rack.sublist(0, n).toList();
        currentPlayer.rack.removeRange(0, n);
        _drawTiles(currentPlayer, n);
        for (final letter in returned) {
          bag.add(Tile(letter));
        }
        bag.shuffle();
        _emit(InfoEvent('${currentPlayer.name} swaps tiles'));
      } else {
        _emit(InfoEvent('${currentPlayer.name} passes'));
      }
      if (_registerScorelessTurn()) return;
      _nextTurn();
      return;
    }

    // Validate against the untouched board first...
    final res = evaluateMove(
      board: board,
      placements: chosen.placements,
      dict: dict,
      isFirstMove: firstMove,
    );
    if (!res.valid) {
      _emit(InfoEvent('${currentPlayer.name} passes'));
      if (_registerScorelessTurn()) return;
      _nextTurn();
      return;
    }

    // ...then land the tiles one by one for a lively animation.
    final player = currentPlayer;
    final playedIndex = turn;
    for (final p in chosen.placements) {
      moveId++;
      board.applyPlacements([p], moveId: moveId);
      notifyListeners();
      await Future<void>.delayed(const Duration(milliseconds: 280));
      if (gameOver) return;
    }
    board.consumePremiums(chosen.placements);
    player.score += res.score;
    for (final w in res.words) {
      if (w.score > player.bestWordScore) {
        player.bestWordScore = w.score;
        player.bestWord = w.word;
      }
    }
    _removeRackTiles(player, chosen.placements);
    _drawTiles(player, chosen.placements.length);
    staged.clear();
    stagedRackIndices.clear();
    consecutivePasses = 0;
    firstMove = false;
    _emit(ScorePopupEvent(playedIndex, res.score, res.bingo));
    // Tell the human what the computer just played: the main word
    // (res.words.first) plus the score, and highlight its tiles.
    final mainWord = res.words.isNotEmpty ? res.words.first.word : '';
    announceAiMove(
      '${player.name} played $mainWord — ${res.score} pts'
      '${res.bingo ? '  BINGO!' : ''}',
      chosen.placements,
    );
    _nextTurn();
  }

  void _removeRackTiles(Player player, List<PlacedTile> placements) {
    for (final p in placements) {
      if (p.isBlank) {
        player.rack.remove('');
      } else {
        player.rack.remove(p.letter);
      }
    }
  }

  // ------------------------- game end -------------------------

  bool _checkGameEnd() {
    if (gameOver) return true;
    if (bag.isEmpty) {
      for (var i = 0; i < players.length; i++) {
        if (players[i].rack.isEmpty) {
          _endGame('${players[i].name} played their last tile',
              rackOutPlayer: i);
          return true;
        }
      }
    }
    return false;
  }

  void _endGame(String reason, {int? rackOutPlayer}) {
    gameOver = true;
    gameOverReason = reason;
    if (rackOutPlayer != null) {
      var bonus = 0;
      for (var i = 0; i < players.length; i++) {
        if (i == rackOutPlayer) continue;
        final v = _rackValue(players[i].rack);
        players[i].score -= v;
        bonus += v;
      }
      players[rackOutPlayer].score += bonus;
    } else {
      // Nobody went out (the game ended by scoreless turns): every
      // player deducts the value of the tiles left on their own rack.
      for (final p in players) {
        p.score -= _rackValue(p.rack);
      }
    }
    var best = -1000000;
    winnerIndex = 0;
    for (var i = 0; i < players.length; i++) {
      if (players[i].score > best) {
        best = players[i].score;
        winnerIndex = i;
      }
    }
    _emit(GameOverEvent());
  }
}
