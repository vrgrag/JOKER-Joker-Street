import 'package:clarity_flutter/clarity_flutter.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'carnival/route_boss.dart';
import 'game/game_controller.dart';
import 'theme/palette.dart';
import 'wire/adspot_pipe.dart';
import 'wire/handshake_gate.dart';
import 'wire/insight.dart';
import 'wire/mask_store.dart';
import 'wire/masked_agent.dart';
import 'wire/push_relay.dart';
import 'wire/signal_gauge.dart';

// ---------------------------------------------------------------
// main — Joker Street bootstrap
// ---------------------------------------------------------------
// The startup order below is intentional; do NOT reshuffle without
// re-reading .cursor/rules/android_gray_guide.md §"Setup Checklist".
//
//   1. WidgetsFlutterBinding      — required before any plugin call.
//   2. Firebase + AppCheck        — wrapped in try/catch because the
//      manager delivers google-services.json late in the pipeline.
//      A failure here MUST NOT block startup: the gray flow simply
//      falls through to the native carnival game.
//   3. Orientation whitelist       — loading + WebView scenes rotate
//      freely; the native game re-locks to portrait inside RouteBoss.
//   4. Status bar transparent      — the artwork goes edge-to-edge.
//   5. maskedAgent.prime()         — assembles the forged Chrome-149
//      user-agent BEFORE any bridge tries to POST anywhere.
//   6. MaskStore.warmUp()          — reads SharedPreferences into
//      memory so RouteBoss can decide its first frame synchronously
//      (no async wait = no blank frame).
//   7. Bridges are constructed here but NOT booted; PushRelay and
//      AdSpotPipe run their `boot`/`spinUp` inside RouteBoss.
//
// The GameController provider is kept intact so the existing native
// game (game_screen, menu_screen, hud_bar, …) still works exactly as
// before. It just now lives behind the RouteBoss decision.
// ---------------------------------------------------------------

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase + App Check are optional until google-services.json lands;
  // the try/catch is deliberate — the client asked that the native
  // (white) part launches even without any internet or credentials.
  try {
    await Firebase.initializeApp();
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
    );
  } catch (_) {
    // No Firebase config yet — carry on. RouteBoss will pick this up
    // when PushRelay.boot() short-circuits.
  }

  await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Palette.nightPurple,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Forge the UA BEFORE any bridge is created — HandshakeGate uses
  // the primed value on its first POST.
  await maskedAgent.prime();

  final MaskStore store = MaskStore();
  await store.warmUp();

  final SignalGauge signalGauge = SignalGauge();
  final AdSpotPipe adSpotPipe = AdSpotPipe();
  final HandshakeGate handshakeGate = HandshakeGate(store);
  final PushRelay pushRelay = PushRelay(store);

  // ClarityWidget must wrap the app root so replay + custom events
  // work across every route. See .cursor/rules/clarity_analytics.mdc §1.
  runApp(ClarityWidget(
    clarityConfig: Insight.config,
    app: JokerStreetApp(
      store: store,
      signalGauge: signalGauge,
      adSpotPipe: adSpotPipe,
      handshakeGate: handshakeGate,
      pushRelay: pushRelay,
    ),
  ));
}

class JokerStreetApp extends StatelessWidget {
  const JokerStreetApp({
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
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<GameController>(
      create: (_) => GameController(),
      child: MaterialApp(
        title: 'Joker Street',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: Palette.nightPurple,
          fontFamily: 'Baloo2',
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Palette.gold,
            brightness: Brightness.dark,
          ),
        ),
        home: RouteBoss(
          store: store,
          signalGauge: signalGauge,
          adSpotPipe: adSpotPipe,
          handshakeGate: handshakeGate,
          pushRelay: pushRelay,
        ),
      ),
    );
  }
}
