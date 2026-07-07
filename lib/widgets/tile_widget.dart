import 'package:flutter/material.dart';

import '../app_assets.dart';
import '../game/models.dart';
import '../theme/palette.dart';

/// One of the six magic street tiles. Pulses gold when it is the "real"
/// glowing tile, flickers with the lantern decoy look when it is a fake
/// flash, and sits calm and dim otherwise.
class TileWidget extends StatefulWidget {
  const TileWidget({
    super.key,
    required this.glow,
    required this.onTap,
    required this.accentColor,
  });

  final TileGlowKind glow;
  final VoidCallback onTap;
  final Color accentColor;

  @override
  State<TileWidget> createState() => _TileWidgetState();
}

class _TileWidgetState extends State<TileWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 480),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMagic = widget.glow == TileGlowKind.magic;
    final isFake = widget.glow == TileGlowKind.fake;
    final glowColor = isMagic
        ? Palette.gold
        : (isFake ? Palette.amber : widget.accentColor);

    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) {
          final t = (isMagic || isFake) ? _pulse.value : 0.0;
          final scale = 1.0 + t * 0.06;
          final blur = 10 + t * 22;
          return Transform.scale(
            scale: scale,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: (isMagic || isFake)
                      ? [glowColor.withValues(alpha: 0.85), glowColor.withValues(alpha: 0.45)]
                      : [
                          widget.accentColor.withValues(alpha: 0.28),
                          Palette.nightPurple.withValues(alpha: 0.55),
                        ],
                ),
                border: Border.all(
                  color: (isMagic || isFake)
                      ? glowColor
                      : widget.accentColor.withValues(alpha: 0.55),
                  width: (isMagic || isFake) ? 2.6 : 1.4,
                ),
                boxShadow: (isMagic || isFake)
                    ? [
                        BoxShadow(
                          color: glowColor.withValues(alpha: 0.75),
                          blurRadius: blur,
                          spreadRadius: 1,
                        ),
                      ]
                    : [],
              ),
              alignment: Alignment.center,
              child: isFake
                  ? Image.asset(
                      AppAssets.magicLantern,
                      width: 34,
                      fit: BoxFit.contain,
                    )
                  : Icon(
                      Icons.auto_awesome,
                      color: isMagic
                          ? Colors.white.withValues(alpha: 0.9)
                          : widget.accentColor.withValues(alpha: 0.5),
                      size: isMagic ? 26 : 20,
                    ),
            ),
          );
        },
      ),
    );
  }
}
