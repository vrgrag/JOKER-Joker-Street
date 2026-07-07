import 'package:flutter/material.dart';

import '../app_assets.dart';
import '../game/models.dart';
import '../theme/palette.dart';

/// Renders a single marching enemy, sliding smoothly along its lane
/// based on [Enemy.progress] (driven every frame by [GameController]).
class EnemySprite extends StatelessWidget {
  const EnemySprite({super.key, required this.enemy, required this.size});

  final Enemy enemy;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isMime = enemy.type == EnemyType.shadowMime;
    final asset = isMime ? AppAssets.shadowMime : AppAssets.streetGremlin;
    final glow = isMime ? Palette.velvet : Palette.emerald;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: glow.withValues(alpha: 0.55), blurRadius: 16),
        ],
      ),
      child: Image.asset(asset, fit: BoxFit.contain),
    );
  }
}
