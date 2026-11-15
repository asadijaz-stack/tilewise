/// The game board: drag-and-drop tiles, animated placements, score popups.
library;

import 'dart:math';

import 'package:flutter/material.dart';

import '../game/ai_engine.dart';
import '../game/board.dart';
import '../game/dictionary.dart';
import '../game/game_state.dart';
import '../game/rules.dart';
import '../util/sound.dart';
import 'game_over_screen.dart';
import 'menu_screen.dart';
import 'setup_screen.dart';
import 'widgets.dart';

class _Floater {
  final int id;
  final String text;
  final Color color;
  final double fontSize;
  _Floater(this.id, this.text, this.color, this.fontSize);
}

class BoardScreen extends StatefulWidget {
  final GameState game;
  final GameConfig config;
  final Dictionary dict;
  final AiEngine aiEngine;

  const BoardScreen({
    super.key,
    required this.game,
    required this.config,
    required this.dict,
    required this.aiEngine,
  });

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shakeController;
  final List<_Floater> _floaters = [];
  int _floaterId = 0;
  String? _bannerText;
  int _bannerToken = 0;
  bool _thinking = false;
  bool _hintBusy = false;

  static const _playerColors = [
    Colors.lightBlue,
    Colors.orange,
    Colors.purple,
    Colors.teal,
  ];

  Color _playerColor(int i) => _playerColors[i % _playerColors.length];

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 420));
    widget.game.addListener(_onGameChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showBanner("${widget.game.currentPlayer.name} starts!");
    });
  }

  @override
  void dispose() {
    widget.game.removeListener(_onGameChanged);
    _shakeController.dispose();
    super.dispose();
  }

  // ------------------------- events -------------------------

  void _onGameChanged() {
    final events = widget.game.drainEvents();
    for (final e in events) {
      switch (e) {
        case ScorePopupEvent():
          _addFloater(
            e.bingo ? 'BINGO! +${e.points}' : '+${e.points}',
            e.bingo ? Colors.amber.shade700 : _playerColor(e.playerIndex),
            e.bingo ? 26 : 22,
          );
          SoundManager().play(e.bingo ? 'win' : 'place');
        case InvalidMoveEvent():
          _shake();
          _addFloater(e.message, Colors.red.shade700, 15);
          SoundManager().play('invalid');
        case TurnBannerEvent():
          final p = widget.game.players[e.playerIndex];
          _showBanner("${p.name}'s turn");
          if (!p.isAI) SoundManager().play('turn');
        case ThinkingEvent():
          setState(() => _thinking = e.thinking);
        case InfoEvent():
          _addFloater(e.message, Colors.blueGrey.shade700, 15);
        case GameOverEvent():
          SoundManager().play('win');
          _goToGameOver();
      }
    }
    if (mounted) setState(() {});
  }

  void _addFloater(String text, Color color, double fontSize) {
    if (!mounted) return;
    setState(() {
      _floaters.add(_Floater(_floaterId++, text, color, fontSize));
      if (_floaters.length > 3) _floaters.removeAt(0);
    });
  }

  void _removeFloater(int id) {
    if (!mounted) return;
    setState(() => _floaters.removeWhere((f) => f.id == id));
  }

  void _showBanner(String text) {
    if (!mounted) return;
    final token = ++_bannerToken;
    setState(() => _bannerText = text);
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted && token == _bannerToken) {
        setState(() => _bannerText = null);
      }
    });
  }

  void _shake() {
    _shakeController.forward(from: 0);
  }

  void _goToGameOver() {
    Navigator.of(context).pushReplacement(
      slideRoute(GameOverScreen(
        game: widget.game,
        config: widget.config,
        dict: widget.dict,
        aiEngine: widget.aiEngine,
      )),
    );
  }

  // ------------------------- tile placement -------------------------

  Future<String?> _pickBlankLetter() {
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E4D2B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title:
            const Text('Blank tile = ?', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: 300,
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
            ),
            itemCount: 26,
            itemBuilder: (_, i) {
              final letter = String.fromCharCode(65 + i);
              return GestureDetector(
                onTap: () => Navigator.of(ctx).pop(letter),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5DDAE),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      letter,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: Color(0xFF4A2F16),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _acceptTile(int rackIndex, int r, int c) async {
    final game = widget.game;
    if (!game.canStage) return;
    if (rackIndex < 0 || rackIndex >= game.currentPlayer.rack.length) return;
    final raw = game.currentPlayer.rack[rackIndex];
    String? blankLetter;
    if (raw.isEmpty) {
      blankLetter = await _pickBlankLetter();
      if (blankLetter == null || !mounted) return;
    }
    final ok = game.stageTile(rackIndex, r, c, blankLetter: blankLetter);
    if (ok) SoundManager().play('click');
  }

  void _confirmPass() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E4D2B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Pass your turn?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'Passing too many times in a row ends the game.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Keep playing',
                style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              widget.game.passTurn();
            },
            child: const Text('Pass', style: TextStyle(color: Colors.amber)),
          ),
        ],
      ),
    );
  }

  void _confirmQuit() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E4D2B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Quit game?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Your current game will be lost.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Keep playing',
                style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) =>
                      MenuScreen(dict: widget.dict, aiEngine: widget.aiEngine),
                ),
              );
            },
            child: const Text('Quit', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ------------------------- board -------------------------

  Color _cellColor(Premium premium) {
    return switch (premium) {
      Premium.tripleWord => const Color(0xFFD63C3C),
      Premium.doubleWord => const Color(0xFFF0A8A8),
      Premium.tripleLetter => const Color(0xFF3D7BC4),
      Premium.doubleLetter => const Color(0xFF9CCBF5),
      Premium.star => const Color(0xFFF0A8A8),
      Premium.none => const Color(0xFFEFE3CC),
    };
  }

  Widget _premiumLabel(Premium premium, double cell) {
    final label = switch (premium) {
      Premium.tripleWord => 'TW',
      Premium.doubleWord => 'DW',
      Premium.tripleLetter => 'TL',
      Premium.doubleLetter => 'DL',
      Premium.star => '★',
      Premium.none => '',
    };
    if (label.isEmpty) return const SizedBox.shrink();
    return Text(
      label,
      style: TextStyle(
        fontSize: cell * (premium == Premium.star ? 0.5 : 0.3),
        fontWeight: FontWeight.w800,
        color: premium == Premium.none ? Colors.brown : Colors.white,
      ),
    );
  }

  Widget _cell(int r, int c, double cell) {
    final game = widget.game;
    final key = '$r,$c';
    final idx = GameBoard.index(r, c);
    final letter = game.board.letterAt(r, c);
    final staged = game.staged[key];
    final premium = premiumAt(r, c);
    final tileMoveId = game.board.moveIds[idx];
    final isLastAi = game.lastAiMoveKeys.contains(key);

    Widget content;
    if (letter != null) {
      content = TileEntrance(
        key: ValueKey('b$tileMoveId-$r-$c'),
        child: TileWidget(letter: letter, size: cell * 0.94),
      );
    } else if (staged != null) {
      content = GestureDetector(
        onTap: () => game.unstageTile(r, c),
        child: TileEntrance(
          key: ValueKey('s$key'),
          child: TileWidget(
              letter: staged.letter, size: cell * 0.94, dimmed: true),
        ),
      );
    } else {
      content = _premiumLabel(premium, cell);
    }

    return DragTarget<int>(
      onWillAcceptWithDetails: (_) =>
          game.canStage && letter == null && staged == null,
      onAcceptWithDetails: (d) => _acceptTile(d.data, r, c),
      builder: (context, candidate, rejected) {
        final highlight = candidate.isNotEmpty;
        return GestureDetector(
          onTap: () {
            final sel = game.selectedRackIndex;
            if (sel != null && letter == null && staged == null) {
              _acceptTile(sel, r, c);
            } else if (staged != null) {
              game.unstageTile(r, c);
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.all(0.7),
            decoration: BoxDecoration(
              color: highlight ? Colors.amber : _cellColor(premium),
              borderRadius: BorderRadius.circular(2.5),
              border: highlight
                  ? Border.all(color: Colors.white, width: 1.5)
                  : isLastAi
                      ? Border.all(color: Colors.amber, width: 2.5)
                      : null,
            ),
            child: Center(child: content),
          ),
        );
      },
    );
  }

  Widget _board(double side) {
    final cell = side / 15;
    return AnimatedBuilder(
      animation: _shakeController,
      builder: (_, child) {
        final t = _shakeController.value;
        final dx = 12 * sin(t * pi * 4) * (1 - t);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: Container(
        width: side,
        height: side,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFF5D4023),
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 12)],
        ),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 15,
            mainAxisSpacing: 1,
            crossAxisSpacing: 1,
          ),
          itemCount: 225,
          itemBuilder: (_, i) => _cell(i ~/ 15, i % 15, cell - 1.4),
        ),
      ),
    );
  }

  // ------------------------- rack -------------------------

  /// Face-down tile back (used to hide the computer's rack).
  Widget _tileBack(double tileSize) {
    return Container(
      width: tileSize,
      height: tileSize,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(tileSize * 0.16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8D6E3F), Color(0xFF6D4C2F)],
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 3, offset: Offset(0, 2)),
        ],
      ),
      child: Center(
        child: Text(
          '?',
          style: TextStyle(
            fontSize: tileSize * 0.45,
            fontWeight: FontWeight.w800,
            color: Colors.white.withValues(alpha: 0.55),
          ),
        ),
      ),
    );
  }

  Widget _rack(double tileSize) {
    final game = widget.game;
    final player = game.currentPlayer;
    // Never reveal the computer's tiles.
    if (player.isAI) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          player.rack.length,
          (i) => Padding(
            padding: const EdgeInsets.all(3),
            child: _tileBack(tileSize),
          ),
        ),
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(player.rack.length, (i) {
        if (game.stagedRackIndices.contains(i)) {
          return SizedBox(width: tileSize + 6, height: tileSize + 6);
        }
        final letter = player.rack[i];
        final selected = game.selectedRackIndex == i;
        final inExchange = game.exchangeSelection.contains(i);
        Widget tile = TileWidget(letter: letter, size: tileSize);
        if (selected || inExchange) {
          tile = Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: inExchange ? Colors.redAccent : Colors.amber,
                width: 3,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: tile,
          );
        }
        final tappable = GestureDetector(
          onTap: () {
            if (game.exchangeMode) {
              game.toggleExchangeTile(i);
              SoundManager().play('click');
            } else {
              game.selectRack(i);
              SoundManager().play('click');
            }
          },
          child: tile,
        );
        if (game.exchangeMode || !game.canStage) {
          return Padding(padding: const EdgeInsets.all(3), child: tappable);
        }
        return Padding(
          padding: const EdgeInsets.all(3),
          child: Draggable<int>(
            data: i,
            feedback: Material(
              color: Colors.transparent,
              child: TileWidget(letter: letter, size: tileSize * 1.3),
            ),
            childWhenDragging: SizedBox(width: tileSize, height: tileSize),
            child: tappable,
          ),
        );
      }),
    );
  }

  Widget _rackArea() {
    return LayoutBuilder(builder: (ctx, constraints) {
      final tileSize = ((constraints.maxWidth - 56) / 7.6).clamp(32.0, 50.0);
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF5D4023),
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6)],
        ),
        child: _rack(tileSize),
      );
    });
  }

  // ------------------------- chrome -------------------------

  Widget _topBar() {
    final game = widget.game;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70),
            onPressed: _confirmQuit,
          ),
          const Text(
            'TileWise',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.shopping_bag_outlined,
                    color: Colors.white70, size: 15),
                const SizedBox(width: 4),
                Text(
                  '${game.bag.length}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chipsRow() {
    final game = widget.game;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Row(
        children: List.generate(game.players.length, (i) {
          final p = game.players[i];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: PlayerChip(
              name: p.name,
              score: p.score,
              active: game.turn == i && !game.gameOver,
              color: _playerColor(i),
              isAI: p.isAI,
            ),
          );
        }),
      ),
    );
  }

  Widget _banner() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      transitionBuilder: (child, anim) => SlideTransition(
        position:
            Tween(begin: const Offset(0, -0.6), end: Offset.zero).animate(anim),
        child: FadeTransition(opacity: anim, child: child),
      ),
      child: _bannerText == null
          ? const SizedBox.shrink(key: ValueKey('none'))
          : Container(
              key: ValueKey(_bannerText),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.amber, width: 1.5),
              ),
              child: Text(
                _bannerText!,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16),
              ),
            ),
    );
  }

  /// Strip announcing the computer's last move, e.g.
  /// "Computer played QUIZ — 32 pts". Tap to dismiss.
  Widget _aiMoveStrip() {
    final label = widget.game.aiMoveLabel;
    if (label == null) return const SizedBox.shrink();
    return GestureDetector(
      onTap: widget.game.clearAiMoveAnnouncement,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.amber.shade700,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 6)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.smart_toy, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.close, color: Colors.white70, size: 16),
          ],
        ),
      ),
    );
  }

  // ------------------------- coach + hint -------------------------

  /// Finds a good everyday word for the human's rack and stages it,
  /// so a stuck (or brand-new) player sees exactly what to do.
  Future<void> _onHint() async {
    final game = widget.game;
    if (!game.canStage || game.exchangeMode || _hintBusy) return;
    setState(() => _hintBusy = true);
    try {
      game.clearStaged();
      final res = await widget.aiEngine.findMoves(
        board: game.board,
        rack: game.currentPlayer.rack.toList(),
        budgetMs: 900,
        commonVocabulary: true,
      );
      if (!mounted || !game.canStage || game.exchangeMode) return;
      if (res.moves.isEmpty) {
        _addFloater('No word with these letters — try Swap',
            Colors.blueGrey.shade700, 14);
        return;
      }
      if (game.stageMove(res.moves.first.placements)) {
        SoundManager().play('click');
      }
    } catch (_) {
      // Engine hiccup: stay quiet, the player can keep playing.
    } finally {
      if (mounted) setState(() => _hintBusy = false);
    }
  }

  /// The coach: one friendly line that always tells a human player
  /// what to do next — and, once tiles are staged, shows the word
  /// being formed with its live score (or why it is not legal yet).
  Widget _coachBar() {
    final game = widget.game;
    if (game.gameOver || game.currentPlayer.isAI) {
      return const SizedBox.shrink();
    }
    final String text;
    final Color bg;
    final IconData icon;
    if (game.exchangeMode) {
      icon = Icons.swap_horiz;
      bg = const Color(0xFF1565C0);
      text = 'Tap the tiles you want to trade, then tap Swap.';
    } else if (game.staged.isEmpty) {
      icon = Icons.school_outlined;
      bg = const Color(0xFF37474F);
      text = game.firstMove
          ? 'Spell a word through the ★ star in the middle. '
              'Drag tiles up — or tap a tile, then tap a square.'
          : 'Your turn! Build a word that touches letters on the '
              'board. Stuck? Tap 💡 Hint below.';
    } else {
      final res = game.previewStaged();
      if (res == null) return const SizedBox.shrink();
      if (res.valid) {
        icon = Icons.check_circle;
        bg = const Color(0xFF2E7D32);
        final w = res.words.isNotEmpty ? res.words.first.word : '';
        text = res.bingo
            ? 'BINGO! $w — ${res.score} points! Tap Play Word 🎉'
            : '$w — ${res.score} points ✓ Tap Play Word!';
      } else {
        icon = Icons.info_outline;
        bg = const Color(0xFFB26A00);
        text = friendlyMoveError(res.error ?? 'Not a valid move');
      }
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Container(
        key: ValueKey(text),
        margin: const EdgeInsets.fromLTRB(10, 2, 10, 2),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(color: Colors.black38, blurRadius: 5),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 19),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                  height: 1.25,
                ),
              ),
            ),
            if (_hintBusy)
              const SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.2),
              ),
          ],
        ),
      ),
    );
  }

  Widget _thinkingBar() {
    if (!_thinking) return const SizedBox(height: 6);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          ThinkingDots(),
          SizedBox(width: 10),
          Text('Computer is thinking…',
              style: TextStyle(
                  color: Colors.white70,
                  fontStyle: FontStyle.italic,
                  fontSize: 13)),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, String label, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.35 : 1.0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 21),
            ),
            const SizedBox(height: 3),
            Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _actions() {
    final game = widget.game;
    final canAct = game.canStage;
    if (game.exchangeMode) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          BouncyButton(
            color: Colors.redAccent,
            onTap: game.toggleExchangeMode,
            child: const Text('Cancel',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
          BouncyButton(
            gradient: const LinearGradient(
                colors: [Color(0xFF43A047), Color(0xFF2E7D32)]),
            onTap:
                game.exchangeSelection.isEmpty ? () {} : game.confirmExchange,
            child: Text('Swap ${game.exchangeSelection.length}',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ],
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _iconBtn(
            Icons.shuffle,
            'Shuffle',
            canAct
                ? () {
                    game.shuffleRack();
                    SoundManager().play('shuffle');
                  }
                : null),
        _iconBtn(
            Icons.swap_horiz, 'Swap', canAct ? game.toggleExchangeMode : null),
        _iconBtn(
            Icons.lightbulb, 'Hint', canAct && !_hintBusy ? _onHint : null),
        _iconBtn(Icons.front_hand, 'Pass', canAct ? _confirmPass : null),
        if (game.staged.isNotEmpty)
          _iconBtn(Icons.undo, 'Undo', canAct ? game.clearStaged : null),
        if (game.staged.isNotEmpty)
          BouncyButton(
            gradient: const LinearGradient(
                colors: [Color(0xFFFFB300), Color(0xFFFF8F00)]),
            onTap: game.submitMove,
            child: const Text('Play Word',
                style: TextStyle(
                    color: Color(0xFF4A2F16),
                    fontWeight: FontWeight.w800,
                    fontSize: 16)),
          ),
      ],
    );
  }

  // ------------------------- build -------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F3D1F),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _topBar(),
                _chipsRow(),
                _aiMoveStrip(),
                Expanded(
                  child: Center(
                    child: LayoutBuilder(
                      builder: (ctx, constraints) {
                        final side =
                            min(constraints.maxWidth, constraints.maxHeight);
                        return _board(side);
                      },
                    ),
                  ),
                ),
                _thinkingBar(),
                _coachBar(),
                _rackArea(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 2, 8, 12),
                  child: _actions(),
                ),
              ],
            ),
            Positioned(
              top: 96,
              left: 0,
              right: 0,
              child: Center(child: _banner()),
            ),
            ..._floaters.asMap().entries.map(
                  (e) => Positioned(
                    top: MediaQuery.of(context).size.height * 0.30 + e.key * 62,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: ScoreFloater(
                        key: ValueKey(e.value.id),
                        text: e.value.text,
                        color: e.value.color,
                        fontSize: e.value.fontSize,
                        onDone: () => _removeFloater(e.value.id),
                      ),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
