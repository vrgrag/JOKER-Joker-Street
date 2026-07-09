import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'mask_store.dart';
import 'masked_agent.dart';

// ---------------------------------------------------------------
// PushRelay — Firebase Messaging + local notification renderer
// ---------------------------------------------------------------
// Cold-start taps (app was killed) stash the link so the portal
// opens it on the next boot. Warm taps (background / foreground)
// deliver the link live via [onLiveLink] without persisting it —
// push links are one-time per spec.
//
// The Android notification channel id MUST match the manifest's
// `default_notification_channel_id` meta-data. The small icon is a
// dedicated flame drawable, never the launcher icon.
// ---------------------------------------------------------------

// [FINGERPRINT] Both constants and _smallIcon MUST match the manifest
// meta-data:
//   • kChannelId ↔ com.google.firebase.messaging.default_notification_channel_id
//   • kChannelName is the user-visible name in Android system settings
//     ("Notifications for Joker Street").
//   • _smallIcon references res/drawable/ic_notification.xml.
const String kChannelId = 'joker_beats';
const String kChannelName = 'Street Updates';
const String _smallIcon = '@drawable/ic_notification';

@pragma('vm:entry-point')
Future<void> _bgHandler(RemoteMessage message) async {
  // The OS renders background notifications on its own; the tap is
  // processed on resume (warm) or boot (cold) — nothing to do here.
}

class PushRelay {
  PushRelay(this._store);

  final MaskStore _store;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  FirebaseMessaging? _fm;
  String? _token;
  bool _ready = false;

  /// Live (warm) push link delivery → loaded straight into the WebView.
  void Function(String link)? onLiveLink;

  /// Fired when FCM rotates the token → re-post to the portal.
  void Function(String token)? onTokenRotated;

  String? get token => _token;

  Future<void> boot() async {
    if (_ready) return;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      _fm = FirebaseMessaging.instance;
      FirebaseMessaging.onBackgroundMessage(_bgHandler);

      await _setupLocal();

      _token = await _fm!.getToken();
      _fm!.onTokenRefresh.listen((String t) {
        _token = t;
        onTokenRotated?.call(t);
      });

      FirebaseMessaging.onMessage.listen(_onForeground);
      FirebaseMessaging.onMessageOpenedApp.listen(_onWarmTap);

      final RemoteMessage? initial = await _fm!.getInitialMessage();
      if (initial != null) _onColdTap(initial);

      _ready = true;
    } catch (_) {
      // Firebase not configured yet — push stays dormant, app keeps
      // running through the native path.
    }
  }

  Future<void> _setupLocal() async {
    const AndroidInitializationSettings android =
        AndroidInitializationSettings(_smallIcon);
    const DarwinInitializationSettings ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _local.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (NotificationResponse r) {
        final String? payload = r.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final Map<String, dynamic> data =
              jsonDecode(payload) as Map<String, dynamic>;
          final String? link = data['url'] as String?;
          if (link != null && link.isNotEmpty) onLiveLink?.call(link);
        } catch (_) {}
      },
    );

    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? bridge =
          _local.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await bridge?.createNotificationChannel(
        const AndroidNotificationChannel(
          kChannelId,
          kChannelName,
          description: 'Live updates from the carnival',
          importance: Importance.high,
        ),
      );
    }
  }

  /// Asks for notification permission (Android 13+ system dialog).
  /// Records an OS-denied flag so the invite screen never loops.
  Future<bool> askPermission() async {
    if (_fm == null) return false;
    final NotificationSettings settings = await _fm!.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    final AuthorizationStatus status = settings.authorizationStatus;
    final bool granted = status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;

    await _store.markPushGranted(granted);
    if (status == AuthorizationStatus.denied) {
      await _store.markPushBlockedByOs();
    }
    return granted;
  }

  void _onForeground(RemoteMessage message) async {
    final RemoteNotification? n = message.notification;
    if (n == null || !Platform.isAndroid) return;

    AndroidNotificationDetails? details;
    final String? imageUrl = n.android?.imageUrl;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      final Uint8List? bytes = await _fetchImage(imageUrl);
      if (bytes != null) {
        details = AndroidNotificationDetails(
          kChannelId,
          kChannelName,
          importance: Importance.high,
          priority: Priority.high,
          icon: _smallIcon,
          styleInformation: BigPictureStyleInformation(
            ByteArrayAndroidBitmap(bytes),
            largeIcon:
                const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          ),
        );
      }
    }

    details ??= const AndroidNotificationDetails(
      kChannelId,
      kChannelName,
      importance: Importance.high,
      priority: Priority.high,
      icon: _smallIcon,
    );

    await _local.show(
      id: n.hashCode,
      title: n.title,
      body: n.body,
      notificationDetails: NotificationDetails(android: details),
      payload: message.data.isNotEmpty ? jsonEncode(message.data) : null,
    );
  }

  void _onColdTap(RemoteMessage message) {
    final String? link = message.data['url'] as String?;
    if (link != null && link.isNotEmpty) {
      _store.stashPendingLink(link);
    }
  }

  void _onWarmTap(RemoteMessage message) {
    final String? link = message.data['url'] as String?;
    if (link != null && link.isNotEmpty) {
      onLiveLink?.call(link);
    }
  }

  Future<Uint8List?> _fetchImage(String url) async {
    try {
      final dynamic res = await maskedAgent
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) return res.bodyBytes as Uint8List;
    } catch (_) {}
    return null;
  }
}
