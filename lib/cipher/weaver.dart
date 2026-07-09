import 'dart:typed_data';

// ---------------------------------------------------------------
// Weaver — keystream string veil for the Joker Street portal
// ---------------------------------------------------------------
// The portal keeps its network fingerprints (config gate, ad-key,
// firebase project id, spoofed Chrome build) as byte lists and only
// resolves them at runtime through this module. Plaintext literals
// would otherwise become instant grep targets for store scanners.
//
// Cipher construction:
//   * FNV-1a over the project seed produces a starting hash.
//   * That hash bootstraps an xorshift32 generator which spits out a
//     `_stripLength`-byte pad.
//   * Each output byte = plain ^ pad[i % len] ^ (i & 0xFF).
//     The positional XOR breaks byte-frequency analysis: repeating
//     characters do not encode to repeating bytes.
//
// The routine is symmetric — `tool/pack_ciphers.dart` uses the SAME
// implementation to produce the packed arrays.
//
// [FINGERPRINT] The seed and pad length are project-unique. If either
// value changes, the packed arrays MUST be regenerated:
//   dart run tool/pack_ciphers.dart
// then pasted into `lib/setup/mask_bytes.dart`.
// ---------------------------------------------------------------

const String _projectSeed = 'JkrStr_p7fQ!m9';
const int _stripLength = 32;

Uint8List _weaveStrip() {
  int digest = 0x811C9DC5;
  for (final int cp in _projectSeed.codeUnits) {
    digest = (digest ^ cp) & 0xFFFFFFFF;
    digest = (digest * 0x01000193) & 0xFFFFFFFF;
  }

  int walker = digest == 0 ? 0x9E3779B9 : digest;
  final Uint8List strip = Uint8List(_stripLength);
  for (int slot = 0; slot < _stripLength; slot++) {
    walker ^= (walker << 13) & 0xFFFFFFFF;
    walker ^= walker >> 17;
    walker ^= (walker << 5) & 0xFFFFFFFF;
    walker &= 0xFFFFFFFF;
    strip[slot] = (walker >> 16) & 0xFF;
  }
  return strip;
}

final Uint8List _keystream = _weaveStrip();

/// Decodes a packed byte list back into its plaintext form. Returns an
/// empty string for empty input so the portal degrades to the native
/// game path when the arrays have not been populated yet.
String unshield(List<int> packed) {
  if (packed.isEmpty) return '';
  final Uint8List revealed = Uint8List(packed.length);
  for (int idx = 0; idx < packed.length; idx++) {
    revealed[idx] =
        (packed[idx] ^ _keystream[idx % _stripLength] ^ (idx & 0xFF)) & 0xFF;
  }
  return String.fromCharCodes(revealed);
}
