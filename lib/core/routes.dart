import 'package:agrishield2/auth/loginscreen.dart';
import 'package:flutter/material.dart';
import '../auth/splashscreen.dart';
import '../dashboard/dashboard_screen.dart';
import '../history/history_screen.dart';
import '../alerts/alerts_screen.dart';
import '../node_status/node_status_screen.dart';
import '../settings/settings_screen.dart';
import '../weather/weather_screen.dart';



class Routes {
  Routes._();

  static const String splash     = '/';
  static const String login      = '/login';
  static const String dashboard  = '/dashboard';
  static const String history    = '/history';
  static const String alerts     = '/alerts';
  static const String nodeStatus = '/node-status';
  static const String settings   = '/settings';
  static const String weather    = '/weather';
}



Route<dynamic> generateRoute(RouteSettings settings) {
  switch (settings.name) {

    case Routes.splash:
      return _go(const SplashScreen());

    case Routes.login:
      return _go(const LoginScreen());

    case Routes.dashboard:
      return _go(const DashboardScreen());

    case Routes.history:
      return _go(const HistoryScreen());

    case Routes.alerts:
      return _go(const AlertsScreen());

    case Routes.nodeStatus:
      return _go(const NodeStatusScreen());

    case Routes.settings:
      return _go(const SettingsScreen());

    case Routes.weather:
      return _go(const WeatherScreen());

    // If someone navigates to a route that doesn't exist
    default:
      return _go(
        Scaffold(
          body: Center(
            child: Text('Page not found: ${settings.name}'),
          ),
        ),
      );
  }
}



MaterialPageRoute _go(Widget screen) {
  return MaterialPageRoute(builder: (_) => screen);
}