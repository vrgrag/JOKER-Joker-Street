import 'legal_urls.dart';
import 'mask_bytes.dart';

// ---------------------------------------------------------------
// AppMask — single access point for portal-wide constants
// ---------------------------------------------------------------
// Identity values are plain text; endpoints/credentials resolve
// lazily through the weaver so no plaintext lands in the binary.
// ---------------------------------------------------------------

class AppMask {
  AppMask._();

  // ────────────────────────────────────────────────────────
  // Identity
  // ────────────────────────────────────────────────────────
  static const String packageName = 'com.joker.jokerstreet';
  static const String marketRef = 'com.joker.jokerstreet';
  static const String showName = 'Joker Street';

  // iOS App Store numeric id (unused on Android).
  static const String storeNumeric = '';

  // ────────────────────────────────────────────────────────
  // Resolved endpoints / credentials
  // ────────────────────────────────────────────────────────
  static String get portalGate => unveilPortalGate();
  static String get adSpotterKey => unveilAdSpotterKey();
  static String get messagingRef => unveilMessagingRef();

  // ────────────────────────────────────────────────────────
  // Public links (plain text — non-sensitive)
  // ────────────────────────────────────────────────────────
  static const String privacyUrl = privacyPageUrl;
  static const String supportUrl = supportPageUrl;
  static const String homeUrl = projectHomeUrl;

  // ────────────────────────────────────────────────────────
  // Timing knobs
  // ────────────────────────────────────────────────────────
  /// Re-prompt the push invite this many seconds after a Skip
  /// (3 days). Do not lower without approval.
  static const int inviteRearmSeconds = 3 * 24 * 60 * 60;

  /// Delay before retrying attribution via GCD when the first
  /// callback reports a (possibly false) Organic status.
  static const int organicRecheckSeconds = 5;
}
