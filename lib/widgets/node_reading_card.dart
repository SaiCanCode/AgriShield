import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/readings_provider.dart';

class NodeReadingCard extends ConsumerWidget {
  final String nodeId;
  const NodeReadingCard({super.key, required this.nodeId});

  String _timeAgo(int tsSeconds) {
    if (tsSeconds == 0) return 'never';
    final dt = DateTime.fromMillisecondsSinceEpoch(tsSeconds * 1000);
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Color _soilColor(double soil) {
    if (soil <= 0) return Colors.grey;
    if (soil < 30) return Colors.orange;
    if (soil > 90) return Colors.red;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncReading = ref.watch(latestReadingProvider(nodeId));
    final asyncRaw = ref.watch(nodeRawReadingsProvider(nodeId));

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: asyncReading.when(
          data: (reading) {
            if (reading == null) {
              // Show raw snapshot if available to help debug import/format issues
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Node: $nodeId', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  asyncRaw.when(
                    data: (raw) {
                      if (raw == null || raw.isEmpty) return const Text('No readings yet', style: TextStyle(color: Colors.grey));
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Text(raw.toString(), style: const TextStyle(fontSize: 12, color: Colors.white70)),
                      );
                    },
                    loading: () => const Text('No readings yet', style: TextStyle(color: Colors.grey)),
                    error: (e, st) => Text('No readings yet (debug error: $e)', style: const TextStyle(color: Colors.grey)),
                  ),
                ],
              );
            }

            final temp = reading.temp.toStringAsFixed(1);
            final hum = reading.humidity.toStringAsFixed(1);
            final soil = reading.soil.toStringAsFixed(0);
            final alert = (reading.toMap()['alert_type'] ?? 'none').toString();
            final ts = reading.timestamp;
            final online = (DateTime.now().toUtc().millisecondsSinceEpoch / 1000 - ts) < (60 * 30);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Node: $nodeId', style: Theme.of(context).textTheme.titleMedium),
                    Row(children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: online ? Colors.green : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(_timeAgo(ts), style: const TextStyle(fontSize: 12, color: Colors.black54)),
                    ])
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(spacing: 12, runSpacing: 8, children: [
                  Chip(label: Text('Temp: $temp °C')),
                  Chip(label: Text('Humidity: $hum %')),
                  Chip(
                    avatar: CircleAvatar(backgroundColor: _soilColor(reading.soil)),
                    label: Text('Soil: $soil %'),
                  ),
                ]),
                const SizedBox(height: 8),
                if (alert != 'none' && alert.isNotEmpty)
                  Row(children: [
                    const Icon(Icons.warning, color: Colors.red, size: 18),
                    const SizedBox(width: 6),
                    Text(alert, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                  ]),
              ],
            );
          },
          loading: () => const SizedBox(height: 96, child: Center(child: CircularProgressIndicator())),
          error: (e, st) => Text('Error: $e'),
        ),
      ),
    );
  }
}
