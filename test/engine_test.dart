/// Engine tests: tiles, board, rules, AI (all pure Dart).
import 'package:flutter_test/flutter_test.dart';
import 'package:tilewise/game/ai.dart';
import 'package:tilewise/game/ai_engine.dart';
import 'package:tilewise/game/board.dart';
import 'package:tilewise/game/dictionary.dart';
import 'package:tilewise/game/game_state.dart';
import 'package:tilewise/game/rules.dart';
import 'package:tilewise/game/tiles.dart';

List<PlacedTile> _word(int row, int colStart, String word,
    {bool across = true}) {
  return [
    for (var i = 0; i < word.length; i++)
      PlacedTile(
        row: across ? row : row + i,
        col: across ? colStart + i : colStart,
        letter: word[i],
      ),
  ];
}

void main() {
  test('bag has 100 tiles with the right distribution', () {
    final bag = newBag(seed: 7);
    expect(bag.length, 100);
    expect(bag.where((t) => t.letter == 'E').length, 12);
    expect(bag.where((t) => t.letter == 'Q').length, 1);
    expect(bag.where((t) => t.isBlank).length, 2);
    expect(bag.where((t) => t.letter == 'Q').single.value, 10);
    expect(const Tile('').value, 0);
  });

  test('premium layout matches the standard board', () {
    expect(premiumAt(0, 0), Premium.tripleWord);
    expect(premiumAt(7, 7), Premium.star);
    expect(premiumAt(7, 3), Premium.doubleLetter);
    expect(premiumAt(1, 5), Premium.tripleLetter);
    expect(premiumAt(1, 1), Premium.doubleWord);
    var tw = 0, dw = 0, tl = 0, dl = 0, star = 0;
    for (var r = 0; r < 15; r++) {
      for (var c = 0; c < 15; c++) {
        switch (premiumAt(r, c)) {
          case Premium.tripleWord:
            tw++;
          case Premium.doubleWord:
            dw++;
          case Premium.tripleLetter:
            tl++;
          case Premium.doubleLetter:
            dl++;
          case Premium.star:
            star++;
          case Premium.none:
            break;
        }
      }
    }
    expect(tw, 8);
    expect(dw, 16);
    expect(tl, 12);
    expect(dl, 24);
    expect(star, 1);
  });

  group('rules', () {
    final dict = Dictionary.fromWords(['HELLO', 'HE', 'WE', 'LOW']);

    test('first move HELLO through center scores 18', () {
      final board = GameBoard();
      final res = evaluateMove(
        board: board,
        placements: _word(7, 7, 'HELLO'),
        dict: dict,
        isFirstMove: true,
      );
      expect(res.valid, isTrue);
      // H(4) on star=DW, E(1), L(1), L(1), O(1x2 on DL) = 9, x2 = 18.
      expect(res.score, 18);
      expect(res.words.single.word, 'HELLO');
    });

    test('first move must cover the center star', () {
      final board = GameBoard();
      final res = evaluateMove(
        board: board,
        placements: _word(5, 5, 'HELLO'),
        dict: dict,
        isFirstMove: true,
      );
      expect(res.valid, isFalse);
    });

    test('first move needs 2+ letters', () {
      final board = GameBoard();
      final res = evaluateMove(
        board: board,
        placements: _word(7, 7, 'H'),
        dict: dict,
        isFirstMove: true,
      );
      expect(res.valid, isFalse);
    });

    test('hooking HE under HELLO scores 5', () {
      final board = GameBoard();
      final first = _word(7, 7, 'HELLO');
      board.applyPlacements(first);
      board.consumePremiums(first);
      final res = evaluateMove(
        board: board,
        placements: [const PlacedTile(row: 8, col: 7, letter: 'E')],
        dict: dict,
        isFirstMove: false,
      );
      expect(res.valid, isTrue);
      // HE down: H(4) + E(1), no fresh premiums.
      expect(res.score, 5);
    });

    test('disconnected placement is rejected', () {
      final board = GameBoard();
      final first = _word(7, 7, 'HELLO');
      board.applyPlacements(first);
      board.consumePremiums(first);
      final res = evaluateMove(
        board: board,
        placements: _word(0, 0, 'WE'),
        dict: dict,
        isFirstMove: false,
      );
      expect(res.valid, isFalse);
    });

    test('non-dictionary word is rejected', () {
      final board = GameBoard();
      final res = evaluateMove(
        board: board,
        placements: _word(7, 7, 'XYZQK'),
        dict: dict,
        isFirstMove: true,
      );
      expect(res.valid, isFalse);
    });

    test('tiles must be in one row or column', () {
      final board = GameBoard();
      final res = evaluateMove(
        board: board,
        placements: const [
          PlacedTile(row: 7, col: 7, letter: 'H'),
          PlacedTile(row: 8, col: 8, letter: 'E'),
        ],
        dict: dict,
        isFirstMove: true,
      );
      expect(res.valid, isFalse);
    });

    test('blank tile scores 0 but the word still counts', () {
      final board = GameBoard();
      final res = evaluateMove(
        board: board,
        placements: const [
          PlacedTile(row: 7, col: 7, letter: 'H'),
          PlacedTile(row: 7, col: 8, letter: 'E', isBlank: true),
        ],
        dict: Dictionary.fromWords(['HE']),
        isFirstMove: true,
      );
      expect(res.valid, isTrue);
      // H(4) on star=DW, blank E = 0 -> (4 + 0) * 2 = 8.
      expect(res.score, 8);
    });
  });

  group('ai', () {
    test('finds HELLO as the best first move', () {
      final dict =
          Dictionary.fromWords(['HELLO', 'HE', 'WE', 'LOW', 'HOW', 'OWL']);
      final gen = MoveGenerator(
        trieFull: Trie.fromWords(dict.words),
        dictFull: dict,
        trieCommon: Trie.fromWords(dict.words),
        dictCommon: dict);
      final moves = gen.generate(
        board: GameBoard(),
        rack: const ['H', 'E', 'L', 'L', 'O', 'A', 'T'],
        budgetMs: 5000,
        maxMoves: 30,
      );
      expect(moves, isNotEmpty);
      expect(moves.first.score, 18);
      final keys = moves.first.placements.map((p) => p.key).toSet();
      expect(keys.contains('7,7'), isTrue);
      // Every returned move must be legal.
      for (final m in moves.take(10)) {
        final res = evaluateMove(
          board: GameBoard(),
          placements: m.placements,
          dict: dict,
          isFirstMove: true,
        );
        expect(res.valid, isTrue, reason: 'illegal AI move generated');
        expect(res.score, m.score);
      }
    });
  });

    test('commonOnly AI only plays everyday words', () {
      final full = Dictionary.fromWords(['HELLO', 'HE', 'XYZQ']);
      final common = Dictionary.fromWords(['HELLO', 'HE']);
      final gen = MoveGenerator(
        trieFull: Trie.fromWords(full.words),
        dictFull: full,
        trieCommon: Trie.fromWords(common.words),
        dictCommon: common,
      );
      final moves = gen.generate(
        board: GameBoard(),
        rack: const ['H', 'E', 'L', 'L', 'O', 'X', 'Q'],
        budgetMs: 3000,
        maxMoves: 20,
        commonOnly: true,
      );
      expect(moves, isNotEmpty);
      expect(moves.first.score, 18); // HELLO, not an obscure play
      for (final m in moves) {
        final res = evaluateMove(
          board: GameBoard(),
          placements: m.placements,
          dict: common,
          isFirstMove: true,
        );
        expect(res.valid, isTrue,
            reason: 'AI played a word outside its vocabulary');
      }
    });

  group('game_state', () {
    test('announceAiMove sets label and highlight, clear removes them', () {
      final dict = Dictionary.fromWords(['HELLO', 'HE']);
      final game = GameState(
        players: [
          Player(
              name: 'P1',
              isAI: false,
              difficulty: Difficulty.easy,
              colorIndex: 0),
          Player(
              name: 'CPU',
              isAI: true,
              difficulty: Difficulty.medium,
              colorIndex: 1),
        ],
        dict: dict,
        aiEngine: null,
      );
      game.announceAiMove('CPU played HE — 6 pts', [
        const PlacedTile(row: 7, col: 8, letter: 'H'),
        const PlacedTile(row: 7, col: 9, letter: 'E'),
      ]);
      expect(game.aiMoveLabel, 'CPU played HE — 6 pts');
      expect(game.lastAiMoveKeys, {'7,8', '7,9'});
      game.clearAiMoveAnnouncement();
      expect(game.aiMoveLabel, isNull);
      expect(game.lastAiMoveKeys, isEmpty);
    });

    test('AI turn announces the word it played', () async {
      final dict =
          Dictionary.fromWords(['HELLO', 'HE', 'WE', 'LOW', 'HOW', 'OWL']);
      final engine = await AiEngine.create();
      addTearDown(engine.dispose);
      await engine.init(
        ['HELLO', 'HE', 'WE', 'LOW', 'HOW', 'OWL'],
        ['HELLO', 'HE', 'WE', 'LOW', 'HOW'],
      );
      final game = GameState(
        players: [
          Player(
              name: 'P1',
              isAI: false,
              difficulty: Difficulty.easy,
              colorIndex: 0),
          Player(
              name: 'CPU',
              isAI: true,
              difficulty: Difficulty.medium,
              colorIndex: 1),
        ],
        dict: dict,
        aiEngine: engine,
      );
      // Fixed racks so the game is deterministic.
      game.players[0].rack
        ..clear()
        ..addAll(['H', 'E', 'L', 'L', 'O', 'A', 'B']);
      game.players[1].rack
        ..clear()
        ..addAll(['W', 'E', 'H', 'O', 'L', 'X', 'Y']);
      // Human opens with HELLO across the star.
      for (var i = 0; i < 5; i++) {
        expect(game.stageTile(i, 7, 7 + i), isTrue);
      }
      game.submitMove();
      // AI thinks 700ms, then places its tiles (~280ms each).
      await Future<void>.delayed(const Duration(seconds: 4));
      expect(game.aiMoveLabel, isNotNull);
      expect(game.aiMoveLabel, contains('played'));
      expect(game.lastAiMoveKeys, isNotEmpty);
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('game ends after six scoreless turns, racks deducted', () {
      final dict = Dictionary.fromWords(['HELLO', 'HE']);
      final game = GameState(
        players: [
          Player(
              name: 'P1',
              isAI: false,
              difficulty: Difficulty.easy,
              colorIndex: 0),
          Player(
              name: 'P2',
              isAI: false,
              difficulty: Difficulty.easy,
              colorIndex: 1),
        ],
        dict: dict,
        aiEngine: null,
      );
      game.players[0].rack
        ..clear()
        ..addAll(['Q', 'A']); // 11 points of tiles
      game.players[1].rack
        ..clear()
        ..addAll(['Z']); // 10 points of tiles
      game.players[0].score = 100;
      game.players[1].score = 90;
      // Five scoreless turns: the game must still be running.
      for (var i = 0; i < 5; i++) {
        game.passTurn();
        expect(game.gameOver, isFalse);
      }
      game.passTurn(); // sixth scoreless turn ends the game
      expect(game.gameOver, isTrue);
      // Nobody went out: each player deducts their own rack value.
      expect(game.players[0].score, 100 - 11);
      expect(game.players[1].score, 90 - 10);
      expect(game.winnerIndex, 0);
    });

    test('going out adds opponents rack values to the finisher', () {
      final dict = Dictionary.fromWords(['HELLO', 'HE']);
      final game = GameState(
        players: [
          Player(
              name: 'P1',
              isAI: false,
              difficulty: Difficulty.easy,
              colorIndex: 0),
          Player(
              name: 'P2',
              isAI: false,
              difficulty: Difficulty.easy,
              colorIndex: 1),
        ],
        dict: dict,
        aiEngine: null,
      );
      game.bag.clear();
      game.players[0].rack
        ..clear()
        ..addAll(['H', 'E', 'L', 'L', 'O']);
      game.players[1].rack
        ..clear()
        ..addAll(['Q']); // 10 points of tiles
      for (var i = 0; i < 5; i++) {
        expect(game.stageTile(i, 7, 7 + i), isTrue);
      }
      game.submitMove(); // plays the last tile with an empty bag
      expect(game.gameOver, isTrue);
      // HELLO: O sits on a double-letter, so (4+1+1+1+2) x2 on the
      // star = 18, plus Q's 10 points for going out.
      expect(game.players[0].score, 28);
      expect(game.players[1].score, -10);
      expect(game.winnerIndex, 0);
    });

    test('human move applies score and advances the turn', () {
      final dict = Dictionary.fromWords(['HELLO', 'HE']);
      final game = GameState(
        players: [
          Player(
              name: 'P1',
              isAI: false,
              difficulty: Difficulty.medium,
              colorIndex: 0),
          Player(
              name: 'P2',
              isAI: false,
              difficulty: Difficulty.medium,
              colorIndex: 1),
        ],
        dict: dict,
        aiEngine: null,
        seed: 3,
      );
      // Fix P1's rack so the test is deterministic.
      game.players[0].rack
        ..clear()
        ..addAll(['H', 'E', 'L', 'L', 'O', 'A', 'B']);
      for (var i = 0; i < 5; i++) {
        expect(game.stageTile(i, 7, 7 + i), isTrue);
      }
      game.submitMove();
      expect(game.players[0].score, 18);
      expect(game.turn, 1);
      expect(game.board.letterAt(7, 9), 'L');
      expect(game.firstMove, isFalse);
    });

    test('invalid move emits an event and keeps staged tiles', () {
      final dict = Dictionary.fromWords(['HELLO']);
      final game = GameState(
        players: [
          Player(
              name: 'P1',
              isAI: false,
              difficulty: Difficulty.medium,
              colorIndex: 0),
          Player(
              name: 'P2',
              isAI: false,
              difficulty: Difficulty.medium,
              colorIndex: 1),
        ],
        dict: dict,
        aiEngine: null,
        seed: 3,
      );
      game.players[0].rack
        ..clear()
        ..addAll(['X', 'Y', 'Z', 'Q', 'J', 'A', 'B']);
      // Not covering the center star -> invalid first move.
      expect(game.stageTile(0, 0, 0), isTrue);
      expect(game.stageTile(1, 0, 1), isTrue);
      game.submitMove();
      final events = game.drainEvents();
      expect(events.whereType<InvalidMoveEvent>(), isNotEmpty);
      expect(game.staged.length, 2);
      expect(game.turn, 0);
    });
  });
}
