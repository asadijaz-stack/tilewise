/// Animated background: drifting translucent tile letters over a slowly
/// shifting green-felt gradient.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

class _FloatTile {
  final String letter;
  final double x, y, speed, sway, phase, size, rot;
  _FloatTile({
    required this.letter,
    required this.x,
    required this.y,
    required this.speed,
    required this.sway,
    required this.phase,
    required this.size,
    required this.rot,
  });
}

class FloatingTilesBackground extends StatefulWidget {
  final Widget child;
  const FloatingTilesBackground({super.key, required this.child});

  @override
  State<FloatingTilesBackground> createState() =>
      _FloatingTilesBackgroundState();
}

class _FloatingTilesBackgroundState extends State<FloatingTilesBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final List<_FloatTile> _tiles;

  @override
  void initState() {
    super.initState();
    final rng = math.Random(42);
    const letters = 'TILEWISEABCDFGH';
    _tiles = List.generate(
      16,
      (i) => _FloatTile(
        letter: letters[rng.nextInt(letters.length)],
        x: rng.nextDouble(),
        y: rng.nextDouble(),
        speed: 0.015 + rng.nextDouble() * 0.045,
        sway: 12 + rng.nextDouble() * 26,
        phase: rng.nextDouble() * math.pi * 2,
        size: 30 + rng.nextDouble() * 34,
        rot: (rng.nextDouble() - 0.5) * 0.7,
      ),
    );
    _c = AnimationController(
        vsync: this, duration: const Duration(seconds: 36))
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
      builder: (_, __) {
        final t = _c.value;
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(
                    const Color(0xFF1E6B2E), const Color(0xFF0C3A1C), t)!,
                Color.lerp(
                    const Color(0xFF2F8A3E), const Color(0xFF175C28), t)!,
              ],
            ),
          ),
          child: Stack(
            children: [
              CustomPaint(
                painter: _FloatPainter(_tiles, t),
                size: Size.infinite,
              ),
              widget.child,
            ],
          ),
        );
      },
    );
  }
}

class _FloatPainter extends CustomPainter {
  final List<_FloatTile> tiles;
  final double t;
  _FloatPainter(this.tiles, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    for (final tile in tiles) {
      final y = (((tile.y - t * tile.speed) % 1.2) - 0.1) * size.height;
      final x = tile.x * size.width +
          math.sin(t * math.pi * 2 + tile.phase) * tile.sway;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(tile.rot + math.sin(t * math.pi * 2 + tile.phase) * 0.15);
      final s = tile.size;
      final rect = Rect.fromCenter(
          center: Offset.zero, width: s, height: s);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(s * 0.16)),
        Paint()..color = Colors.white.withValues(alpha: 0.08),
      );
      final tp = TextPainter(
        text: TextSpan(
          text: tile.letter,
          style: TextStyle(
            fontSize: s * 0.55,
            fontWeight: FontWeight.w800,
            color: Colors.white.withValues(alpha: 0.13),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
          canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _FloatPainter old) => old.t != t;
}
