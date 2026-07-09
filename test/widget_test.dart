// Basic smoke test making sure the app boots into the loading route
// without throwing. The gray-flow bridges are constructed with fresh
// (non-primed) instances — enough to satisfy the constructor.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jokerstreet/main.dart';
import 'package:jokerstreet/wire/adspot_pipe.dart';
import 'package:jokerstreet/wire/handshake_gate.dart';
import 'package:jokerstreet/wire/mask_store.dart';
import 'package:jokerstreet/wire/push_relay.dart';
import 'package:jokerstreet/wire/signal_gauge.dart';

void main() {
  testWidgets('App builds a MaterialApp', (WidgetTester tester) async {
    final MaskStore store = MaskStore();
    final SignalGauge signalGauge = SignalGauge();
    final AdSpotPipe adSpotPipe = AdSpotPipe();
    final HandshakeGate handshakeGate = HandshakeGate(store);
    final PushRelay pushRelay = PushRelay(store);

    await tester.pumpWidget(JokerStreetApp(
      store: store,
      signalGauge: signalGauge,
      adSpotPipe: adSpotPipe,
      handshakeGate: handshakeGate,
      pushRelay: pushRelay,
    ));

    // A single pump — enough for the MaterialApp to appear. We do NOT
    // pumpAndSettle because the RouteBoss kicks off async pipelines
    // (Firebase, connectivity probe) that the test bindings do not
    // simulate; letting them run would just time out.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
