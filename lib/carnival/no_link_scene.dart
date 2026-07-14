import 'package:flutter/material.dart';

import '../app_assets.dart';
import '../theme/palette.dart';
import '../wire/insight.dart';
import 'neon_pill.dart';

/// Shown when the device has no live connection. Uses the project's
/// dedicated no-wifi artwork (orientation-aware) with a Retry pill
/// overlaid at the bottom. Retry rebuilds whatever screen the caller
/// supplies.
///
/// The horizontal artwork intentionally does NOT use SafeArea: with
/// side notches / camera cutouts the SafeArea padding would knock the
/// button off the artwork's horizontal centreline (per client note).
/// The button is placed against the raw screen dimensions and stays
/// centred on the joker's cobblestone floor.
class NoLinkScene extends StatefulWidget {
  const NoLinkScene({super.key, required this.onRetryBuild});

  final WidgetBuilder onRetryBuild;

  @override
  State<NoLinkScene> createState() => _NoLinkSceneState();
}

class _NoLinkSceneState extends State<NoLinkScene> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    Insight.screen('offline');
  }

  Future<void> _retry() async {
    if (_busy) return;
    Insight.event('offline_retry');
    setState(() => _busy = true);
    // Tiny grace so the pill's press animation gets to play.
    await Future<void>.delayed(const Duration(milliseconds: 320));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: widget.onRetryBuild),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final bool landscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final String bg =
        landscape ? AppAssets.horizontalNoWifi : AppAssets.verticalNoWifi;

    final Widget action = _busy
        ? SizedBox(
            width: 42,
            height: 42,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(
                Palette.gold.withValues(alpha: 0.95),
              ),
            ),
          )
        : NeonPillButton(
            label: 'Try Again',
            width: landscape ? size.width * 0.34 : size.width * 0.62,
            compact: landscape,
            onTap: _retry,
          );

    return Scaffold(
      backgroundColor: Palette.nightPurple,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset(
            bg,
            fit: BoxFit.cover,
            width: size.width,
            height: size.height,
          ),
          // Landscape: no SafeArea, centre on raw dimensions so notches
          // do not offset the button. Portrait: keep the ~9% offset that
          // sits above the cobblestone gutter.
          if (landscape)
            Positioned(
              left: 0,
              right: 0,
              bottom: size.height * 0.06,
              child: Center(child: action),
            )
          else
            Positioned(
              left: 0,
              right: 0,
              bottom: size.height * 0.08,
              child: Center(child: action),
            ),
        ],
      ),
    );
  }
}
