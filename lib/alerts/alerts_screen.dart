import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agrishield2/core/responsive_nav.dart';
import '../widgets/agri_surface_card.dart';
import 'alert_detail_sheet.dart';
import '../providers/readings_provider.dart';

class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routes = ['/dashboard', '/alerts', '/node-status', '/history', '/settings'];
    final alerts = ref.watch(allNodesAlertsProvider);

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
              const SizedBox(height: 12),
              alerts.when(
                data: (items) {
                  if (items.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.only(top: 24),
                      child: Text('No alerts yet.'),
                    );
                  }

                  return Column(
                    children: items
                        .map(
                          (alert) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: AgriSurfaceCard(
                              padding: EdgeInsets.zero,
                              borderRadius: BorderRadius.circular(18),
                              onTap: () => showAlertDetailSheet(context, alert),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                                leading: const Icon(Icons.warning_amber_rounded),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(alert.type.toUpperCase()),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[300],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        alert.nodeId,
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Value: ${alert.value.toStringAsFixed(2)} | Threshold: ${alert.threshold.toStringAsFixed(2)} | SMS sent: ${alert.smsSent ? 'yes' : 'no'}',
                                    ),
                                    if (alert.message.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 6.0),
                                        child: Text(alert.message),
                                      ),
                                    if (alert.action.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4.0),
                                        child: Text('Action: ${alert.action}'),
                                      ),
                                  ],
                                ),
                                trailing: Text(alert.timestamp.toString()),
                              ),
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