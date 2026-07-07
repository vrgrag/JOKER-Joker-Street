import 'package:flutter/material.dart';

/// Wraps [child] with a gentle, endless up/down bobbing motion - used to
/// keep the hero and decorative art feeling alive on otherwise static
/// screens.
class Bobbing extends StatefulWidget {
  const Bobbing({
    super.key,
    required this.child,
    this.amplitude = 6,
    this.duration = const Duration(milliseconds: 1800),
  });

  final Widget child;
  final double amplitude;
  final Duration duration;

  @override
  State<Bobbing> createState() => _BobbingState();
}

class _BobbingState extends State<Bobbing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final offset =
            Curves.easeInOut.transform(_controller.value) * widget.amplitude;
        return Transform.translate(offset: Offset(0, -offset), child: child);
      },
      child: widget.child,
    );
  }
}
