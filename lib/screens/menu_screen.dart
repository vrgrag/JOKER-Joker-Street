import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app_assets.dart';
import '../app_urls.dart';
import '../game/game_controller.dart';
import '../theme/palette.dart';
import '../widgets/bobbing.dart';
import 'game_screen.dart';
import 'webview_screen.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final bestScore = context.watch<GameController>().bestScore;

    return Scaffold(
      backgroundColor: Palette.nightPurple,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(AppAssets.background, fit: BoxFit.cover),
          const DecoratedBox(
            decoration: BoxDecoration(gradient: Palette.backdropFade),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Bobbing(
                    amplitude: 5,
                    child: Image.asset(
                      AppAssets.gameLogo,
                      width: 240,
                      fit: BoxFit.contain,
                    ),
                  ),
                  if (bestScore > 0) ...[
                    const SizedBox(height: 4),
                    _BestScoreChip(bestScore: bestScore),
                  ],
                  const Spacer(),
                  Image.asset(
                    AppAssets.hero,
                    height: 260,
                    fit: BoxFit.contain,
                  ),
                  const Spacer(),
                  _PlayButton(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const GameScreen()),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _LinkButton(
                        label: 'Privacy Policy',
                        icon: Icons.privacy_tip_outlined,
                        onTap: () => _openWeb(
                          context,
                          'Privacy Policy',
                          AppUrls.privacyPolicy,
                        ),
                      ),
                      const SizedBox(width: 18),
                      _LinkButton(
                        label: 'Support',
                        icon: Icons.support_agent_outlined,
                        onTap: () => _openWeb(
                          context,
                          'Support',
                          AppUrls.support,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openWeb(BuildContext context, String title, String url) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => WebViewScreen(title: title, url: url)),
    );
  }
}

class _BestScoreChip extends StatelessWidget {
  const _BestScoreChip({required this.bestScore});
  final int bestScore;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Palette.nightPurple.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Palette.gold.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(AppAssets.festivalStar, width: 18, height: 18),
          const SizedBox(width: 6),
          Text(
            'Best: $bestScore',
            style: Palette.body.copyWith(color: Palette.gold, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(32),
        onTap: onTap,
        child: Container(
          width: 220,
          padding: const EdgeInsets.symmetric(vertical: 18),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            gradient: const LinearGradient(
              colors: [Palette.amber, Palette.gold],
            ),
            boxShadow: [
              BoxShadow(
                color: Palette.gold.withValues(alpha: 0.55),
                blurRadius: 24,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Text(
            'PLAY',
            style: Palette.display.copyWith(
              fontSize: 24,
              color: Palette.nightPurple,
              letterSpacing: 2,
            ),
          ),
        ),
      ),
    );
  }
}

class _LinkButton extends StatelessWidget {
  const _LinkButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Palette.nightPurple.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Palette.cream, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: Palette.body.copyWith(color: Palette.cream, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
