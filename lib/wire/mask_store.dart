import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../kind/app_flavor.dart';

// ---------------------------------------------------------------
// MaskStore — persistence layer for the portal
// ---------------------------------------------------------------
// Plain flags live in SharedPreferences; URLs live in encrypted
// secure storage. Keys are neutral / terse so a prefs dump on a
// rooted device does not reveal intent.
// ---------------------------------------------------------------

class MaskStore {
  MaskStore({FlutterSecureStorage? crypt})
      : _crypt = crypt ?? const FlutterSecureStorage();

  static const String _kFlavor = 'js_flavor_v2';
  static const String _kCachedLink = 'jsc_link';
  static const String _kLinkTtl = 'jsc_ttl';
  static const String _kInviteRearm = 'js_notice_rearm';
  static const String _kPushGranted = 'js_notice_ok';
  static const String _kPushBlocked = 'js_notice_blocked';
  static const String _kPendingLink = 'jsp_link';

  late final SharedPreferences _prefs;
  final FlutterSecureStorage _crypt;

  Future<void> warmUp() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ── App flavor ──
  AppFlavor readFlavor() => AppFlavor.read(_prefs.getString(_kFlavor));

  Future<void> writeFlavor(AppFlavor flavor) =>
      _prefs.setString(_kFlavor, flavor.write());

  // ── Cached portal link (encrypted) ──
  Future<String?> readCachedLink() => _crypt.read(key: _kCachedLink);

  Future<void> writeCachedLink(String link) =>
      _crypt.write(key: _kCachedLink, value: link);

  // ── Link expiry ──
  int? readLinkTtl() => _prefs.getInt(_kLinkTtl);

  Future<void> writeLinkTtl(int unixSeconds) =>
      _prefs.setInt(_kLinkTtl, unixSeconds);

  bool isLinkStale() {
    final int? ttl = readLinkTtl();
    if (ttl == null) return true;
    return _nowSeconds() >= ttl;
  }

  // ── Push permission state ──
  bool isPushGranted() => _prefs.getBool(_kPushGranted) ?? false;

  Future<void> markPushGranted(bool value) =>
      _prefs.setBool(_kPushGranted, value);

  /// True once the user denied the OS dialog — the system will refuse
  /// to open it again, so the invite screen must stop reappearing.
  bool isPushBlockedByOs() => _prefs.getBool(_kPushBlocked) ?? false;

  Future<void> markPushBlockedByOs() =>
      _prefs.setBool(_kPushBlocked, true);

  int? readInviteRearm() => _prefs.getInt(_kInviteRearm);

  Future<void> writeInviteRearm(int unixSeconds) =>
      _prefs.setInt(_kInviteRearm, unixSeconds);

  /// Decides whether to show the push-invite promo before the WebView.
  bool shouldOfferInvite() {
    if (isPushGranted()) return false;
    if (isPushBlockedByOs()) return false;
    final int? until = readInviteRearm();
    if (until == null) return true;
    return _nowSeconds() >= until;
  }

  // ── One-time push link (encrypted) ──
  Future<void> stashPendingLink(String? link) async {
    if (link == null) {
      await _crypt.delete(key: _kPendingLink);
    } else {
      await _crypt.write(key: _kPendingLink, value: link);
    }
  }

  Future<String?> takePendingLink() async {
    final String? link = await _crypt.read(key: _kPendingLink);
    if (link != null) await _crypt.delete(key: _kPendingLink);
    return link;
  }

  static int _nowSeconds() =>
      DateTime.now().millisecondsSinceEpoch ~/ 1000;
}
