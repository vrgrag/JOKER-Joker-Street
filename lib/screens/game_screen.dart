import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app_assets.dart';
import '../game/game_controller.dart';
import '../game/models.dart';
import '../theme/palette.dart';
import '../widgets/bobbing.dart';
import '../widgets/confetti_overlay.dart';
import '../widgets/enemy_sprite.dart';
import '../widgets/floating_text_popup.dart';
import '../widgets/game_over_overlay.dart';
import '../widgets/hud_bar.dart';
import '../widgets/tile_widget.dart';
import '../wire/insight.dart';

const List<double> _rowY = [0.10, 0.42, 0.74];
const List<double> _laneX = [0.27, 0.73];

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration? _lastElapsed;
  late final GameController _game;
  bool _gameOverTracked = false;

  @override
  void initState() {
    super.initState();
    Insight.screen('game');
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    _game = context.read<GameController>();
    _game.addListener(_onGameStateChange);
    _game.start();
    _ticker = createTicker(_onTick)..start();
  }

  void _onGameStateChange() {
    if (!_gameOverTracked && _game.status == GameStatus.gameOver) {
      _gameOverTracked = true;
      Insight.event('game_over');
      Insight.tag('final_score', '${_game.score}');
    }
  }

  void _onTick(Duration elapsed) {
    final last = _lastElapsed ?? elapsed;
    _lastElapsed = elapsed;
    var dt = (elapsed - last).inMicroseconds / 1000000.0;
    if (dt < 0 || dt > 0.05) dt = 0.016;
    _game.update(dt);
  }

  @override
  void dispose() {
    _game.removeListener(_onGameStateChange);
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameController>();

    return Scaffold(
      backgroundColor: Palette.nightPurple,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(AppAssets.background, fit: BoxFit.cover),
          const DecoratedBox(
            decoration: BoxDecoration(gradient: Palette.backdropFade),
          ),
          Column(
            children: [
              HudBar(
                streetHealth: game.streetHealth,
                score: game.score,
                feverMeter: game.feverMeter,
                feverActive: game.feverActive,
                onMenuPressed: () => _confirmExit(context),
              ),
              Expanded(child: _Board(game: game)),
            ],
          ),
          if (game.feverActive) const ConfettiOverlay(),
          if (game.feverActive) const _FeverBanner(),
          if (game.status == GameStatus.gameOver)
            GameOverOverlay(
              score: game.score,
              bestScore: game.bestScore,
              onRestart: () => _game.start(),
              onMenu: () => Navigator.of(context).pop(),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmExit(BuildContext context) async {
    if (_game.status == GameStatus.gameOver) {
      Navigator.of(context).pop();
      return;
    }
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Palette.deepPurple,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Palette.gold),
        ),
        title: Text('Leave the street?', style: Palette.display.copyWith(fontSize: 18, color: Palette.gold)),
        content: Text(
          'Your current run will be lost.',
          style: Palette.body.copyWith(color: Palette.cream),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Stay', style: Palette.body.copyWith(color: Palette.cream)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Leave', style: Palette.body.copyWith(color: Palette.gold)),
          ),
        ],
      ),
    );
    if (shouldExit == true && context.mounted) {
      Navigator.of(context).pop();
    }
  }
}

class _FeverBanner extends StatelessWidget {
  const _FeverBanner();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: const Alignment(0, -0.55),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.7, end: 1.0),
          duration: const Duration(milliseconds: 400),
          curve: Curves.elasticOut,
          builder: (context, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(AppAssets.carnivalFever, width: 92, height: 92),
              Text(
                'CARNIVAL FEVER!',
                style: Palette.display.copyWith(
                  fontSize: 24,
                  color: Palette.gold,
                  shadows: Palette.glowShadow(Palette.hotPink, blur: 14),
                ),
              ),
              Text(
                'Tap any tile to clear the street!',
                style: Palette.body.copyWith(
                  color: Palette.cream,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Board extends StatelessWidget {
  const _Board({required this.game});

  final GameController game;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final tileSize = (w * 0.36).clamp(64.0, 118.0);
        final enemySize = tileSize * 0.62;

        Offset posFor(int lane, double rowFraction) {
          return Offset(_laneX[lane] * w, rowFraction * h);
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Tiles
            for (var index = 0; index < kTileCount; index++)
              () {
                final lane = index % 2;
                final row = index ~/ 2;
                final pos = posFor(lane, _rowY[row]);
                return Positioned(
                  left: pos.dx - tileSize / 2,
                  top: pos.dy - tileSize / 2,
                  width: tileSize,
                  height: tileSize,
                  child: TileWidget(
                    glow: game.tiles[index].glow,
                    accentColor: _accentFor(index),
                    onTap: () => game.onTileTap(index),
                  ),
                );
              }(),
            // Enemies
            for (final enemy in game.enemies)
              () {
                final y = _rowY.first + (_rowY.last - _rowY.first) * enemy.progress;
                final pos = posFor(enemy.lane, y.clamp(0.0, 1.0));
                return Positioned(
                  left: pos.dx - enemySize / 2,
                  top: pos.dy - enemySize / 2,
                  width: enemySize,
                  height: enemySize,
                  child: EnemySprite(enemy: enemy, size: enemySize),
                );
              }(),
            // Floating texts / success bursts
            for (final text in game.floatingTexts)
              () {
                final pos = posFor(text.lane, _rowY[text.row]);
                return Positioned(
                  left: pos.dx - 45,
                  top: pos.dy - 45,
                  width: 90,
                  height: 90,
                  child: FloatingTextPopup(
                    key: ValueKey(text.id),
                    text: text.text,
                    onComplete: () => game.removeFloatingText(text.id),
                  ),
                );
              }(),
            // Hero, standing guard at the bottom of the street.
            Positioned(
              left: w * 0.5 - tileSize * 0.85,
              bottom: 0,
              width: tileSize * 1.7,
              child: Bobbing(
                amplitude: 5,
                child: Image.asset(AppAssets.hero, fit: BoxFit.contain),
              ),
            ),
          ],
        );
      },
    );
  }

  Color _accentFor(int index) {
    const colors = [
      Palette.sky,
      Palette.hotPink,
      Palette.emerald,
      Palette.amber,
      Palette.velvet,
      Palette.sky,
    ];
    return colors[index % colors.length];
  }
}
