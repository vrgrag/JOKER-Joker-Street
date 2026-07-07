import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/palette.dart';

class _ConfettiPiece {
  _ConfettiPiece(Random rng)
    : x = rng.nextDouble(),
      phase = rng.nextDouble(),
      speed = 0.35 + rng.nextDouble() * 0.5,
      size = 6 + rng.nextDouble() * 8,
      swayAmount = 10 + rng.nextDouble() * 24,
      rotationSpeed = (rng.nextBool() ? 1 : -1) * (0.5 + rng.nextDouble()),
      color = [
        Palette.gold,
        Palette.hotPink,
        Palette.emerald,
        Palette.sky,
        Palette.amber,
      ][rng.nextInt(5)];

  final double x;
  final double phase;
  final double speed;
  final double size;
  final double swayAmount;
  final double rotationSpeed;
  final Color color;
}

/// Lightweight, self-contained confetti rain used to celebrate Carnival
/// Fever without pulling in an external particle package.
class ConfettiOverlay extends StatefulWidget {
  const ConfettiOverlay({super.key, this.pieceCount = 26});

  final int pieceCount;

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late final List<_ConfettiPiece> _pieces;
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();

  @override
  void initState() {
    super.initState();
    final rng = Random();
    _pieces = List.generate(widget.pieceCount, (_) => _ConfettiPiece(rng));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            size: Size.infinite,
            painter: _ConfettiPainter(_pieces, _controller.value),
          );
        },
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.t);
  final List<_ConfettiPiece> pieces;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in pieces) {
      final fall = ((t * p.speed) + p.phase) % 1.0;
      final dy = fall * (size.height + 40) - 20;
      final dx =
          p.x * size.width + sin((fall * 2 * pi) + p.phase * 6) * p.swayAmount;
      final angle = fall * 2 * pi * p.rotationSpeed;

      final paint = Paint()..color = p.color.withValues(alpha: 0.9);
      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate(angle);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.5),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => true;
}
