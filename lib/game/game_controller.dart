import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

const int kLanes = 2;
const int kRows = 3;
const int kTileCount = kLanes * kRows;
const String _kBestScoreKey = 'joker_street_best_score';

/// Drives the entire "Joker Street" mini-game: tile glow scheduling,
/// enemy spawning/marching, scoring, the street health bar and the
/// Carnival Fever power-up. Consumed by [GameScreen] through a per-frame
/// [update] call so all timing is frame-driven rather than relying on
/// independent, drift-prone [Timer]s.
class GameController extends ChangeNotifier {
  GameController() {
    bestScore = _bestScoreCache;
    for (var i = 0; i < kTileCount; i++) {
      tiles.add(TileState());
    }
  }

  static int _bestScoreCache = 0;

  static Future<void> loadBestScore() async {
    final prefs = await SharedPreferences.getInstance();
    _bestScoreCache = prefs.getInt(_kBestScoreKey) ?? 0;
  }

  /// Instance-level refresh — reads the persisted best score into this
  /// controller and notifies listeners. Used by the RouteBoss so the
  /// menu screen paints the correct value on first frame (without this
  /// the controller was constructed before disk I/O completed and would
  /// briefly show 0).
  Future<void> refreshBestScore() async {
    await loadBestScore();
    if (bestScore != _bestScoreCache) {
      bestScore = _bestScoreCache;
      notifyListeners();
    } else {
      bestScore = _bestScoreCache;
    }
  }

  static Future<void> _saveBestScore(int value) async {
    _bestScoreCache = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kBestScoreKey, value);
  }

  final Random _rng = Random();

  GameStatus status = GameStatus.gameOver; // gameOver acts as "not started"
  double streetHealth = 100;
  int score = 0;
  int bestScore = 0;
  double feverMeter = 0;
  double elapsed = 0;

  final List<TileState> tiles = [];
  final List<Enemy> enemies = [];
  final List<FloatingText> floatingTexts = [];

  int? activeGlowIndex;
  bool feverActive = false;
  double feverTimeRemaining = 0;

  double _tileGapTimer = 0.9;
  double _tileGlowTimer = 0;
  double _spawnTimer = 1.4;
  int _nextEnemyId = 0;
  int _nextTextId = 0;

  static const double _kFeverDuration = 6.0;
  static const int _kMaxEnemiesPerLane = 4;

  void start() {
    status = GameStatus.playing;
    streetHealth = 100;
    score = 0;
    feverMeter = 0;
    elapsed = 0;
    enemies.clear();
    floatingTexts.clear();
    for (final tile in tiles) {
      tile.glow = TileGlowKind.none;
    }
    activeGlowIndex = null;
    feverActive = false;
    feverTimeRemaining = 0;
    _tileGapTimer = 0.9;
    _tileGlowTimer = 0;
    _spawnTimer = 1.2;
    notifyListeners();
  }

  // ----- Difficulty curve -----------------------------------------------

  double _lerpClamped(double from, double to, double t0, double t1) {
    if (t1 <= t0) return to;
    final f = ((elapsed - t0) / (t1 - t0)).clamp(0.0, 1.0);
    return from + (to - from) * f;
  }

  double get _glowDuration => _lerpClamped(1.55, 0.55, 0, 110);
  double get _glowGap => _lerpClamped(0.55, 0.16, 0, 90);
  double get _spawnInterval => _lerpClamped(1.9, 0.7, 0, 110);
  double get _fakeChance => _lerpClamped(0.0, 0.28, 12, 75);
  double get _mimeChance => _lerpClamped(0.18, 0.5, 0, 90);
  double get _speedMultiplier => _lerpClamped(1.0, 1.55, 0, 120);

  // ----- Frame update -----------------------------------------------------

  void update(double dt) {
    if (status != GameStatus.playing) return;
    elapsed += dt;
    _updateGlow(dt);
    _updateSpawning(dt);
    _updateEnemies(dt);
    _updateFever(dt);
    notifyListeners();
  }

  void _updateGlow(double dt) {
    if (feverActive) return;
    if (activeGlowIndex == null) {
      _tileGapTimer -= dt;
      if (_tileGapTimer <= 0) {
        final index = _rng.nextInt(kTileCount);
        final isFake = _rng.nextDouble() < _fakeChance;
        tiles[index].glow = isFake ? TileGlowKind.fake : TileGlowKind.magic;
        activeGlowIndex = index;
        _tileGlowTimer = _glowDuration;
      }
    } else {
      _tileGlowTimer -= dt;
      if (_tileGlowTimer <= 0) {
        tiles[activeGlowIndex!].glow = TileGlowKind.none;
        activeGlowIndex = null;
        _tileGapTimer = _glowGap;
      }
    }
  }

  void _updateSpawning(double dt) {
    _spawnTimer -= dt;
    if (_spawnTimer <= 0) {
      _spawnTimer = _spawnInterval;
      final lane = _rng.nextInt(kLanes);
      final laneCount = enemies.where((e) => e.lane == lane).length;
      if (laneCount < _kMaxEnemiesPerLane) {
        final type = _rng.nextDouble() < _mimeChance
            ? EnemyType.shadowMime
            : EnemyType.streetGremlin;
        enemies.add(Enemy(id: _nextEnemyId++, type: type, lane: lane));
      }
    }
  }

  void _updateEnemies(double dt) {
    final breached = <Enemy>[];
    for (final enemy in enemies) {
      final speedScale = feverActive ? 0.35 : 1.0;
      enemy.progress += enemy.type.baseSpeed * _speedMultiplier * speedScale * dt;
      if (enemy.progress >= 1.0) {
        breached.add(enemy);
      }
    }
    if (breached.isEmpty) return;
    for (final enemy in breached) {
      enemies.remove(enemy);
      streetHealth -= enemy.type.breachDamage;
    }
    if (streetHealth <= 0) {
      streetHealth = 0;
      _endGame();
    }
  }

  void _updateFever(double dt) {
    if (!feverActive) return;
    feverTimeRemaining -= dt;
    if (feverTimeRemaining <= 0) {
      feverActive = false;
      feverTimeRemaining = 0;
      for (final tile in tiles) {
        tile.glow = TileGlowKind.none;
      }
      activeGlowIndex = null;
      _tileGapTimer = _glowGap;
    }
  }

  // ----- Player input -------------------------------------------------

  void onTileTap(int index) {
    if (status != GameStatus.playing) return;

    if (feverActive) {
      _resolveFeverTap(index);
      notifyListeners();
      return;
    }

    if (index != activeGlowIndex) return; // wrong or unlit tile: no effect
    final tile = tiles[index];
    activeGlowIndex = null;

    if (tile.glow == TileGlowKind.fake) {
      tile.glow = TileGlowKind.none;
      _tileGapTimer = _glowGap;
      notifyListeners();
      return;
    }

    tile.glow = TileGlowKind.none;
    _tileGapTimer = _glowGap * 0.6;

    final lane = index % 2;
    final row = index ~/ 2;
    var starsGained = 18;
    var killed = 0;
    enemies.removeWhere((enemy) {
      if (enemy.lane == lane) {
        starsGained += enemy.type.starReward;
        killed++;
        return true;
      }
      return false;
    });

    score += starsGained;
    feverMeter = (feverMeter + 13 + killed * 4).clamp(0, 100);
    _addFloatingText('+$starsGained', lane, row);

    if (feverMeter >= 100) {
      _activateFever();
    }
    notifyListeners();
  }

  void _resolveFeverTap(int index) {
    final lane = index % 2;
    final row = index ~/ 2;
    if (enemies.isEmpty) {
      score += 8;
      _addFloatingText('+8', lane, row);
      return;
    }
    var stars = 0;
    for (final enemy in enemies) {
      stars += enemy.type.starReward * 2;
    }
    score += stars;
    enemies.clear();
    _addFloatingText('+$stars', lane, row);
  }

  void _activateFever() {
    feverActive = true;
    feverTimeRemaining = _kFeverDuration;
    feverMeter = 0;
    activeGlowIndex = null;
    for (final tile in tiles) {
      tile.glow = TileGlowKind.magic;
    }
  }

  void _addFloatingText(String text, int lane, int row) {
    floatingTexts.add(
      FloatingText(id: _nextTextId++, text: text, lane: lane, row: row),
    );
    if (floatingTexts.length > 8) {
      floatingTexts.removeAt(0);
    }
  }

  void removeFloatingText(int id) {
    floatingTexts.removeWhere((t) => t.id == id);
  }

  void _endGame() {
    status = GameStatus.gameOver;
    feverActive = false;
    if (score > bestScore) {
      bestScore = score;
      unawaited(_saveBestScore(score));
    }
  }
}
