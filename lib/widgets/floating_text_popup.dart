import 'package:flutter/material.dart';

import '../theme/palette.dart';

/// A short-lived "+18" style popup with a golden burst behind it, used to
/// celebrate a successful tile tap.
class FloatingTextPopup extends StatefulWidget {
  const FloatingTextPopup({
    super.key,
    required this.text,
    required this.onComplete,
  });

  final String text;
  final VoidCallback onComplete;

  @override
  State<FloatingTextPopup> createState() => _FloatingTextPopupState();
}

class _FloatingTextPopupState extends State<FloatingTextPopup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
  )..forward();

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete();
      }
    });
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
          final t = _controller.value;
          final rise = -30 * t;
          final fade = 1.0 - Curves.easeIn.transform(t);
          final burstScale = 0.6 + t * 1.6;
          return Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Opacity(
                opacity: (1 - t).clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: burstScale,
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Palette.gold.withValues(alpha: 0.55),
                          Palette.gold.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Transform.translate(
                offset: Offset(0, rise),
                child: Opacity(
                  opacity: fade.clamp(0.0, 1.0),
                  child: Text(
                    widget.text,
                    style: Palette.display.copyWith(
                      fontSize: 20,
                      color: Palette.gold,
                      shadows: Palette.glowShadow(Palette.gold, blur: 8),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
