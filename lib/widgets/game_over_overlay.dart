import 'package:flutter/material.dart';

import '../app_assets.dart';
import '../theme/palette.dart';

class GameOverOverlay extends StatelessWidget {
  const GameOverOverlay({
    super.key,
    required this.score,
    required this.bestScore,
    required this.onRestart,
    required this.onMenu,
  });

  final int score;
  final int bestScore;
  final VoidCallback onRestart;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final isNewBest = score >= bestScore && score > 0;
    return Positioned.fill(
      child: Container(
        color: Palette.nightPurple.withValues(alpha: 0.86),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Palette.velvet, Palette.deepPurple],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Palette.gold, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Palette.gold.withValues(alpha: 0.35),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Street Overrun!',
                  textAlign: TextAlign.center,
                  style: Palette.display.copyWith(
                    fontSize: 26,
                    color: Palette.gold,
                    shadows: Palette.glowShadow(Palette.gold),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'The carnival spirits scattered the crowd...',
                  textAlign: TextAlign.center,
                  style: Palette.body.copyWith(
                    fontSize: 13,
                    color: Palette.cream.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: 20),
                Image.asset(AppAssets.festivalStar, width: 56, height: 56),
                const SizedBox(height: 8),
                Text(
                  '$score',
                  style: Palette.display.copyWith(
                    fontSize: 34,
                    color: Palette.cream,
                  ),
                ),
                if (isNewBest)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'NEW BEST!',
                      style: Palette.body.copyWith(
                        color: Palette.emerald,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Best: $bestScore',
                      style: Palette.body.copyWith(
                        color: Palette.cream.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _GameOverButton(
                        label: 'Menu',
                        filled: false,
                        onTap: onMenu,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _GameOverButton(
                        label: 'Play Again',
                        filled: true,
                        onTap: onRestart,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GameOverButton extends StatelessWidget {
  const _GameOverButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? Palette.gold : Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: filled ? null : Border.all(color: Palette.gold, width: 1.6),
          ),
          child: Text(
            label,
            style: Palette.display.copyWith(
              fontSize: 15,
              color: filled ? Palette.nightPurple : Palette.gold,
            ),
          ),
        ),
      ),
    );
  }
}
