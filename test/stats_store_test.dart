/// Stats: record serialization, summary math, persistent store.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tilewise/game/dictionary.dart';
import 'package:tilewise/game/game_state.dart';
import 'package:tilewise/game/stats_store.dart';

GameRecord _rec({
  required bool vs,
  Difficulty? diff,
  required List<(String, int, bool)> players, // name, score, isAI
  required int winner,
  String? bestWord,
  int bestWordScore = 0,
}) {
  return GameRecord(
    date: DateTime(2026, 11, 20, 15, 30),
    vsComputer: vs,
    difficulty: diff,
    players: [
      for (var i = 0; i < players.length; i++)
        PlayerResult(
          name: players[i].$1,
          score: players[i].$2,
          isAI: players[i].$3,
          bestWord: i == winner ? bestWord : null,
          bestWordScore: i == winner ? bestWordScore : 0,
        ),
    ],
    winnerIndex: winner,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('GameRecord JSON round-trips', () {
    final r = _rec(
      vs: true,
      diff: Difficulty.hard,
      players: [('You', 214, false), ('Computer', 176, true)],
      winner: 0,
      bestWord: 'QUIZ',
      bestWordScore: 42,
    );
    final back = GameRecord.fromJson(r.toJson());
    expect(back.vsComputer, isTrue);
    expect(back.difficulty, Difficulty.hard);
    expect(back.date, r.date);
    expect(back.winner.name, 'You');
    expect(back.humanWon, isTrue);
    expect(back.players[0].bestWord, 'QUIZ');
    expect(back.players[0].bestWordScore, 42);
    expect(back.players[1].isAI, isTrue);
  });

  test('summarize aggregates wins, difficulties, bests', () {
    final records = [
      _rec(
          vs: true,
          diff: Difficulty.medium,
          players: [('You', 214, false), ('Computer', 176, true)],
          winner: 0,
          bestWord: 'QUIZ',
          bestWordScore: 42),
      _rec(
          vs: true,
          diff: Difficulty.medium,
          players: [('You', 150, false), ('Computer', 190, true)],
          winner: 1),
      _rec(
          vs: true,
          diff: Difficulty.hard,
          players: [('You', 98, false), ('Computer', 240, true)],
          winner: 1),
      _rec(
          vs: false,
          players: [('Sara', 180, false), ('Ali', 165, false)],
          winner: 0,
          bestWord: 'JAZZ',
          bestWordScore: 30),
    ];
    final s = summarize(records);
    expect(s.totalGames, 4);
    expect(s.vsComputerGames, 3);
    expect(s.humanWinsVsComputer, 1);
    expect(s.winRateVsComputer, closeTo(1 / 3, 0.001));
    expect(s.passPlayGames, 1);
    expect(s.byDifficulty[Difficulty.medium], (2, 1));
    expect(s.byDifficulty[Difficulty.hard], (1, 0));
    // Human-only bests: 214 is the top human score; QUIZ 42 > JAZZ 30.
    expect(s.highestScore, 214);
    expect(s.bestWord, 'QUIZ');
    expect(s.bestWordScore, 42);
  });

  test('summarize of no games is all zeros', () {
    final s = summarize(const []);
    expect(s.totalGames, 0);
    expect(s.winRateVsComputer, 0);
    expect(s.highestScore, 0);
    expect(s.bestWord, isNull);
  });

  test('GameRecord.fromGame captures a finished game', () {
    final dict = Dictionary.fromWords(['CAT']);
    final g = GameState(
      players: [
        Player(
            name: 'You',
            isAI: false,
            difficulty: Difficulty.easy,
            colorIndex: 0),
        Player(
            name: 'Computer',
            isAI: true,
            difficulty: Difficulty.hard,
            colorIndex: 1),
      ],
      dict: dict,
      aiEngine: null,
      seed: 5,
    );
    g.players[0].score = 120;
    g.players[0].bestWord = 'CAT';
    g.players[0].bestWordScore = 10;
    g.players[1].score = 90;
    g.winnerIndex = 0;
    final r =
        GameRecord.fromGame(g, vsComputer: true, difficulty: Difficulty.hard);
    expect(r.humanWon, isTrue);
    expect(r.difficulty, Difficulty.hard);
    expect(r.players[0].score, 120);
    expect(r.players[0].bestWord, 'CAT');
    expect(r.players[1].isAI, isTrue);
  });

  test('StatsStore records newest-first and loads them back', () async {
    SharedPreferences.setMockInitialValues({});
    await StatsStore.clear();
    final a = _rec(
        vs: false, players: [('A', 10, false), ('B', 5, false)], winner: 0);
    final b = _rec(
        vs: false, players: [('A', 20, false), ('B', 5, false)], winner: 0);
    await StatsStore.record(a);
    await StatsStore.record(b);
    final loaded = await StatsStore.load();
    expect(loaded.length, 2);
    expect(loaded.first.players.first.score, 20); // newest first
    expect(loaded.last.players.first.score, 10);
    await StatsStore.clear();
    expect(await StatsStore.load(), isEmpty);
  });
}
