import 'package:flutter/material.dart';
import 'package:agrishield2/core/responsive_nav.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final routes = ['/dashboard', '/alerts', '/node-status', '/history', '/settings'];
    return NavBar(
      currentIndex: 3, // History = index 3
      onTap: (int index) {
        Navigator.pushReplacementNamed(context, routes[index]);
      },
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
          child: Column(
            children: [
              // Your history content here
            ],
          ),
        ),
      ),
    );
  }
}