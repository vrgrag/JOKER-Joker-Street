import 'dart:async';

import 'package:flutter/material.dart';

/// Renders "Loading" followed by a cycling number of dots (. .. ...),
/// purely cosmetic and independent from the real loading progress.
class AnimatedLoadingDots extends StatefulWidget {
  const AnimatedLoadingDots({super.key, this.style, this.label = 'Loading'});

  final TextStyle? style;
  final String label;

  @override
  State<AnimatedLoadingDots> createState() => _AnimatedLoadingDotsState();
}

class _AnimatedLoadingDotsState extends State<AnimatedLoadingDots> {
  int _dots = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 420), (_) {
      if (!mounted) return;
      setState(() => _dots = (_dots + 1) % 4);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dotsText = '.' * _dots;
    final padding = '.' * (3 - _dots);
    return Text.rich(
      TextSpan(
        style: widget.style,
        children: [
          TextSpan(text: widget.label),
          TextSpan(text: dotsText),
          TextSpan(
            text: padding,
            style: const TextStyle(color: Colors.transparent),
          ),
        ],
      ),
    );
  }
}
