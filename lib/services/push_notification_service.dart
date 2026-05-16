import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../core/routes.dart';

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: 'https://agrishield-71213-default-rtdb.firebaseio.com',
  );
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<User?>? _authSubscription;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'agrishield_alerts',
    'AgriShield Alerts',
    description: 'Shows urgent crop alert notifications from Firebase',
    importance: Importance.max,
  );

  Future<void> initialize() async {
    await _requestPermissions();
    await _initializeLocalNotifications();
    await _configureForegroundPresentation();
    await _registerHandlers();
    _listenForAuthChanges();
  }

  Future<void> _requestPermissions() async {
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
  }

  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettings = InitializationSettings(android: androidSettings);

    await _localNotifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (response) {
        _handleNotificationPayload(response.payload);
      },
    );

    final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_channel);
  }

  Future<void> _configureForegroundPresentation() async {
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> _registerHandlers() async {
    FirebaseMessaging.onMessage.listen((message) async {
      final notification = message.notification;
      if (notification == null) return;

      await _showLocalNotification(
        title: notification.title ?? 'AgriShield Alert',
        body: notification.body ?? 'You have a new alert.',
        payload: _encodePayload(message.data),
      );
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleNotificationPayload(_encodePayload(message.data));
    });

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleNotificationPayload(_encodePayload(initialMessage.data));
      });
    }
  }

  void _listenForAuthChanges() {
    _authSubscription ??= _auth.authStateChanges().listen((user) {
      if (user == null) return;
      unawaited(_registerDeviceForNotifications(user));
    });
  }

  Future<void> _registerDeviceForNotifications(User user) async {
    final token = await _messaging.getToken();
    if (token == null || token.isEmpty) return;

    const nodeIds = ['node_001'];
    final tokenRef = _database.ref('notification_tokens/${user.uid}');
    await tokenRef.update({
      'token': token,
      'platform': defaultTargetPlatform.name,
      'updatedAt': ServerValue.timestamp,
      'nodeIds': {for (final nodeId in nodeIds) nodeId: true},
    });

    final subscriptionUpdates = <String, Object?>{};
    for (final nodeId in nodeIds) {
      subscriptionUpdates['node_subscribers/$nodeId/${user.uid}'] = true;
    }
    await _database.ref().update(subscriptionUpdates);

    FirebaseMessaging.instance.onTokenRefresh.listen((refreshedToken) async {
      await tokenRef.update({
        'token': refreshedToken,
        'platform': defaultTargetPlatform.name,
        'updatedAt': ServerValue.timestamp,
        'nodeIds': {for (final nodeId in nodeIds) nodeId: true},
      });
    });
  }

  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channel.id,
        _channel.name,
        channelDescription: _channel.description,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        icon: '@mipmap/ic_launcher',
      ),
    );

    await _localNotifications.show(
      id: title.hashCode,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }

  void _handleNotificationPayload(String? payload) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    navigator.pushNamedAndRemoveUntil(
      Routes.alerts,
      (route) => false,
    );
  }

  String _encodePayload(Map<String, dynamic> data) {
    return jsonEncode(data);
  }

  @pragma('vm:entry-point')
  static Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    if (kDebugMode) {
      debugPrint('Background push received: ${message.messageId}');
    }
  }
}
