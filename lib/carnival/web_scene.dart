import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../theme/palette.dart';
import '../wire/mask_store.dart';
import '../wire/masked_agent.dart';
import '../wire/push_relay.dart';
import '../wire/signal_gauge.dart';
import 'no_link_scene.dart';

// ---------------------------------------------------------------
// WebScene — immersive full-screen WebView (gray portal)
// ---------------------------------------------------------------
// Hosts the content link with: spoofed device UA, both orientations,
// immersive system UI, external-scheme hand-off, redirect-loop
// recovery, live connectivity guard, warm push link swap, file
// uploads, third-party cookies, media autoplay and the safe-area /
// keyboard JS fixes.
//
// [FINGERPRINT] The upload MethodChannel name MUST match the string
// in MainActivity.kt. Both use 'joker/media_pick'.
// ---------------------------------------------------------------

class WebScene extends StatefulWidget {
  const WebScene({
    super.key,
    required this.link,
    required this.store,
    required this.pushRelay,
    required this.signalGauge,
  });

  final String link;
  final MaskStore store;
  final PushRelay pushRelay;
  final SignalGauge signalGauge;

  @override
  State<WebScene> createState() => _WebSceneState();
}

class _WebSceneState extends State<WebScene> with WidgetsBindingObserver {
  late final WebViewController _web;
  bool _spinner = true;
  bool _offlineShown = false;
  String? _lastMainFrame;
  int _redirectRetries = 0;
  StreamSubscription<List<ConnectivityResult>>? _pulseSub;
  static const MethodChannel _uploadChannel =
      MethodChannel('joker/media_pick');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _enterImmersive();
    _buildController();

    widget.pushRelay.onLiveLink = (String link) {
      if (mounted) _web.loadRequest(Uri.parse(link));
    };

    _pulseSub =
        widget.signalGauge.pulseChanges.listen((List<ConnectivityResult> r) {
      if (r.isNotEmpty &&
          r.every((ConnectivityResult e) => e == ConnectivityResult.none)) {
        // Immediate swap — no DNS probe, that can hang for up to 7 s
        // while offline and the WebView's built-in error page would
        // flash in the interim.
        _openOffline();
      }
    });
  }

  void _enterImmersive() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _enterImmersive();
  }

  void _buildController() {
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(maskedAgent.userAgent)
      ..setBackgroundColor(Colors.black)
      ..enableZoom(false)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() => _spinner = true);
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _spinner = false);
          _redirectRetries = 0;
          _neutraliseSafeAreaCss();
          _injectKeyboardScroll();
        },
        onWebResourceError: (WebResourceError err) {
          if (err.isForMainFrame != true) return;
          final String d = err.description.toLowerCase();
          final bool loop = d.contains('too_many_redirects') ||
              d.contains('too many redirects') ||
              err.errorCode == -1007 ||
              err.errorCode == -9;
          if (loop && _lastMainFrame != null && _redirectRetries < 3) {
            _redirectRetries++;
            _web.loadRequest(Uri.parse(_lastMainFrame!));
            return;
          }
          // Cover the WebView with our own overlay so the native error
          // page is never visible while we decide what to do.
          if (mounted) setState(() => _spinner = true);
          final bool dnsOrDrop = d.contains('name_not_resolved') ||
              d.contains('err_name_not_resolved') ||
              d.contains('internet_disconnected') ||
              d.contains('network_changed') ||
              err.errorCode == -105 ||
              err.errorCode == -106 ||
              err.errorCode == -21;
          if (dnsOrDrop) {
            _openOffline();
          } else {
            _guardOffline();
          }
        },
        onNavigationRequest: (NavigationRequest req) {
          final Uri? uri = Uri.tryParse(req.url);
          if (uri == null) return NavigationDecision.prevent;
          const Set<String> inApp = <String>{
            'http',
            'https',
            'about',
            'data',
            'blob',
          };
          if (inApp.contains(uri.scheme)) {
            if (req.isMainFrame) _lastMainFrame = req.url;
            return NavigationDecision.navigate;
          }
          _openExternally(uri);
          return NavigationDecision.prevent;
        },
      ));

    _tuneAndroid();
    _web.loadRequest(Uri.parse(widget.link));
  }

  void _tuneAndroid() {
    if (!Platform.isAndroid) return;
    if (_web.platform is! AndroidWebViewController) return;
    final AndroidWebViewController a =
        _web.platform as AndroidWebViewController;

    // Inline autoplay video, no tap-to-start, no full-screen takeover.
    a.setMediaPlaybackRequiresUserGesture(false);

    // Auto-grant Protected Media ID (DRM) / camera / microphone so
    // Widevine streams and OTP camera prompts do not stall behind a
    // system modal.
    a.setOnPlatformPermissionRequest(
      (PlatformWebViewPermissionRequest req) => req.grant(),
    );

    // Wire <input type="file"> to the native chooser via
    // MethodChannel — no file_picker dependency.
    a.setOnShowFileSelector(_pickFiles);

    // Third-party cookies keep OAuth / payment sessions alive across
    // redirect back to the partner domain.
    final AndroidWebViewCookieManager cookies = AndroidWebViewCookieManager(
      AndroidWebViewCookieManagerCreationParams
          .fromPlatformWebViewCookieManagerCreationParams(
        const PlatformWebViewCookieManagerCreationParams(),
      ),
    );
    cookies.setAcceptThirdPartyCookies(a, true);
  }

  Future<List<String>> _pickFiles(FileSelectorParams params) async {
    try {
      final List<Object?>? picked = await _uploadChannel
          .invokeMethod<List<Object?>>('pick', <String, Object>{
        'multiple': params.mode == FileSelectorMode.openMultiple,
        'mimeTypes': params.acceptTypes
            .where((String t) => t.trim().isNotEmpty)
            .toList(),
      });
      if (picked == null) return const <String>[];
      return picked.whereType<String>().toList();
    } catch (_) {
      return const <String>[];
    }
  }

  Future<void> _openExternally(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  /// Probe-then-show. Used for WebView load errors, which can be
  /// transient (partner is momentarily unreachable but the device is
  /// online — we do not want to boot the user to the No-Wi-Fi screen
  /// for a partner outage).
  Future<void> _guardOffline() async {
    if (_offlineShown) return;
    final bool live = await widget.signalGauge.isOnline();
    if (live) return;
    _openOffline();
  }

  /// Immediate swap to the offline screen. Retry rebuilds the
  /// WebView at the last known main-frame URL.
  void _openOffline() {
    if (_offlineShown || !mounted) return;
    _offlineShown = true;
    final String current = _lastMainFrame ?? widget.link;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => NoLinkScene(
          onRetryBuild: (_) => WebScene(
            link: current,
            store: widget.store,
            pushRelay: widget.pushRelay,
            signalGauge: widget.signalGauge,
          ),
        ),
      ),
    );
  }

  // Scrolls focused inputs above the keyboard. Uses behavior:'auto'
  // and a single delayed pass to avoid fighting the keyboard animation.
  void _injectKeyboardScroll() {
    _web.runJavaScript(r'''
(function(){
  if (window.__jsKbFix) return; window.__jsKbFix = true;
  function isField(el){return el&&(el.tagName==='INPUT'||el.tagName==='TEXTAREA'||el.isContentEditable);}
  function bring(){
    var el=document.activeElement; if(!isField(el))return;
    var vp=window.visualViewport;
    if(vp){
      var r=el.getBoundingClientRect(); var bottom=vp.offsetTop+vp.height;
      if(r.bottom>bottom-20||r.top<vp.offsetTop){el.scrollIntoView({behavior:'auto',block:'nearest'});}
    } else { el.scrollIntoView({behavior:'auto',block:'nearest'}); }
  }
  document.addEventListener('focusin',function(e){ if(isField(e.target)) setTimeout(bring,350); });
  if(window.visualViewport){
    var prev=window.visualViewport.height;
    window.visualViewport.addEventListener('resize',function(){
      var h=window.visualViewport.height; if(h<prev) setTimeout(bring,120); prev=h;
    });
  }
})();
''');
  }

  // Neutralises site-defined safe-area CSS variables so notched devices
  // do not show white bands on top / sides. Deliberately does NOT touch
  // html/body/#app horizontal padding — that would collapse the partner
  // site's gutters (see .cursor/rules/webview_safe_area_injection.mdc).
  void _neutraliseSafeAreaCss() {
    _web.runJavaScript(r'''
(function(){
  if(window.__jsSa) return; window.__jsSa=true;
  var ID='__js_sa';
  var CSS=':root{'
    +'--safe-area-inset-top:0px!important;'
    +'--safe-area-inset-right:0px!important;'
    +'--safe-area-inset-bottom:0px!important;'
    +'--safe-area-inset-left:0px!important;'
    +'--sat:0px!important;--sar:0px!important;'
    +'--sab:0px!important;--sal:0px!important;'
    +'--safe-top:0px!important;--safe-bottom:0px!important;'
    +'--safe-left:0px!important;--safe-right:0px!important;'
    +'}'
    +'.gameview-mobile-header,.app-header,.js-safe-top{'
    +'padding-top:0!important;margin-top:0!important;}';
  function kbOpen(){ if(!window.visualViewport)return false; return window.visualViewport.height<window.innerHeight*0.75; }
  function apply(){
    if(kbOpen())return;
    var head=document.head||document.documentElement; if(!head)return;
    var m=document.querySelector('meta[name="viewport"]');
    if(m && !/viewport-fit\s*=\s*contain/i.test(m.getAttribute('content')||'')){
      var c=(m.getAttribute('content')||'').replace(/,?\s*viewport-fit\s*=\s*\w+/ig,'').trim();
      m.setAttribute('content', c+(c?', ':'')+'viewport-fit=contain');
    }
    var s=document.getElementById(ID);
    if(!s){ s=document.createElement('style'); s.id=ID; head.appendChild(s); }
    if(s.textContent!==CSS) s.textContent=CSS;
  }
  apply();
  ['pushState','replaceState'].forEach(function(fn){
    var o=history[fn]; history[fn]=function(){var r=o.apply(this,arguments); setTimeout(apply,80); setTimeout(apply,400); return r;};
  });
  window.addEventListener('popstate',function(){setTimeout(apply,80);});
  setInterval(apply,2500);
})();
''');
  }

  Future<void> _back() async {
    if (await _web.canGoBack()) {
      await _web.goBack();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulseSub?.cancel();
    widget.pushRelay.onLiveLink = null;
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mq = MediaQuery.of(context);
    final bool landscape = mq.orientation == Orientation.landscape;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, _) async {
        if (!didPop) await _back();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: false,
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // Camera-cutout inset in BOTH orientations (top in portrait,
            // sides in landscape). System bars stay hidden, so this is
            // purely the display-cutout inset. Bottom stays 0 — keyboard
            // handled by the JS scroll fix.
            SafeArea(
              bottom: false,
              child: WebViewWidget(controller: _web),
            ),
            if (_spinner && !landscape)
              const ColoredBox(
                color: Color(0x80000000),
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Palette.gold),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
