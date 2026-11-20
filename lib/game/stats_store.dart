/// Persistent record of finished games, plus aggregate stats.
///
/// Records live in SharedPreferences as JSON (newest first, capped).
/// The summary math is pure Dart and unit-tested.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'game_state.dart';

/// One player's result in a finished game.
class PlayerResult {
  final String name;
  final int score;
  final bool isAI;
  final String? bestWord;
  final int bestWordScore;

  const PlayerResult({
    required this.name,
    required this.score,
    required this.isAI,
    this.bestWord,
    this.bestWordScore = 0,
  });

  factory PlayerResult.fromPlayer(Player p) => PlayerResult(
        name: p.name,
        score: p.score,
        isAI: p.isAI,
        bestWord: p.bestWord,
        bestWordScore: p.bestWordScore,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'score': score,
        'ai': isAI,
        'bw': bestWord,
        'bws': bestWordScore,
      };

  factory PlayerResult.fromJson(Map<String, dynamic> j) => PlayerResult(
        name: j['name'] as String,
        score: j['score'] as int,
        isAI: j['ai'] as bool? ?? false,
        bestWord: j['bw'] as String?,
        bestWordScore: j['bws'] as int? ?? 0,
      );
}

/// A finished game.
class GameRecord {
  final DateTime date;
  final bool vsComputer;

  /// The computer's difficulty (vs-computer games only).
  final Difficulty? difficulty;
  final List<PlayerResult> players;
  final int winnerIndex;

  const GameRecord({
    required this.date,
    required this.vsComputer,
    required this.difficulty,
    required this.players,
    required this.winnerIndex,
  });

  factory GameRecord.fromGame(
    GameState game, {
    required bool vsComputer,
    Difficulty? difficulty,
    DateTime? now,
  }) {
    return GameRecord(
      date: now ?? DateTime.now(),
      vsComputer: vsComputer,
      difficulty: vsComputer ? difficulty : null,
      players: game.players.map(PlayerResult.fromPlayer).toList(),
      winnerIndex: game.winnerIndex ?? 0,
    );
  }

  PlayerResult get winner => players[winnerIndex];

  /// In a vs-computer game, did a human win?
  bool get humanWon => vsComputer && !winner.isAI;

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'vs': vsComputer,
        'diff': difficulty?.name,
        'players': players.map((p) => p.toJson()).toList(),
        'winner': winnerIndex,
      };

  factory GameRecord.fromJson(Map<String, dynamic> j) => GameRecord(
        date: DateTime.parse(j['date'] as String),
        vsComputer: j['vs'] as bool? ?? false,
        difficulty: (j['diff'] as String?) == null
            ? null
            : Difficulty.values.byName(j['diff'] as String),
        players: (j['players'] as List)
            .map((p) =>
                PlayerResult.fromJson((p as Map).cast<String, dynamic>()))
            .toList(),
        winnerIndex: j['winner'] as int? ?? 0,
      );
}

/// Aggregates over a list of records.
class StatsSummary {
  final int totalGames;
  final int vsComputerGames;
  final int humanWinsVsComputer;
  final int passPlayGames;

  /// Best single-game score by any human player.
  final int highestScore;

  /// Best word ever played by a human, and its score.
  final String? bestWord;
  final int bestWordScore;

  /// Per-difficulty (played, humanWon) for vs-computer games.
  final Map<Difficulty, (int, int)> byDifficulty;

  const StatsSummary({
    required this.totalGames,
    required this.vsComputerGames,
    required this.humanWinsVsComputer,
    required this.passPlayGames,
    required this.highestScore,
    required this.bestWord,
    required this.bestWordScore,
    required this.byDifficulty,
  });

  double get winRateVsComputer =>
      vsComputerGames == 0 ? 0 : humanWinsVsComputer / vsComputerGames;
}

StatsSummary summarize(List<GameRecord> records) {
  var vsGames = 0;
  var humanWins = 0;
  var passGames = 0;
  var highest = 0;
  String? bestWord;
  var bestWordScore = 0;
  final byDiff = <Difficulty, (int, int)>{};
  for (final r in records) {
    if (r.vsComputer) {
      vsGames++;
      if (r.humanWon) humanWins++;
      final d = r.difficulty;
      if (d != null) {
        final cur = byDiff[d] ?? (0, 0);
        byDiff[d] = (cur.$1 + 1, cur.$2 + (r.humanWon ? 1 : 0));
      }
    } else {
      passGames++;
    }
    for (final p in r.players) {
      if (p.isAI) continue;
      if (p.score > highest) highest = p.score;
      if (p.bestWord != null && p.bestWordScore > bestWordScore) {
        bestWord = p.bestWord;
        bestWordScore = p.bestWordScore;
      }
    }
  }
  return StatsSummary(
    totalGames: records.length,
    vsComputerGames: vsGames,
    humanWinsVsComputer: humanWins,
    passPlayGames: passGames,
    highestScore: highest,
    bestWord: bestWord,
    bestWordScore: bestWordScore,
    byDifficulty: byDiff,
  );
}

/// Loads/saves game records in SharedPreferences.
class StatsStore {
  static const String _key = 'tw_game_records_v1';
  static const int maxRecords = 200;

  static Future<List<GameRecord>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? const [];
    final records = <GameRecord>[];
    for (final s in raw) {
      try {
        records.add(GameRecord.fromJson(
            (jsonDecode(s) as Map).cast<String, dynamic>()));
      } catch (_) {
        // Skip a corrupt entry rather than losing the whole history.
      }
    }
    return records;
  }

  /// Adds [record] as the newest entry, capping the stored history.
  static Future<void> record(GameRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final records = await load();
    records.insert(0, record);
    final capped = records.take(maxRecords).toList();
    await prefs.setStringList(
        _key, capped.map((r) => jsonEncode(r.toJson())).toList());
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
