// ignore_for_file: avoid_print
// ---------------------------------------------------------------
// pack_ciphers — offline encoder for the Joker Street portal
// ---------------------------------------------------------------
// Mirrors lib/cipher/weaver.dart exactly. Run:
//   dart run tool/pack_ciphers.dart
// then paste each printed const array into lib/setup/mask_bytes.dart.
//
// Always launch via `dart run` (native 64-bit ints). PowerShell wraps
// integers at 32 bits and corrupts the byte stream — the packed strings
// then decode to garbage and every HTTP call fails with the vague
// "Invalid HTTP header field value" symptom.
// ---------------------------------------------------------------

const String projectSeed = 'JkrStr_p7fQ!m9';
const int stripLength = 32;

List<int> weaveStrip() {
  int digest = 0x811C9DC5;
  for (final int cp in projectSeed.codeUnits) {
    digest = (digest ^ cp) & 0xFFFFFFFF;
    digest = (digest * 0x01000193) & 0xFFFFFFFF;
  }
  int walker = digest == 0 ? 0x9E3779B9 : digest;
  final List<int> strip = List<int>.filled(stripLength, 0);
  for (int slot = 0; slot < stripLength; slot++) {
    walker ^= (walker << 13) & 0xFFFFFFFF;
    walker ^= walker >> 17;
    walker ^= (walker << 5) & 0xFFFFFFFF;
    walker &= 0xFFFFFFFF;
    strip[slot] = (walker >> 16) & 0xFF;
  }
  return strip;
}

final List<int> strip = weaveStrip();

List<int> pack(String plain) {
  final List<int> bytes = plain.codeUnits;
  final List<int> shielded = List<int>.filled(bytes.length, 0);
  for (int idx = 0; idx < bytes.length; idx++) {
    shielded[idx] =
        (bytes[idx] ^ strip[idx % stripLength] ^ (idx & 0xFF)) & 0xFF;
  }
  return shielded;
}

void emit(String label, String plain) {
  if (plain.isEmpty) {
    print('// $label — (empty, populate later)');
    print('const <int>[];\n');
    return;
  }
  final List<int> shielded = pack(plain);
  print('// $label  <= "$plain"');
  print('const <int>[${shielded.join(', ')}],\n');
}

void main() {
  // ── Fill in the plaintext values, then run this script ──
  const String portalGate = 'https://jokersttreet.com/config.php';
  const String gcdBase = 'https://gcdsdk.appsflyer.com/install_data/v4.0/';

  // Chrome 149 build/patch — regenerated per project per
  // .cursor/rules/gray_user_agent.mdc.
  const String chromeFingerprint = '149.0.7813.127';
  const String webkitFingerprint = '537.36';

  // Provided by the manager:
  const String adSpotterKey = 'AybqpvKFmB5U5mB2UzR83G'; // AppsFlyer Dev Key
  const String messagingRef = '734686002392'; // Firebase project number

  print('=== Joker Street pack_ciphers ===\n');
  emit('portalGate', portalGate);
  emit('gcdBase', gcdBase);
  emit('chromeFingerprint', chromeFingerprint);
  emit('webkitFingerprint', webkitFingerprint);
  emit('adSpotterKey', adSpotterKey);
  emit('messagingRef', messagingRef);
}
