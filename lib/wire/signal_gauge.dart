import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

// ---------------------------------------------------------------
// SignalGauge — connectivity probe used by the portal
// ---------------------------------------------------------------
// [isOnline] combines the OS adapter state with a real DNS lookup so
// captive / limited networks (public wifi, VPN warm-up) are treated
// as offline. VPN adapters count as connectivity — otherwise every
// VPN toggle would flash the No-Wi-Fi screen for a heartbeat.
// ---------------------------------------------------------------

const Set<ConnectivityResult> _liveAdapters = <ConnectivityResult>{
  ConnectivityResult.wifi,
  ConnectivityResult.mobile,
  ConnectivityResult.ethernet,
  ConnectivityResult.vpn,
  ConnectivityResult.bluetooth,
  ConnectivityResult.other,
};

class SignalGauge {
  SignalGauge({Connectivity? sensor})
      : _sensor = sensor ?? Connectivity();

  final Connectivity _sensor;

  /// Returns true when at least one live adapter is present AND a DNS
  /// probe against cloudflare completes within 7 seconds. Real "no
  /// route" cases throw SocketException instantly, so the larger
  /// timeout costs nothing on genuine failures.
  Future<bool> isOnline() async {
    final List<ConnectivityResult> states =
        await _sensor.checkConnectivity();
    if (!states.any(_liveAdapters.contains)) return false;

    try {
      final List<InternetAddress> probe =
          await InternetAddress.lookup('cloudflare.com')
              .timeout(const Duration(seconds: 7));
      return probe.isNotEmpty && probe.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Stream<List<ConnectivityResult>> get pulseChanges =>
      _sensor.onConnectivityChanged;
}
