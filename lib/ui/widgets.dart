/// Shared animated widgets: tiles, popups, chips, confetti, buttons.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/tiles.dart';

/// A wooden letter tile. Empty [letter] renders a blank tile.
class TileWidget extends StatelessWidget {
  final String letter;
  final double size;
  final bool dimmed;

  const TileWidget({
    super.key,
    required this.letter,
    required this.size,
    this.dimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    final value = tileValues[letter] ?? 0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF5DDAE), Color(0xFFDFAF63)],
        ),
        boxShadow: const [
          BoxShadow(
              color: Colors.black38, blurRadius: 3, offset: Offset(0, 2)),
        ],
      ),
      child: Opacity(
        opacity: dimmed ? 0.6 : 1.0,
        child: Stack(
          children: [
            Center(
              child: Text(
                letter.isEmpty ? '★' : letter,
                style: TextStyle(
                  fontSize: size * 0.52,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF4A2F16),
                  height: 1.0,
                ),
              ),
            ),
            if (letter.isNotEmpty)
              Positioned(
                right: size * 0.09,
                bottom: size * 0.05,
                child: Text(
                  '$value',
                  style: TextStyle(
                    fontSize: size * 0.24,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF4A2F16),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Plays a springy scale+fade entrance once when mounted.
/// Parent must give it a fresh key whenever the entrance should replay.
class TileEntrance extends StatefulWidget {
  final Widget child;
  const TileEntrance({super.key, required this.child});

  @override
  State<TileEntrance> createState() => _TileEntranceState();
}

class _TileEntranceState extends State<TileEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 340));
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 0.2, end: 1.0).animate(
        CurvedAnimation(parent: _c, curve: Curves.elasticOut),
      ),
      child: FadeTransition(
        opacity: CurvedAnimation(parent: _c, curve: Curves.easeOut),
        child: widget.child,
      ),
    );
  }
}

/// A letter that flips in with a stagger (menu title).
class FlipIn extends StatelessWidget {
  final int index;
  final Widget child;
  const FlipIn({super.key, required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: -index * 0.22, end: 1.0),
      duration: const Duration(milliseconds: 800),
      builder: (_, v, child) {
        final t = v.clamp(0.0, 1.0);
        final eased = Curves.easeOut.transform(t);
        return Opacity(
          opacity: eased,
          child: Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.002)
              ..rotateY((1 - eased) * math.pi / 2),
            alignment: Alignment.center,
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// Fades + slides a child in with a stagger based on [index].
class StaggeredIn extends StatelessWidget {
  final int index;
  final Widget child;
  const StaggeredIn({super.key, required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: -index * 0.3, end: 1.0),
      duration: const Duration(milliseconds: 650),
      builder: (_, v, child) {
        final t = v.clamp(0.0, 1.0);
        final eased = Curves.easeOutCubic.transform(t);
        return Opacity(
          opacity: eased,
          child: Transform.translate(
            offset: Offset(0, 46 * (1 - eased)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// Floating "+N" score popup that rises and fades, then calls [onDone].
class ScoreFloater extends StatefulWidget {
  final String text;
  final Color color;
  final VoidCallback onDone;
  final double fontSize;
  const ScoreFloater({
    super.key,
    required this.text,
    required this.color,
    required this.onDone,
    this.fontSize = 22,
  });

  @override
  State<ScoreFloater> createState() => _ScoreFloaterState();
}

class _ScoreFloaterState extends State<ScoreFloater>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400));
    _c.forward().then((_) => widget.onDone());
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = _c.value;
        final scale = t < 0.22 ? 0.5 + 0.5 * (t / 0.22) : 1.0;
        final opacity = t < 0.65 ? 1.0 : 1.0 - (t - 0.65) / 0.35;
        return Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, -80 * t),
            child: Transform.scale(
              scale: scale,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: const [
                    BoxShadow(color: Colors.black45, blurRadius: 10)
                  ],
                ),
                child: Text(
                  widget.text,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: widget.fontSize,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Player score chip with an animated count-up and active glow.
class PlayerChip extends StatelessWidget {
  final String name;
  final int score;
  final bool active;
  final Color color;
  final bool isAI;

  const PlayerChip({
    super.key,
    required this.name,
    required this.score,
    required this.active,
    required this.color,
    required this.isAI,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: active ? color : Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: active ? Colors.white : Colors.white24, width: 2),
        boxShadow: active
            ? [
                BoxShadow(
                    color: color.withValues(alpha: 0.55),
                    blurRadius: 12,
                    spreadRadius: 1)
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isAI)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(Icons.smart_toy, size: 13, color: Colors.white),
                ),
              Text(
                name,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12),
              ),
            ],
          ),
          TweenAnimationBuilder<int>(
            tween: IntTween(begin: 0, end: score),
            duration: const Duration(milliseconds: 700),
            builder: (_, v, __) => Text(
              '$v',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 17),
            ),
          ),
        ],
      ),
    );
  }
}

/// Three bouncing dots for the "computer is thinking" indicator.
class ThinkingDots extends StatefulWidget {
  const ThinkingDots({super.key});

  @override
  State<ThinkingDots> createState() => _ThinkingDotsState();
}

class _ThinkingDotsState extends State<ThinkingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final t = (_c.value + i / 3) % 1.0;
          final dy = -7 * math.sin(t * math.pi);
          return Transform.translate(
            offset: Offset(0, dy),
            child: Container(
              width: 9,
              height: 9,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: const BoxDecoration(
                  color: Colors.white, shape: BoxShape.circle),
            ),
          );
        }),
      ),
    );
  }
}

/// Button that squishes on tap.
class BouncyButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final Gradient? gradient;
  final Color? color;

  const BouncyButton({
    super.key,
    required this.child,
    required this.onTap,
    this.gradient,
    this.color,
  });

  @override
  State<BouncyButton> createState() => _BouncyButtonState();
}

class _BouncyButtonState extends State<BouncyButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.93),
      onTapUp: (_) => setState(() => _scale = 1.0),
      onTapCancel: () => setState(() => _scale = 1.0),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
          decoration: BoxDecoration(
            gradient: widget.gradient,
            color: widget.color,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black38, blurRadius: 8, offset: Offset(0, 4)),
            ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Confetti rain for the game-over screen.
class Confetti extends StatefulWidget {
  const Confetti({super.key});

  @override
  State<Confetti> createState() => _ConfettiState();
}

class _Particle {
  double x, y, vx, vy, size, rot, spin;
  Color color;
  _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.color,
    required this.rot,
    required this.spin,
  });
}

class _ConfettiState extends State<Confetti>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  final List<_Particle> _parts = [];

  @override
  void initState() {
    super.initState();
    final rng = math.Random(7);
    const colors = [
      Colors.red,
      Colors.amber,
      Colors.green,
      Colors.lightBlue,
      Colors.purple,
      Colors.orange,
      Colors.pink,
    ];
    for (var i = 0; i < 130; i++) {
      _parts.add(_Particle(
        x: rng.nextDouble(),
        y: -0.15 - rng.nextDouble() * 0.35,
        vx: (rng.nextDouble() - 0.5) * 0.25,
        vy: 0.32 + rng.nextDouble() * 0.5,
        size: 5 + rng.nextDouble() * 8,
        color: colors[rng.nextInt(colors.length)],
        rot: rng.nextDouble() * math.pi * 2,
        spin: (rng.nextDouble() - 0.5) * 12,
      ));
    }
    _c = AnimationController(
        vsync: this, duration: const Duration(seconds: 4))
      ..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => CustomPaint(
        painter: _ConfettiPainter(_parts, _c.value),
        size: Size.infinite,
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> parts;
  final double t;
  _ConfettiPainter(this.parts, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in parts) {
      final x = (p.x + p.vx * t) * size.width;
      final y = (p.y + p.vy * t) * size.height;
      if (y > size.height + 24) continue;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rot + p.spin * t);
      canvas.drawRect(
        Rect.fromCenter(
            center: Offset.zero, width: p.size, height: p.size * 0.62),
        Paint()..color = p.color.withValues(alpha: (1 - t * 0.45).clamp(0.0, 1.0)),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.t != t;
}

/// Slide + fade page transition used across the app.
PageRouteBuilder<T> slideRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 380),
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, anim, __, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return SlideTransition(
        position: Tween(begin: const Offset(0.28, 0), end: Offset.zero)
            .animate(curved),
        child: FadeTransition(opacity: curved, child: child),
      );
    },
  );
}
