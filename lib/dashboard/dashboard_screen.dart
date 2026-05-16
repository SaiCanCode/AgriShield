import 'package:agrishield2/core/responsive_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/agri_text.dart';
import '../widgets/weather_widget.dart';
import '../widgets/node_reading_card.dart';
import '../providers/readings_provider.dart';


class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final routes = ['/dashboard', '/alerts', '/node-status', '/history', '/settings'];
    return NavBar(
      currentIndex: 0, // 0 = Dashboard tab
      onTap: (int index) {
        Navigator.pushReplacementNamed(context, routes[index]);
      },
      child: SafeArea(
        child: Consumer(builder: (context, ref, _) {
          final asyncNodes = ref.watch(nodesListProvider);

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AgriText.h2('Dashboard'),
                const SizedBox(height: 24),
                asyncNodes.when(
                  data: (nodes) {
                    if (nodes.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24.0),
                        child: Text('No nodes found.'),
                      );
                    }

                    // Use a simple Column of cards inside the existing
                    // SingleChildScrollView to avoid nested scroll / viewport
                    // calculation issues that can cause bottom overflow.
                    return Column(
                      children: nodes.map((id) => Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: NodeReadingCard(nodeId: id),
                      )).toList(),
                    );
                  },
                  loading: () => const SizedBox(height: 120, child: Center(child: CircularProgressIndicator())),
                  error: (e, st) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24.0),
                    child: Text('Error loading nodes: $e'),
                  ),
                ),
                const SizedBox(height: 16),
                const WeatherWidget(),
                const SizedBox(height: 16),
              ],
            ),
          );
        }),
      ),
    );
  }
}