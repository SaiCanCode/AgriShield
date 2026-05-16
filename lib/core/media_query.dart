// ignore: file_names
import 'package:flutter/material.dart';

class Responsive {
  Responsive._();

  // Breakpoint — anything above 600px wide is a tablet
  static const double _tabletBreakpoint = 600;

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < _tabletBreakpoint;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= _tabletBreakpoint;

  // Get the screen width 
  static double width(BuildContext context) =>
      MediaQuery.of(context).size.width;

  static double height(BuildContext context) =>
      MediaQuery.of(context).size.height;
}