import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../theme/palette.dart';
import '../wire/insight.dart';
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
  // Insight funnel state:
  //   _offerReached — flips true on the FIRST error-free onPageFinished so
  //     `web_offer_reached` is emitted exactly once per session; used to
  //     decide `web_offer_unreachable` vs `web_error_after_load` in errors.
  //   _pageHadError — reset on every navigation start; blocks a "false
  //     success" if a mid-navigation error fires before onPageFinished.
  bool _offerReached = false;
  bool _pageHadError = false;
  StreamSubscription<List<ConnectivityResult>>? _pulseSub;
  static const MethodChannel _uploadChannel =
      MethodChannel('joker/media_pick');

  // Cashier / register / login URL classifiers (mirror the JS probe below
  // so SPA route changes and native page loads report the same funnel).
  static final RegExp _depositRx = RegExp(
      r'(deposit|cashier|top.?up|replenish|payment|checkout|wallet|пополн|депозит|касс|оплат|внести|платеж)',
      caseSensitive: false);
  static final RegExp _registerRx = RegExp(
      r'(sign.?up|regist|create.?account|onboarding|регистрац|зарегистр)',
      caseSensitive: false);
  static final RegExp _loginRx = RegExp(
      r'(sign.?in|log.?in|log.?on|/auth\b|authoriz|войти|вход|авториз)',
      caseSensitive: false);

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
    Insight.screen('web');
    Insight.event('web_open');
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
    if (state == AppLifecycleState.resumed) {
      _enterImmersive();
      Insight.event('web_foreground');
    } else if (state == AppLifecycleState.paused) {
      // Paused while inside the WebView is the clearest drop-off marker —
      // combined with the `last_screen` tag it points at abandonment on
      // the offer site itself.
      Insight.event('web_background');
    }
  }

  void _buildController() {
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(maskedAgent.userAgent)
      ..setBackgroundColor(Colors.black)
      ..enableZoom(false)
      ..addJavaScriptChannel(
        'AegisInsight',
        onMessageReceived: (JavaScriptMessage m) => _onWebSignal(m.message),
      )
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          // Per-navigation reset — a mid-load error can then correctly veto
          // the `web_offer_reached` classification for this URL.
          _pageHadError = false;
          if (mounted) setState(() => _spinner = true);
        },
        onPageFinished: (String url) {
          if (mounted) setState(() => _spinner = false);
          _redirectRetries = 0;
          _neutraliseSafeAreaCss();
          _injectKeyboardScroll();
          _installInsightProbe();
          _trackWebPage(url);
        },
        onWebResourceError: (WebResourceError err) {
          if (err.isForMainFrame != true) return;
          _pageHadError = true;
          final String d = err.description.toLowerCase();
          final bool loop = d.contains('too_many_redirects') ||
              d.contains('too many redirects') ||
              err.errorCode == -1007 ||
              err.errorCode == -9;

          // Classify + tag the error BEFORE the redirect-loop recovery so
          // the reason is captured even when the retry succeeds.
          final String reason = _classifyWebError(err);
          final String failed = _lastMainFrame ?? widget.link;
          final String host = Uri.tryParse(failed)?.host ?? '';
          Insight.event('web_error');
          Insight.tag('web_error_reason', reason);
          Insight.tag('web_last_error', '${err.errorCode}:${err.description}');
          if (host.isNotEmpty) Insight.tag('web_error_host', host);
          if (!_offerReached) {
            // The user never actually reached the offer — the most common
            // cause of "paid install, zero funnel" (e.g. ERR_CONNECTION_REFUSED).
            Insight.event('web_offer_unreachable');
            Insight.tag('offer_reached', 'false');
            Insight.tag('offer_unreachable_reason', reason);
          } else {
            Insight.event('web_error_after_load');
          }

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
          // External scheme hand-off (payment app, banking, tel:, mailto:).
          // Track it before launching — the OS chooser can silently steal
          // the user and we want the last known intent in the session.
          Insight.event('web_external');
          Insight.tag('web_external_scheme', uri.scheme);
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

  // ── Insight funnel: native page tracking ─────────────────────────

  void _trackWebPage(String url) {
    final Uri? uri = Uri.tryParse(url);
    final String label = uri == null ? url : '${uri.host}${uri.path}';
    Insight.screenName('web:$label');
    Insight.event('web_page');
    Insight.tag('web_last_url', url);
    if (!_offerReached && !_pageHadError) {
      _offerReached = true;
      Insight.event('web_offer_reached');
      Insight.tag('offer_reached', 'true');
      if (uri?.host != null) Insight.tag('offer_host', uri!.host);
    }
    if (_depositRx.hasMatch(url)) {
      Insight.event('web_cashier_page');
      Insight.tag('reached_cashier', 'true');
    }
    _trackAuthPage(url);
  }

  void _trackAuthPage(String url) {
    if (_registerRx.hasMatch(url)) {
      Insight.event('web_register_page');
      Insight.tag('reached_register', 'true');
    } else if (_loginRx.hasMatch(url)) {
      Insight.event('web_login_page');
      Insight.tag('reached_login', 'true');
    }
  }

  static String _classifyWebError(WebResourceError err) {
    final String d = err.description.toLowerCase();
    final int c = err.errorCode;
    if (d.contains('connection_refused') ||
        d.contains('connection refused')) return 'connection_refused';
    if (d.contains('too_many_redirects') ||
        d.contains('too many redirects')) return 'redirect_loop';
    if (d.contains('name_not_resolved') ||
        d.contains('address_unreachable') ||
        d.contains('unknownhost') ||
        c == -2) return 'dns_unresolved';
    if (d.contains('timed out') || d.contains('timeout') || c == -8) {
      return 'timeout';
    }
    if (d.contains('internet_disconnected') ||
        d.contains('network_changed') ||
        c == -6) return 'no_network';
    if (d.contains('connection_reset')) return 'connection_reset';
    if (d.contains('connection_closed') || d.contains('empty_response')) {
      return 'connection_closed';
    }
    if (d.contains('ssl') || d.contains('cert') || c == -11) {
      return 'ssl_error';
    }
    if (d.contains('blocked')) return 'blocked';
    return 'other';
  }

  // ── Insight funnel: in-page JS probe ────────────────────────────
  //
  // The partner site's DOM is invisible to Clarity's session replay,
  // so we bridge SPA route changes + deposit/register/login intents
  // back to native via the `AegisInsight` JavaScript channel.
  //
  // The probe is idempotent (`window.__aegisInsight` guard), so
  // re-injecting on every onPageFinished is safe.

  void _installInsightProbe() {
    _web.runJavaScript(r'''
(function(){
  if (window.__aegisInsight) return; window.__aegisInsight = true;
  function send(t){ try { AegisInsight.postMessage(t); } catch(e){} }
  var DEP=/(deposit|cashier|top.?up|add funds|replenish|payment|pay now|checkout|withdraw|пополн|депозит|касс|оплат|внести|вывод|платеж)/i;
  var REG=/(sign.?up|regist|create.?account|регистрац|зарегистр)/i;
  var LOG=/(sign.?in|log.?in|log.?on|войти|вход|авториз)/i;
  var lastPath='';
  function reportPath(){ var p=location.pathname+location.search; if(p!==lastPath){ lastPath=p; send('path:'+p);} }
  reportPath();
  ['pushState','replaceState'].forEach(function(fn){ var o=history[fn]; history[fn]=function(){ var r=o.apply(this,arguments); setTimeout(reportPath,60); return r; }; });
  window.addEventListener('popstate',function(){ setTimeout(reportPath,60); });
  document.addEventListener('click',function(e){
    try{ var el=e.target;
      for(var i=0;i<4&&el;i++){
        var t=((el.innerText||el.value||(el.getAttribute&&el.getAttribute('aria-label'))||'')+'').trim();
        if(t){ if(DEP.test(t)){send('deposit_click:'+t.slice(0,60));return;}
               if(REG.test(t)){send('register_click:'+t.slice(0,60));return;}
               if(LOG.test(t)){send('login_click:'+t.slice(0,60));return;} }
        el=el.parentElement;
      }
    }catch(x){}
  },true);
  document.addEventListener('submit',function(e){
    try{ var f=e.target;
      var pw=f.querySelectorAll?f.querySelectorAll('input[type="password"]'):[];
      var blob=((f.innerText||'')+' '+(f.getAttribute('action')||'')+' '+(f.className||''));
      var confirm=f.querySelector&&(f.querySelector('input[name*="confirm" i]')||f.querySelector('input[name*="repeat" i]'));
      if(pw&&pw.length>=2){send('auth_submit:register');return;}
      if(pw&&pw.length===1){ send('auth_submit:'+((confirm||REG.test(blob))?'register':'login')); return; }
      if(REG.test(blob)){send('auth_submit:register');return;}
      if(LOG.test(blob)){send('auth_submit:login');return;}
      send('form_submit');
    }catch(x){ send('form_submit'); }
  },true);
})();
''');
  }

  void _onWebSignal(String raw) {
    final int i = raw.indexOf(':');
    final String type = i < 0 ? raw : raw.substring(0, i);
    final String data = i < 0 ? '' : raw.substring(i + 1);
    switch (type) {
      case 'path':
        Insight.event('web_spa_route');
        Insight.tag('web_last_path', data);
        if (_depositRx.hasMatch(data)) {
          Insight.event('web_cashier_page');
          Insight.tag('reached_cashier', 'true');
        }
        _trackAuthPage(data);
        break;
      case 'deposit_click':
        Insight.event('web_deposit_click');
        Insight.tag('deposit_intent', 'true');
        if (data.isNotEmpty) Insight.tag('deposit_label', data);
        break;
      case 'register_click':
        Insight.event('web_register_click');
        Insight.tag('register_intent', 'true');
        break;
      case 'login_click':
        Insight.event('web_login_click');
        Insight.tag('login_intent', 'true');
        break;
      case 'auth_submit':
        if (data == 'register') {
          Insight.event('web_register_submit');
          Insight.tag('attempted_register', 'true');
        } else {
          Insight.event('web_login_submit');
          Insight.tag('attempted_login', 'true');
        }
        break;
      case 'form_submit':
        Insight.event('web_form_submit');
        break;
    }
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
