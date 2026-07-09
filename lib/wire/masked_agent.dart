import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;

import '../setup/app_mask.dart';
import '../setup/mask_bytes.dart';

// ---------------------------------------------------------------
// MaskedAgent — http client wearing a real device Chrome UA
// ---------------------------------------------------------------
// Outgoing requests (portal gate POST, GCD retry, push image fetch)
// and the WebView all share one user-agent string that mimics the
// real device's Chrome build. A default Dart UA leaks Flutter and
// the shell instantly.
//
// The Chrome major is fixed at 149 per
// .cursor/rules/gray_user_agent.mdc; the build/patch fragment is
// project-unique and decoded from mask_bytes.
// ---------------------------------------------------------------

// GAME THEME CATEGORY: slot  (appid/appname suffix REQUIRED)
// Per .cursor/rules/gray_user_agent.mdc §2, the appid/appname suffix
// is appended after the canonical browser UA, in this exact order:
//   … Mobile Safari/<webkit> appid/<packageName> appname/<AppNameToken>
// The suffix is sourced from AppMask so the value never has to be
// hardcoded in two places.
class MaskedAgent extends http.BaseClient {
  final http.Client _delegate = http.Client();
  String _stamp = 'Mozilla/5.0';

  String get userAgent => _stamp;

  /// Reads device info and assembles the user-agent. Call once in main().
  Future<void> prime() async {
    final String chrome =
        _orDefault(unveilChromeFingerprint(), '149.0.7813.127');
    final String webkit =
        _orDefault(unveilWebkitFingerprint(), '537.36');
    // AppNameToken: PascalCase, no spaces. Preserve casing per §2.
    final String appNameToken = AppMask.showName.replaceAll(' ', '');
    final String suffix =
        ' appid/${AppMask.packageName} appname/$appNameToken';

    try {
      final DeviceInfoPlugin sensor = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final AndroidDeviceInfo drone = await sensor.androidInfo;
        final String tag = drone.display.isNotEmpty ? drone.display : drone.id;
        _stamp = 'Mozilla/5.0 (Linux; Android ${drone.version.release}; '
            '${drone.brand} ${drone.model} Build/$tag) '
            'AppleWebKit/$webkit (KHTML, like Gecko) '
            'Chrome/$chrome Mobile Safari/$webkit$suffix';
      } else if (Platform.isIOS) {
        final IosDeviceInfo ios = await sensor.iosInfo;
        final String os = ios.systemVersion.replaceAll('.', '_');
        _stamp = 'Mozilla/5.0 (iPhone; CPU iPhone OS $os like Mac OS X) '
            'AppleWebKit/$webkit (KHTML, like Gecko) '
            'Version/${ios.systemVersion} Mobile/15E148 Safari/$webkit$suffix';
      }
    } catch (_) {
      // Realistic fallback if device_info_plus is unavailable.
      _stamp = 'Mozilla/5.0 (Linux; Android 14; SM-A536B Build/UP1A.231005.007) '
          'AppleWebKit/$webkit (KHTML, like Gecko) '
          'Chrome/$chrome Mobile Safari/$webkit$suffix';
    }
  }

  static String _orDefault(String value, String fallback) =>
      value.isNotEmpty ? value : fallback;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.putIfAbsent('User-Agent', () => _stamp);
    return _delegate.send(request);
  }

  @override
  void close() => _delegate.close();
}

/// Shared client used by every networking bridge.
final MaskedAgent maskedAgent = MaskedAgent();
