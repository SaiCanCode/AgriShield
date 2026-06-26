import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme.dart';
import 'package:agrishield2/core/routes.dart';
import 'firebase_options.dart';
import 'alerts/app_alert_listener.dart';
import 'alerts/alert_rules_loader.dart';
import 'services/push_notification_service.dart';

class AgriScrollBehavior extends MaterialScrollBehavior {
  const AgriScrollBehavior();
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
    );
  }
}
/// Initializes Firebase and starts the app
Future<void> main() async {
  // Ensure Flutter bindings are initialized before any async operations
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Firebase with platform-specific options
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(
    PushNotificationService.firebaseMessagingBackgroundHandler,
  );
  // Run the app with Riverpod provider support
  runApp(
    /// Wrap app with ProviderScope to enable Riverpod
    const ProviderScope(child: MyApp()),
  );

  unawaited(_bootstrapDeferredServices());
}

Future<void> _bootstrapDeferredServices() async {
  try {
    await Future.wait([
      PushNotificationService.instance.initialize(),
      AlertRulesRepository.instance.initFromAsset(),
    ]);
  } catch (error, stackTrace) {
    debugPrint('Deferred startup bootstrap failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'AgriShield',
      theme: AgriTheme.light,
      darkTheme: AgriTheme.dark,
      themeMode: ThemeMode.system,
      scrollBehavior: const AgriScrollBehavior(),
      initialRoute: Routes.splash,
      onGenerateRoute: generateRoute,
      navigatorKey: PushNotificationService.instance.navigatorKey,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        if (child == null) {
          return const SizedBox.shrink();
        }
        // Keep system chrome (status bar) readable for the active theme
        final brightness = Theme.of(context).brightness;
        SystemChrome.setSystemUIOverlayStyle(
          brightness == Brightness.dark
              ? SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent)
              : SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
        );
        return AppAlertListener(child: child);
      },
    );
  }
}
