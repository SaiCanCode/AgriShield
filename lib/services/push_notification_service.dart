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
import '../firebase_options.dart';
import '../alerts/alert_entry.dart';

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

    static final FlutterLocalNotificationsPlugin _backgroundLocalNotifications =
      FlutterLocalNotificationsPlugin();
    static bool _backgroundNotificationsInitialized = false;

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
      // Foreground popup side effects are handled via Riverpod ref.listen.
      if (kDebugMode) {
        debugPrint('Foreground push received: ${message.messageId}');
      }
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

  Future<void> showAlertNotification(AlertEntry alert) async {
    final title = _titleForAlertType(alert.type);
    final body = _bodyForAlert(alert);
    await _showLocalNotification(
      title: title,
      body: body,
      payload: _encodePayload({
        'alertType': alert.type,
        'alertId': alert.alertId,
        'alertTs': alert.timestamp.toString(),
      }),
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

  static String _titleForAlertType(String rawType) {
    final type = rawType.trim().toLowerCase();
    if (type.isEmpty) return 'AgriShield Alert';

    switch (type) {
      case 'drought':
        return 'Drought Alert';
      case 'flood':
        return 'Flood Alert';
      case 'heat':
        return 'Heat Alert';
      case 'blight':
        return 'Blight Risk Alert';
      default:
        return 'AgriShield Alert';
    }
  }

  static String _bodyForAlert(AlertEntry alert) {
    if (alert.message.isNotEmpty) {
      return alert.message;
    }

    final type = alert.type.trim().toLowerCase();
    final value = alert.triggerValue.toStringAsFixed(2);
    final threshold = alert.threshold.toStringAsFixed(2);

    if (type == 'drought') {
      return 'Low soil moisture detected. Value: $value%, threshold: $threshold%.';
    }
    if (type == 'flood') {
      return 'High soil moisture detected. Value: $value%, threshold: $threshold%.';
    }

    return 'New ${alert.type.toUpperCase()} alert. Value: $value, threshold: $threshold.';
  }

  static Future<void> _ensureBackgroundLocalNotifications() async {
    if (_backgroundNotificationsInitialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettings = InitializationSettings(android: androidSettings);

    await _backgroundLocalNotifications.initialize(settings: initializationSettings);

    final androidPlugin = _backgroundLocalNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_channel);
    _backgroundNotificationsInitialized = true;
  }

  static Future<void> _showBackgroundLocalNotification(RemoteMessage message) async {
    final notification = message.notification;

    // If a notification payload is present, Android/iOS usually display it
    // while the app is backgrounded/terminated. Avoid duplicate popups.
    if (notification != null) return;

    final data = message.data;
    final alertType = (data['alertType'] ?? data['type'] ?? 'alert').toString();
    final title = _titleForAlertType(alertType);
    final value = (data['value'] ?? '').toString();
    final threshold = (data['threshold'] ?? '').toString();
    final body =
        'New ${alertType.toUpperCase()} alert. Value: $value, threshold: $threshold.';

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

    await _backgroundLocalNotifications.show(
      id: title.hashCode,
      title: title,
      body: body,
      notificationDetails: details,
      payload: jsonEncode(data),
    );
  }

  @pragma('vm:entry-point')
  static Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await _ensureBackgroundLocalNotifications();
    await _showBackgroundLocalNotification(message);

    if (kDebugMode) {
      debugPrint('Background push received: ${message.messageId}');
    }
  }
}
