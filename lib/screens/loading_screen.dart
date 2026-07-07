import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_assets.dart';
import '../game/game_controller.dart';
import '../theme/palette.dart';
import '../widgets/animated_loading_dots.dart';
import 'menu_screen.dart';

/// The very first screen the player sees. It is the only screen in the
/// app allowed to render in both portrait AND landscape (it picks the
/// matching artwork automatically). Its progress bar is driven by real
/// work being completed - it is mathematically impossible for it to
/// reach 100% before the app has actually finished getting ready.
class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  double _progress = 0.0;
  bool _startedLoading = false;

  @override
  void initState() {
    super.initState();
    // Allow the loading screen to be shown in whichever orientation the
    // device is currently in.
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_startedLoading) {
      _startedLoading = true;
      _runLoadingSequence();
    }
  }

  Future<void> _runLoadingSequence() async {
    final steps = <Future<void> Function()>[
      ...AppAssets.precacheTargets.map(
        (path) => () => precacheImage(AssetImage(path), context),
      ),
      () => GameController.loadBestScore(),
      () => Future<void>.delayed(const Duration(milliseconds: 120)),
    ];

    final total = steps.length;
    var completed = 0;

    for (final step in steps) {
      await step();
      completed++;
      if (!mounted) return;
      setState(() => _progress = completed / total);
    }

    // Tiny grace pause so the bar visibly reaches its very end before we
    // transition, rather than cutting away the instant it hits 100%.
    await Future<void>.delayed(const Duration(milliseconds: 260));
    if (!mounted) return;

    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    if (!mounted) return;

    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const MenuScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.nightPurple,
      body: OrientationBuilder(
        builder: (context, orientation) {
          final isPortrait = orientation == Orientation.portrait;
          final asset = isPortrait
              ? AppAssets.verticalLoading
              : AppAssets.horizontalLoading;
          return Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(asset, fit: BoxFit.cover),
              Align(
                alignment: const Alignment(0, 0.86),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isPortrait ? 44 : 120,
                  ),
                  child: _LoadingBar(progress: _progress),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LoadingBar extends StatelessWidget {
  const _LoadingBar({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 22,
            decoration: BoxDecoration(
              color: Palette.nightPurple.withValues(alpha: 0.55),
              border: Border.all(
                color: Palette.gold.withValues(alpha: 0.7),
                width: 1.6,
              ),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: progress.clamp(0.0, 1.0)),
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOut,
                builder: (context, value, _) {
                  return FractionallySizedBox(
                    widthFactor: value,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Palette.amber, Palette.gold],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Palette.gold,
                            blurRadius: 12,
                            spreadRadius: -2,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        AnimatedLoadingDots(
          style: Palette.display.copyWith(
            fontSize: 20,
            shadows: Palette.glowShadow(Palette.gold, blur: 10),
          ),
        ),
      ],
    );
  }
}
