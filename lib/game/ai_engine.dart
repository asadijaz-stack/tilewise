/// Persistent isolate for AI move generation.
///
/// The trie is built once inside the isolate; each AI turn sends the board
/// and rack and gets candidate moves back. This keeps the UI thread free so
/// animations stay smooth while the computer "thinks".
library;

import 'dart:async';
import 'dart:isolate';

import 'ai.dart';
import 'board.dart';
import 'dictionary.dart';

class AiResponse {
  final List<AiMove> moves;
  AiResponse(this.moves);
}

class AiEngine {
  final SendPort _send;
  final ReceivePort _receive;
  final Stream<dynamic> _broadcast;
  int _nextId = 0;
  bool _ready = false;

  AiEngine._(this._send, this._receive, this._broadcast);

  static Future<AiEngine> create() async {
    final receive = ReceivePort();
    // Convert to broadcast BEFORE the first listen: a ReceivePort's stream
    // is single-subscription, so `await receive.first` followed by
    // `asBroadcastStream()` throws "already been listened to".
    final broadcast = receive.asBroadcastStream();
    await Isolate.spawn(_aiIsolateEntry, receive.sendPort);
    final sendPort = await broadcast.first as SendPort;
    return AiEngine._(sendPort, receive, broadcast);
  }

  /// Sends the word lists once; completes when the tries are built.
  /// [commonWords] is the everyday vocabulary for the weaker difficulties.
  Future<void> init(List<String> words, List<String> commonWords) {
    final completer = Completer<void>();
    late StreamSubscription sub;
    sub = _broadcast.listen((msg) {
      if (msg is Map && msg['type'] == 'ready') {
        _ready = true;
        sub.cancel();
        completer.complete();
      }
    });
    _send.send({'type': 'init', 'words': words, 'commonWords': commonWords});
    return completer.future;
  }

  bool get isReady => _ready;

  Future<AiResponse> findMoves({
    required GameBoard board,
    required List<String> rack,
    required int budgetMs,
    int maxMoves = 60,
    bool commonVocabulary = false,
  }) {
    if (!_ready) throw StateError('AiEngine not initialized');
    final id = _nextId++;
    final completer = Completer<AiResponse>();
    late StreamSubscription sub;
    sub = _broadcast.listen((msg) {
      if (msg is Map && msg['type'] == 'result' && msg['id'] == id) {
        sub.cancel();
        final moves = (msg['moves'] as List)
            .map((m) => AiMove.fromJson((m as Map).cast<String, dynamic>()))
            .toList();
        completer.complete(AiResponse(moves));
      }
    });
    _send.send({
      'type': 'gen',
      'id': id,
      'board': board.letters.toList(),
      'rack': rack.toList(),
      'budgetMs': budgetMs,
      'maxMoves': maxMoves,
      'vocab': commonVocabulary ? 'common' : 'full',
    });
    return completer.future;
  }

  void dispose() {
    try {
      _send.send({'type': 'bye'});
    } catch (_) {}
    _receive.close();
  }
}

void _aiIsolateEntry(SendPort mainPort) {
  final port = ReceivePort();
  mainPort.send(port.sendPort);
  MoveGenerator? gen;
  port.listen((message) {
    final msg = (message as Map).cast<String, dynamic>();
    switch (msg['type']) {
      case 'init':
        final words = (msg['words'] as List).cast<String>();
        final common = (msg['commonWords'] as List).cast<String>();
        gen = MoveGenerator(
          trieFull: Trie.fromWords(words),
          dictFull: Dictionary.fromWords(words),
          trieCommon: Trie.fromWords(common),
          dictCommon: Dictionary.fromWords(common),
        );
        mainPort.send({'type': 'ready'});
      case 'gen':
        final g = gen;
        if (g == null) {
          mainPort.send({'type': 'result', 'id': msg['id'], 'moves': []});
          return;
        }
        final board =
            GameBoard.fromLetters((msg['board'] as List).cast<String?>());
        final moves = g.generate(
          board: board,
          rack: (msg['rack'] as List).cast<String>(),
          budgetMs: msg['budgetMs'] as int,
          maxMoves: msg['maxMoves'] as int? ?? 60,
          commonOnly: msg['vocab'] == 'common',
        );
        mainPort.send({
          'type': 'result',
          'id': msg['id'],
          'moves': moves.map((m) => m.toJson()).toList(),
        });
      case 'bye':
        port.close();
    }
  });
}
