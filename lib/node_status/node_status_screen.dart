import 'package:flutter/material.dart';
import 'package:agrishield2/core/responsive_nav.dart';

class NodeStatusScreen extends StatelessWidget {
  const NodeStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final routes = ['/dashboard', '/alerts', '/node-status', '/history', '/settings'];
    return NavBar(
      currentIndex: 2, // Node Status = index 2
      onTap: (int index) {
        Navigator.pushReplacementNamed(context, routes[index]);
      },
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
          child: Column(
            children: [
              // Node status content here
            ],
          ),
        ),
      ),
    );
  }
}