import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:flutter/foundation.dart';

import '../setup/app_mask.dart';
import '../setup/mask_bytes.dart';
import 'masked_agent.dart';

// ---------------------------------------------------------------
// AdSpotPipe — AppsFlyer install + deep-link attribution collector
// ---------------------------------------------------------------
// Folds three callback streams (install conversion, app-open
// attribution, deep-link) into the merged body that gets POSTed to
// the portal gate.
//
// Organic false-positive guard: AppsFlyer occasionally reports
// af_status == "Organic" on the first conversion callback for
// genuinely paid installs. When that happens we wait a few seconds
// and re-query the GCD endpoint for the real attribution.
//
// If no Dev Key is configured yet, the bridge short-circuits: the
// install-data future completes immediately with an empty map so the
// portal doesn't stall for 30 s before falling back to the game.
// ---------------------------------------------------------------

class AdSpotPipe {
  AppsflyerSdk? _sdk;

  Map<String, dynamic>? _installData;
  Map<String, dynamic>? _deepLinkData;
  Map<String, dynamic>? _appOpenData;

  final Completer<Map<String, dynamic>> _installReady =
      Completer<Map<String, dynamic>>();
  final Completer<void> _deepLinkReady = Completer<void>();

  bool _spun = false;

  /// Wires the SDK callbacks and starts init. Safe to call once.
  Future<void> spinUp() async {
    if (_spun) return;
    _spun = true;

    final String devKey = AppMask.adSpotterKey;
    if (devKey.isEmpty) {
      _finishInstall(<String, dynamic>{});
      _finishDeepLink();
      return;
    }

    final AppsFlyerOptions options = AppsFlyerOptions(
      afDevKey: devKey,
      appId: AppMask.storeNumeric,
      showDebug: kDebugMode,
      timeToWaitForATTUserAuthorization: 10,
    );

    final AppsflyerSdk sdk = AppsflyerSdk(options);
    _sdk = sdk;

    sdk.onInstallConversionData((dynamic res) async {
      final Map<String, dynamic> payload = _flatten(res);
      final String? status = payload['af_status']?.toString();
      if (status == 'Organic') {
        await Future<void>.delayed(
          Duration(seconds: AppMask.organicRecheckSeconds),
        );
        final Map<String, dynamic>? refreshed = await _gcdRecheck();
        _installData = refreshed ?? payload;
      } else {
        _installData = payload;
      }
      if (kDebugMode) {
        debugPrint('[AdSpotPipe] install data: ${jsonEncode(_installData)}');
      }
      _finishInstall(_installData ?? <String, dynamic>{});
    });

    sdk.onAppOpenAttribution((dynamic res) {
      _appOpenData = _flatten(res);
    });

    sdk.onDeepLinking((DeepLinkResult result) {
      final Map<String, dynamic>? click = result.deepLink?.clickEvent;
      if (click != null) {
        _deepLinkData = Map<String, dynamic>.from(click);
      }
      if (kDebugMode) {
        debugPrint('[AdSpotPipe] deep link: ${jsonEncode(_deepLinkData)}');
      }
      _finishDeepLink();
    });

    try {
      await sdk.initSdk(
        registerConversionDataCallback: true,
        registerOnAppOpenAttributionCallback: true,
        registerOnDeepLinkingCallback: true,
      );
    } catch (_) {
      _finishInstall(<String, dynamic>{});
      _finishDeepLink();
    }
  }

  /// Waits up to [seconds] for the install conversion payload.
  Future<Map<String, dynamic>> awaitInstallData({int seconds = 30}) {
    return _installReady.future.timeout(
      Duration(seconds: seconds),
      onTimeout: () => <String, dynamic>{},
    );
  }

  /// Waits up to 5 s for the deep-link callback.
  Future<void> awaitDeepLink() {
    return _deepLinkReady.future
        .timeout(const Duration(seconds: 5), onTimeout: () {});
  }

  Future<String?> uid() async {
    if (_sdk == null) return null;
    try {
      return await _sdk!.getAppsFlyerUID();
    } catch (_) {
      return null;
    }
  }

  /// Assembles the merged body that is POSTed to the portal gate.
  ///
  /// Order (see .cursor/rules/android_gray_guide.md §"Config Request
  /// Contract" §2): install → deep link (putIfAbsent) → app open
  /// (putIfAbsent) → device-side fields (overwrite).
  Future<Map<String, dynamic>> assemblePortalBody({
    required String locale,
    String? pushToken,
  }) async {
    final Map<String, dynamic> body = <String, dynamic>{};

    if (_installData != null) body.addAll(_installData!);
    _deepLinkData
        ?.forEach((String k, dynamic v) => body.putIfAbsent(k, () => v));
    _appOpenData
        ?.forEach((String k, dynamic v) => body.putIfAbsent(k, () => v));

    body['af_id'] = await uid() ?? '';
    body['bundle_id'] = AppMask.packageName;
    body['os'] = Platform.isAndroid ? 'Android' : 'iOS';
    body['store_id'] = AppMask.marketRef;
    body['locale'] = locale;

    if (pushToken != null && pushToken.isNotEmpty) {
      body['push_token'] = pushToken;
    }
    final String project = AppMask.messagingRef;
    if (project.isNotEmpty) {
      body['firebase_project_id'] = project;
    }

    if (kDebugMode) {
      debugPrint('[AdSpotPipe] portal body: ${jsonEncode(body)}');
    }
    return body;
  }

  Future<Map<String, dynamic>?> _gcdRecheck() async {
    try {
      final String? deviceId = await uid();
      if (deviceId == null) return null;
      final String appId = Platform.isIOS
          ? AppMask.storeNumeric
          : AppMask.packageName;
      final String url = unveilGcdUrl(appId, deviceId);
      if (url.isEmpty) return null;

      final dynamic response = await maskedAgent.get(
        Uri.parse(url),
        headers: <String, String>{
          'authorization': 'Bearer ${AppMask.adSpotterKey}',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        if (kDebugMode) {
          debugPrint('[AdSpotPipe] GCD retry response: ${response.body}');
        }
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  void _finishInstall(Map<String, dynamic> data) {
    if (!_installReady.isCompleted) _installReady.complete(data);
  }

  void _finishDeepLink() {
    if (!_deepLinkReady.isCompleted) _deepLinkReady.complete();
  }

  static Map<String, dynamic> _flatten(dynamic res) {
    if (res is! Map) return <String, dynamic>{};
    final dynamic inner = res['payload'] ?? res['data'] ?? res;
    if (inner is Map) {
      return inner.map((dynamic k, dynamic v) =>
          MapEntry<String, dynamic>(k.toString(), v));
    }
    return <String, dynamic>{};
  }
}
