import 'package:flutter/material.dart';

import '../theme/palette.dart';

/// Shared portal button styling. Deliberately distinct from the native
/// game's flat gradient PLAY button: a rounded pill with the amber →
/// gold gradient, a pressed-scale reaction and a glow shadow that
/// reads well against the marquee artwork.
class NeonPillButton extends StatefulWidget {
  const NeonPillButton({
    super.key,
    required this.label,
    required this.onTap,
    this.tint = Palette.gold,
    this.width,
    this.compact = false,
    this.secondary = false,
  });

  final String label;
  final VoidCallback onTap;

  /// Accent colour used for border + glow (defaults to festival gold).
  final Color tint;
  final double? width;
  final bool compact;

  /// When true renders the muted variant used for "Skip". Still a real
  /// gradient button per .cursor/rules/gray_part_pitfalls.md §12 — the
  /// visual weight difference comes from the darker gradient stops.
  final bool secondary;

  @override
  State<NeonPillButton> createState() => _NeonPillButtonState();
}

class _NeonPillButtonState extends State<NeonPillButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    final List<Color> gradientStops = widget.secondary
        ? const <Color>[Palette.deepPurple, Palette.velvet]
        : const <Color>[Palette.amber, Palette.gold];
    final Color labelColour = widget.secondary
        ? Palette.cream
        : Palette.nightPurple;
    final double vertical = widget.compact ? 12 : 16;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _scale = 0.94),
      onTapCancel: () => setState(() => _scale = 1.0),
      onTapUp: (_) {
        setState(() => _scale = 1.0);
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 90),
        child: Container(
          width: widget.width,
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: vertical),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientStops,
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: widget.tint.withValues(alpha: 0.85),
              width: 2,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: widget.tint.withValues(alpha: 0.55),
                blurRadius: 22,
                spreadRadius: -2,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                widget.label,
                textAlign: TextAlign.center,
                style: Palette.display.copyWith(
                  fontSize: widget.compact ? 15 : 18,
                  color: labelColour,
                  letterSpacing: 1.2,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
