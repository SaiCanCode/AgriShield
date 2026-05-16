import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/readings_provider.dart';
// ignore: unused_import
import '../models/sensor_reading.dart';

class LatestReadingCard extends ConsumerWidget {
  final String nodeId;
  const LatestReadingCard({super.key, required this.nodeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncReading = ref.watch(latestReadingProvider(nodeId));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: asyncReading.when(
          data: (reading) {
            if (reading == null) return const Text('No readings yet for this node.');

            // `reading` is now a typed `SensorReading`.
            final temp = reading.temp.toStringAsFixed(1);
            final hum = reading.humidity.toStringAsFixed(1);
            final soil = reading.soil.toStringAsFixed(1);
            final alert = reading.alertType;
            final ts = reading.timestamp;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Node: $nodeId', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text('Timestamp: $ts'),
                const SizedBox(height: 8),
                Wrap(spacing: 12, children: [
                  Text('Temp: $temp °C'),
                  Text('Humidity: $hum %'),
                  Text('Soil: $soil %'),
                ]),
                const SizedBox(height: 8),
                Text('Alert: $alert', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            );
          },
          loading: () => const SizedBox(height: 64, child: Center(child: CircularProgressIndicator())),
          error: (e, st) => Text('Error loading reading: $e'),
        ),
      ),
    );
  }
}
