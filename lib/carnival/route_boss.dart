import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app_assets.dart';
import '../game/game_controller.dart';
import '../kind/app_flavor.dart';
import '../kind/gate_verdict.dart';
import '../screens/menu_screen.dart';
import '../theme/palette.dart';
import '../widgets/animated_loading_dots.dart';
import '../wire/adspot_pipe.dart';
import '../wire/handshake_gate.dart';
import '../wire/insight.dart';
import '../wire/mask_store.dart';
import '../wire/push_relay.dart';
import '../wire/signal_gauge.dart';
import 'no_link_scene.dart';
import 'notice_invite.dart';
import 'web_scene.dart';

// ---------------------------------------------------------------
// RouteBoss — loading artwork + gray/native decision engine
// ---------------------------------------------------------------
// The single startup screen. Renders the project's loading artwork
// with a progress bar + animated "Loading…" caption while it walks
// through the state machine documented in
// .cursor/rules/android_gray_guide.md §"Gray Flow State Machine".
//
// [FIRST-LAUNCH UX INVARIANT — do not weaken]
// If the device is offline on the FIRST launch (OneLink install with
// data OFF), _firstLaunch() short-circuits into _toOffline() BEFORE
// AppSpotPipe.spinUp() is awaited. The user sees the No-Wi-Fi scene
// on frame 1; Retry rebuilds RouteBoss from scratch, which re-runs
// the full pipeline. AppFlavor stays `unset` until a SUCCESSFUL POST
// commits it — a plain network failure on first boot must NEVER
// promote to `nativeShow`.
// ---------------------------------------------------------------

class RouteBoss extends StatefulWidget {
  const RouteBoss({
    super.key,
    required this.store,
    required this.signalGauge,
    required this.adSpotPipe,
    required this.handshakeGate,
    required this.pushRelay,
  });

  final MaskStore store;
  final SignalGauge signalGauge;
  final AdSpotPipe adSpotPipe;
  final HandshakeGate handshakeGate;
  final PushRelay pushRelay;

  @override
  State<RouteBoss> createState() => _RouteBossState();
}

class _RouteBossState extends State<RouteBoss>
    with SingleTickerProviderStateMixin {
  double _progress = 0.05;
  bool _routed = false;
  late final AnimationController _caption;

  @override
  void initState() {
    super.initState();
    _caption = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    widget.pushRelay.onTokenRotated = _repostToken;
    Insight.screen('loading');

    SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _pump();
  }

  @override
  void dispose() {
    widget.pushRelay.onTokenRotated = null;
    _caption.dispose();
    super.dispose();
  }

  void _lift(double value) {
    if (mounted) setState(() => _progress = value);
  }

  Future<void> _pump() async {
    await widget.pushRelay.boot();
    _lift(0.2);

    switch (widget.store.readFlavor()) {
      case AppFlavor.nativeShow:
        await _goNative(initialLift: 0.4);
        break;
      case AppFlavor.webShell:
        await _resumePortal();
        break;
      case AppFlavor.unset:
        await _firstLaunch();
        break;
    }
  }

  Future<void> _firstLaunch() async {
    if (!await widget.signalGauge.isOnline()) {
      _toOffline();
      return;
    }
    _lift(0.4);

    await widget.adSpotPipe.spinUp();
    await Future.wait<void>(<Future<void>>[
      widget.adSpotPipe.awaitInstallData(),
      widget.adSpotPipe.awaitDeepLink(),
    ]);
    _lift(0.7);

    final GateVerdict verdict = await _knock();
    if (verdict.granted && verdict.hasLink) {
      await widget.store.writeFlavor(AppFlavor.webShell);
      _lift(1.0);
      await _settle();
      _toPortal(verdict.link!);
    } else {
      await widget.store.writeFlavor(AppFlavor.nativeShow);
      await _goNative(initialLift: 0.85);
    }
  }

  Future<void> _resumePortal() async {
    if (!await widget.signalGauge.isOnline()) {
      _lift(1.0);
      _toOffline();
      return;
    }
    _lift(0.4);

    // A pending cold-tap push link wins over everything else.
    final String? pending = await widget.store.takePendingLink();
    if (pending != null) {
      Insight.event('route_push_link');
      _lift(1.0);
      await _settle();
      _toPortal(pending);
      return;
    }

    final String? cached = await widget.store.readCachedLink();

    await widget.adSpotPipe.spinUp();
    await Future.wait<void>(<Future<void>>[
      widget.adSpotPipe.awaitInstallData(seconds: 10),
      widget.adSpotPipe.awaitDeepLink(),
    ]);
    _lift(0.7);

    final GateVerdict verdict = await _knock();
    _lift(1.0);
    await _settle();

    if (verdict.granted && verdict.hasLink) {
      _toPortal(verdict.link!);
    } else if (cached != null) {
      Insight.event('route_cached_link');
      _toPortal(cached);
    } else {
      _toOffline();
    }
  }

  Future<GateVerdict> _knock() async {
    final String locale = Platform.localeName.replaceAll('-', '_');
    final Map<String, dynamic> body =
        await widget.adSpotPipe.assemblePortalBody(
      locale: locale,
      pushToken: widget.pushRelay.token,
    );
    // Identify the session as soon as af_id is known. Attribution tags are
    // attached so the Clarity dashboard can be sliced per acquired user.
    Insight.identify(
      body['af_id']?.toString(),
      tags: <String, String>{
        'af_status': body['af_status']?.toString() ?? '',
        'media_source': body['media_source']?.toString() ?? '',
        'campaign': body['campaign']?.toString() ?? '',
        'os': body['os']?.toString() ?? '',
        'locale': body['locale']?.toString() ?? '',
      },
    );
    return widget.handshakeGate.knock(body);
  }

  void _repostToken(String token) async {
    final String locale = Platform.localeName.replaceAll('-', '_');
    final Map<String, dynamic> body =
        await widget.adSpotPipe.assemblePortalBody(
      locale: locale,
      pushToken: token,
    );
    widget.handshakeGate.knock(body);
  }

  Future<void> _settle() =>
      Future<void>.delayed(const Duration(milliseconds: 320));

  // ── Routing ──

  Future<void> _goNative({required double initialLift}) async {
    Insight.tag('run_mode', 'native');
    Insight.event('route_native');
    _lift(initialLift);
    await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    if (!mounted) return;
    await _warmGameArt();
    if (!mounted) return;
    // Load best score into the GameController so MenuScreen's watch()
    // sees the persisted value on first paint (no jump from 0 → n).
    // Reads the provider synchronously before the next await — safe
    // even after an async gap since the controller lives in a Provider
    // above us and outlives this route.
    final GameController controller = context.read<GameController>();
    await controller.refreshBestScore();
    _lift(1.0);
    await _settle();
    if (_routed || !mounted) return;
    _routed = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const MenuScreen()),
    );
  }

  Future<void> _warmGameArt() async {
    for (final String path in AppAssets.precacheTargets) {
      if (!mounted) return;
      try {
        await precacheImage(AssetImage(path), context);
      } catch (_) {}
    }
  }

  void _toPortal(String link) {
    if (_routed || !mounted) return;
    _routed = true;
    Insight.tag('run_mode', 'web');
    Insight.event('route_web');
    if (widget.store.shouldOfferInvite()) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => NoticeInviteScene(
            store: widget.store,
            pushRelay: widget.pushRelay,
            signalGauge: widget.signalGauge,
            contentLink: link,
          ),
        ),
      );
    } else {
      // Returning users skip the invite screen — classify their notif state
      // so the `notif_permission` tag is never blank in the dashboard.
      Insight.tag(
        'notif_permission',
        widget.store.isPushGranted()
            ? 'granted'
            : widget.store.isPushBlockedByOs()
                ? 'os_denied'
                : 'snoozed',
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => WebScene(
            link: link,
            store: widget.store,
            pushRelay: widget.pushRelay,
            signalGauge: widget.signalGauge,
          ),
        ),
      );
    }
  }

  void _toOffline() {
    if (_routed || !mounted) return;
    _routed = true;
    Insight.event('route_offline');
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => NoLinkScene(
          onRetryBuild: (_) => RouteBoss(
            store: widget.store,
            signalGauge: widget.signalGauge,
            adSpotPipe: widget.adSpotPipe,
            handshakeGate: widget.handshakeGate,
            pushRelay: widget.pushRelay,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.nightPurple,
      body: OrientationBuilder(
        builder: (BuildContext context, Orientation orientation) {
          final bool portrait = orientation == Orientation.portrait;
          final String bg = portrait
              ? AppAssets.verticalLoading
              : AppAssets.horizontalLoading;
          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Image.asset(bg, fit: BoxFit.cover),
              Align(
                alignment: const Alignment(0, 0.86),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: portrait ? 44 : 120,
                  ),
                  child: _ProgressPanel(
                    progress: _progress,
                    caption: _caption,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProgressPanel extends StatelessWidget {
  const _ProgressPanel({required this.progress, required this.caption});

  final double progress;
  final AnimationController caption;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
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
                builder: (BuildContext context, double value, _) {
                  return FractionallySizedBox(
                    widthFactor: value,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: <Color>[Palette.amber, Palette.gold],
                        ),
                        boxShadow: <BoxShadow>[
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
