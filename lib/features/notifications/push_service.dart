import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../data/repositories/dairy_refs.dart';

/// Delivers the owner's notifications.
///
/// Two halves that are easy to confuse:
///
///   * When the app is **closed or backgrounded**, Android and iOS draw the
///     notification themselves from the FCM payload. Nothing in Dart runs.
///   * When the app is **open**, the OS stays silent by design, so the
///     foreground handler below raises a local notification instead. Without
///     it, updates that arrive while the owner is looking at the app appear to
///     go missing.
class PushService {
  PushService(this._refs);

  final DairyRefs _refs;

  final _local = FlutterLocalNotificationsPlugin();

  /// Must match the channelId the Cloud Function sends, or Android silently
  /// files the notification under a default channel with no sound.
  static const _channel = AndroidNotificationChannel(
    'doodh_updates',
    'Milk updates',
    description: 'Deliveries recorded and changes to past entries',
    importance: Importance.high,
  );

  /// Call once, after the owner's role is known.
  ///
  /// Deliberately not called for the delivery role: he has no reason to be
  /// notified of his own work, and registering his device would put a delivery
  /// phone in the owner-token list.
  Future<void> startForOwner() async {
    // Notifications are an addition to the dashboard, not a prerequisite for
    // it. If messaging is unavailable — permission refused, Play Services
    // missing, Firebase not configured — the owner should still get every
    // screen, with the History tab covering what the push would have said.
    try {
      await _start();
    } catch (e) {
      debugPrint('Push unavailable, continuing without it: $e');
    }
  }

  Future<void> _start() async {
    final messaging = FirebaseMessaging.instance;

    final settings = await messaging.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('Push permission denied; history still updates in-app.');
      return;
    }

    await _local.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );

    await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);

    FirebaseMessaging.onMessage.listen(_showForeground);

    await _registerToken(messaging);
    // A token can rotate at any time — after a reinstall, a restore, or on
    // Android's own schedule. Without this the owner silently stops receiving
    // notifications and there is nothing on screen to explain why.
    messaging.onTokenRefresh.listen((token) => _saveToken(token));
  }

  Future<void> _registerToken(FirebaseMessaging messaging) async {
    try {
      final token = await messaging.getToken();
      if (token != null) await _saveToken(token);
    } catch (e) {
      debugPrint('Could not get FCM token: $e');
    }
  }

  /// The token is the document ID, so re-registering the same device updates
  /// one row instead of growing the collection on every app launch.
  Future<void> _saveToken(String token) => _refs.ownerTokens.doc(token).set({
    'updatedAt': DateTime.now().toIso8601String(),
    'platform': defaultTargetPlatform.name,
  });

  Future<void> _showForeground(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    await _local.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  /// Remove this device on sign-out, so a phone that is handed on or reassigned
  /// stops receiving someone else's dairy notifications.
  Future<void> unregister() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _refs.ownerTokens.doc(token).delete();
    } catch (e) {
      debugPrint('Could not unregister token: $e');
    }
  }
}
