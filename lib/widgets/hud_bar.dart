import 'package:flutter/material.dart';

import '../app_assets.dart';
import '../theme/palette.dart';

class HudBar extends StatelessWidget {
  const HudBar({
    super.key,
    required this.streetHealth,
    required this.score,
    required this.feverMeter,
    required this.feverActive,
    required this.onMenuPressed,
  });

  final double streetHealth;
  final int score;
  final double feverMeter;
  final bool feverActive;
  final VoidCallback onMenuPressed;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
        child: Column(
          children: [
            Row(
              children: [
                _RoundIconButton(icon: Icons.menu, onTap: onMenuPressed),
                const SizedBox(width: 10),
                Expanded(
                  child: _MeterBar(
                    value: (streetHealth / 100).clamp(0.0, 1.0),
                    icon: Icons.shield_moon,
                    label: 'STREET',
                    colors: streetHealth > 40
                        ? const [Palette.emerald, Palette.sky]
                        : const [Palette.danger, Palette.amber],
                  ),
                ),
                const SizedBox(width: 10),
                _ScoreChip(score: score),
              ],
            ),
            const SizedBox(height: 8),
            _MeterBar(
              value: (feverMeter / 100).clamp(0.0, 1.0),
              iconAsset: AppAssets.carnivalFever,
              label: feverActive ? 'CARNIVAL FEVER!' : 'FEVER',
              colors: const [Palette.hotPink, Palette.gold],
              highlighted: feverActive,
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Palette.nightPurple.withValues(alpha: 0.65),
          shape: BoxShape.circle,
          border: Border.all(color: Palette.gold.withValues(alpha: 0.6)),
        ),
        child: Icon(icon, color: Palette.cream, size: 20),
      ),
    );
  }
}

class _ScoreChip extends StatelessWidget {
  const _ScoreChip({required this.score});
  final int score;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Palette.nightPurple.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Palette.gold.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(AppAssets.festivalStar, width: 20, height: 20),
          const SizedBox(width: 6),
          Text(
            '$score',
            style: Palette.display.copyWith(fontSize: 16, color: Palette.gold),
          ),
        ],
      ),
    );
  }
}

class _MeterBar extends StatelessWidget {
  const _MeterBar({
    required this.value,
    required this.label,
    required this.colors,
    this.icon,
    this.iconAsset,
    this.highlighted = false,
  });

  final double value;
  final String label;
  final List<Color> colors;
  final IconData? icon;
  final String? iconAsset;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Palette.nightPurple.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: (highlighted ? Palette.hotPink : Palette.gold).withValues(
            alpha: 0.55,
          ),
        ),
      ),
      child: Row(
        children: [
          if (iconAsset != null)
            Image.asset(iconAsset!, width: 18, height: 18)
          else if (icon != null)
            Icon(icon, size: 16, color: Palette.cream),
          const SizedBox(width: 6),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  Container(
                    height: 12,
                    color: Colors.black.withValues(alpha: 0.35),
                  ),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: value),
                    duration: const Duration(milliseconds: 220),
                    builder: (context, v, _) => FractionallySizedBox(
                      widthFactor: v,
                      child: Container(
                        height: 12,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: colors),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: Palette.body.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: highlighted ? Palette.hotPink : Palette.cream,
            ),
          ),
        ],
      ),
    );
  }
}
