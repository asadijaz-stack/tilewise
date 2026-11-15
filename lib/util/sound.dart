/// Tiny sound manager: synthesized WAVs, loaded once, fire-and-forget.
/// Never throws — silence is always an acceptable fallback.
library;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

class SoundManager {
  static final SoundManager _instance = SoundManager._internal();
  factory SoundManager() => _instance;
  SoundManager._internal();

  AudioPlayer? _player;
  final Map<String, Uint8List> _sounds = {};
  bool _ready = false;

  Future<void> init() async {
    try {
      const names = ['click', 'place', 'invalid', 'win', 'turn', 'shuffle'];
      for (final n in names) {
        final data = await rootBundle.load('assets/sounds/$n.wav');
        _sounds[n] = data.buffer.asUint8List();
      }
      _player = AudioPlayer();
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  Future<void> play(String name) async {
    if (!_ready) return;
    try {
      final bytes = _sounds[name];
      if (bytes == null || bytes.isEmpty) return;
      await _player!.play(BytesSource(bytes));
    } catch (_) {
      // Stay silent rather than crash the game.
    }
  }
}
