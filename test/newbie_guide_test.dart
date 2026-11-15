/// New-player help: hint staging, live move preview, friendly errors.
import 'package:flutter_test/flutter_test.dart';
import 'package:tilewise/game/dictionary.dart';
import 'package:tilewise/game/game_state.dart';
import 'package:tilewise/game/rules.dart';

GameState _game(List<String> rack) {
  final dict = Dictionary.fromWords(['CAT', 'CATS', 'AT', 'DOG', 'DO']);
  final g = GameState(
    players: [
      Player(
          name: 'You', isAI: false, difficulty: Difficulty.easy, colorIndex: 0),
      Player(
          name: 'Friend',
          isAI: false,
          difficulty: Difficulty.easy,
          colorIndex: 1),
    ],
    dict: dict,
    aiEngine: null,
    seed: 3,
  );
  g.players[0].rack
    ..clear()
    ..addAll(rack);
  return g;
}

void main() {
  test('previewStaged is null with nothing staged', () {
    final g = _game(['C', 'A', 'T', 'D', 'O', 'G', 'S']);
    expect(g.previewStaged(), isNull);
  });

  test('stageMove stages a whole word; preview shows word + score', () {
    final g = _game(['C', 'A', 'T', 'D', 'O', 'G', 'S']);
    final ok = g.stageMove(const [
      PlacedTile(row: 7, col: 6, letter: 'C'),
      PlacedTile(row: 7, col: 7, letter: 'A'),
      PlacedTile(row: 7, col: 8, letter: 'T'),
    ]);
    expect(ok, isTrue);
    expect(g.staged.length, 3);
    final res = g.previewStaged();
    expect(res, isNotNull);
    expect(res!.valid, isTrue);
    expect(res.words.first.word, 'CAT');
    // (3+1+1) doubled by the center star.
    expect(res.score, 10);
  });

  test('stageMove is all-or-nothing when the rack lacks a letter', () {
    final g = _game(['C', 'A', 'T', 'D', 'O', 'G', 'S']);
    final ok = g.stageMove(const [
      PlacedTile(row: 7, col: 6, letter: 'C'),
      PlacedTile(row: 7, col: 7, letter: 'Z'),
    ]);
    expect(ok, isFalse);
    expect(g.staged, isEmpty);
  });

  test('stageMove uses the blank tile for a blank placement', () {
    final g = _game(['', 'A', 'T', 'D', 'O', 'G', 'S']);
    final ok = g.stageMove(const [
      PlacedTile(row: 7, col: 6, letter: 'Q', isBlank: true),
      PlacedTile(row: 7, col: 7, letter: 'A'),
      PlacedTile(row: 7, col: 8, letter: 'T'),
    ]);
    expect(ok, isTrue);
    expect(g.staged['7,6']!.isBlank, isTrue);
    expect(g.staged['7,6']!.letter, 'Q');
  });

  test('previewStaged explains an illegal first word in plain words', () {
    final g = _game(['C', 'A', 'T', 'D', 'O', 'G', 'S']);
    // CAT away from the center star.
    g.stageTile(0, 0, 0);
    g.stageTile(1, 0, 1);
    g.stageTile(2, 0, 2);
    final res = g.previewStaged();
    expect(res!.valid, isFalse);
    expect(friendlyMoveError(res.error!),
        'Your first word must touch the ★ star in the middle.');
  });

  test('friendlyMoveError translates the technical messages', () {
    expect(friendlyMoveError('Not in dictionary: QAT'),
        '“QAT” is not a word. Try different letters.');
    expect(friendlyMoveError('Tiles must connect with no gaps'),
        contains('side by side'));
    expect(friendlyMoveError('The word must connect to existing tiles'),
        contains('touch letters'));
    expect(friendlyMoveError('Tiles must be in one row or column'),
        contains('one straight line'));
    // Unknown errors pass through untouched.
    expect(friendlyMoveError('Something else'), 'Something else');
  });
}
