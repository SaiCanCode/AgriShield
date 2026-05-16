import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agrishield2/core/responsive_nav.dart';
import '../providers/readings_provider.dart';

class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routes = ['/dashboard', '/alerts', '/node-status', '/history', '/settings'];
    final alerts = ref.watch(recentAlertsProvider('node_001'));

    return NavBar(
      currentIndex: 1, // Alerts = index 1
      onTap: (int index) {
        Navigator.pushReplacementNamed(context, routes[index]);
      },
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Alerts',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 12),
              alerts.when(
                data: (items) {
                  if (items.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.only(top: 24),
                      child: Text('No alerts yet for node_001.'),
                    );
                  }

                  return Column(
                    children: items
                        .map(
                          (alert) => Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: const Icon(Icons.warning_amber_rounded),
                              title: Text(alert.type.toUpperCase()),
                              subtitle: Text(
                                'Value: ${alert.value.toStringAsFixed(2)} | Threshold: ${alert.threshold.toStringAsFixed(2)} | SMS sent: ${alert.smsSent ? 'yes' : 'no'}',
                              ),
                              trailing: Text(alert.timestamp.toString()),
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Text('Failed to load alerts: $error'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}