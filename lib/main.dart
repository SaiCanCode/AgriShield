import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme.dart';
import 'package:agrishield2/core/routes.dart';
import 'firebase_options.dart';
import 'services/push_notification_service.dart';


/// Initializes Firebase and starts the app
Future<void> main() async {
  // Ensure Flutter bindings are initialized before any async operations
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with platform-specific options
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize notification handlers before the UI starts listening.
  await PushNotificationService.instance.initialize();

  FirebaseMessaging.onBackgroundMessage(
    PushNotificationService.firebaseMessagingBackgroundHandler,
  );

  // Run the app with Riverpod provider support
  runApp(
    /// Wrap app with ProviderScope to enable Riverpod
    const ProviderScope(child: MyApp()),
  );
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AgriShield',
      theme: AgriTheme.dark,
      initialRoute: Routes.splash,
      onGenerateRoute: generateRoute,
      navigatorKey: PushNotificationService.instance.navigatorKey,
      debugShowCheckedModeBanner: false,
    );
  }
}
