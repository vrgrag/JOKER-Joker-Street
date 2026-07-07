import 'package:flutter/material.dart';

/// The two enemy archetypes described in the design: the Gremlin is
/// quick but fragile, the Mime is slow but soaks up more hits.
enum EnemyType { streetGremlin, shadowMime }

extension EnemyTypeStats on EnemyType {
  int get maxHp => switch (this) {
    EnemyType.streetGremlin => 1,
    EnemyType.shadowMime => 2,
  };

  /// Progress units (0..1 = spawn to breach) advanced per second.
  double get baseSpeed => switch (this) {
    EnemyType.streetGremlin => 0.30,
    EnemyType.shadowMime => 0.15,
  };

  double get breachDamage => switch (this) {
    EnemyType.streetGremlin => 8,
    EnemyType.shadowMime => 15,
  };

  int get starReward => switch (this) {
    EnemyType.streetGremlin => 5,
    EnemyType.shadowMime => 12,
  };
}

/// A single enemy marching down one of the two lanes toward the hero.
class Enemy {
  Enemy({required this.id, required this.type, required this.lane})
    : hp = type.maxHp;

  final int id;
  final EnemyType type;
  final int lane; // 0 = left, 1 = right
  double progress = 0.0; // 0 = just spawned, 1 = reached the hero
  int hp;
  bool flinch = false;
}

/// What a magic tile is currently displaying.
enum TileGlowKind { none, magic, fake }

class TileState {
  TileState({this.glow = TileGlowKind.none});

  TileGlowKind glow;
}

/// Lightweight ephemeral popup (e.g. "+15") rendered on top of the board.
class FloatingText {
  FloatingText({
    required this.id,
    required this.text,
    required this.lane,
    required this.row,
    this.color = Colors.white,
  });

  final int id;
  final String text;
  final int lane;
  final int row;
  final Color color;
}

enum GameStatus { playing, feverIntro, gameOver }
