import 'package:flutter/material.dart';

import '../app_assets.dart';
import '../setup/app_mask.dart';
import '../theme/palette.dart';
import '../wire/insight.dart';
import '../wire/mask_store.dart';
import '../wire/push_relay.dart';
import '../wire/signal_gauge.dart';
import 'neon_pill.dart';
import 'web_scene.dart';

/// Push opt-in promo shown once before the WebView. Uses the project's
/// notification artwork (orientation-aware). Accept triggers the OS
/// dialog; Skip arms a 3-day cooldown. Either way the user continues
/// to the content.
///
/// Both button labels are real gradient pills — per
/// .cursor/rules/gray_part_pitfalls.md §12 the Skip button must NOT be
/// a subdued text link (WCAG contrast failure on dark art). Instead we
/// use a darker gradient family for visual hierarchy.
///
/// Horizontal layout intentionally skips SafeArea horizontal padding
/// so the buttons remain centred on the joker's cobblestone floor
/// regardless of side notches / camera cutouts.
class NoticeInviteScene extends StatefulWidget {
  const NoticeInviteScene({
    super.key,
    required this.store,
    required this.pushRelay,
    required this.signalGauge,
    required this.contentLink,
  });

  final MaskStore store;
  final PushRelay pushRelay;
  final SignalGauge signalGauge;
  final String contentLink;

  @override
  State<NoticeInviteScene> createState() => _NoticeInviteSceneState();
}

class _NoticeInviteSceneState extends State<NoticeInviteScene> {
  @override
  void initState() {
    super.initState();
    Insight.screen('push_invite');
  }

  Future<void> _accept() async {
    Insight.event('push_invite_accept');
    // Use the REAL result of the OS dialog. Do not read the store back —
    // the store may lag by a frame and the tag would be wrong.
    final bool granted = await widget.pushRelay.askPermission();
    Insight.tag('notif_permission', granted ? 'granted' : 'denied');
    Insight.event(granted ? 'push_granted' : 'push_denied');
    if (!granted) {
      await widget.store.writeInviteRearm(_rearmTarget());
    }
    if (mounted) _forward();
  }

  Future<void> _skip() async {
    Insight.event('push_invite_skip');
    Insight.tag('notif_permission', 'skipped');
    await widget.store.writeInviteRearm(_rearmTarget());
    if (mounted) _forward();
  }

  int _rearmTarget() =>
      DateTime.now().millisecondsSinceEpoch ~/ 1000 +
      AppMask.inviteRearmSeconds;

  void _forward() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => WebScene(
          link: widget.contentLink,
          store: widget.store,
          pushRelay: widget.pushRelay,
          signalGauge: widget.signalGauge,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final bool landscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final String bg = landscape
        ? AppAssets.horizontalNotifications
        : AppAssets.verticalNotifications;

    final Widget acceptButton = NeonPillButton(
      label: 'Accept',
      compact: landscape,
      width: landscape ? size.width * 0.34 : size.width * 0.72,
      onTap: _accept,
    );

    final Widget skipButton = NeonPillButton(
      label: 'Skip',
      compact: landscape,
      secondary: true,
      width: landscape ? size.width * 0.24 : size.width * 0.48,
      onTap: _skip,
    );

    final Widget actions = landscape
        ? Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              acceptButton,
              const SizedBox(width: 14),
              skipButton,
            ],
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              acceptButton,
              const SizedBox(height: 14),
              skipButton,
            ],
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
          // No SafeArea horizontally in either orientation — buttons
          // should stay centred against the artwork frame. Vertical
          // offset is tuned per orientation so the pill sits above the
          // cobblestone gutter.
          Positioned(
            left: 0,
            right: 0,
            bottom: size.height * (landscape ? 0.06 : 0.06),
            child: Center(child: actions),
          ),
        ],
      ),
    );
  }
}
