// ignore_for_file: avoid_print, avoid_relative_lib_imports
import '../lib/setup/mask_bytes.dart';

/// Confirms the four packed byte arrays round-trip to the expected
/// plaintext. Run once after `pack_ciphers.dart` regeneration.
void main() {
  final Map<String, String> checks = <String, String>{
    'portalGate': unveilPortalGate(),
    'chromeFingerprint': unveilChromeFingerprint(),
    'webkitFingerprint': unveilWebkitFingerprint(),
    'adSpotterKey': unveilAdSpotterKey(),
    'messagingRef': unveilMessagingRef(),
    'gcdUrl (sample)':
        unveilGcdUrl('com.joker.jokerstreet', 'sample-device-id'),
  };
  const Map<String, String> expected = <String, String>{
    'portalGate': 'https://jokersttreet.com/config.php',
    'chromeFingerprint': '149.0.7813.127',
    'webkitFingerprint': '537.36',
    'adSpotterKey': 'AybqpvKFmB5U5mB2UzR83G',
    'messagingRef': '734686002392',
  };

  bool ok = true;
  checks.forEach((String name, String value) {
    final String? want = expected[name];
    final String status = (want == null)
        ? 'INFO'
        : (value == want ? 'PASS' : 'FAIL');
    if (status == 'FAIL') ok = false;
    print('[$status] $name → "$value"');
  });

  print(ok ? '\n✓ all round-trips OK' : '\n✗ mismatch — re-run pack_ciphers');
}
