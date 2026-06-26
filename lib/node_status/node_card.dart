import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/readings_provider.dart';
import 'dht_chart.dart';
import 'node_history_model.dart';
import 'node_history_provider.dart';
import 'soil_chart.dart';

class NodeCard extends ConsumerWidget {
  const NodeCard({super.key, required this.nodeId});

  final String nodeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range        = ref.watch(timeRangeProvider);
    final historyAsync = ref.watch(
      nodeHistoryProvider((nodeId: nodeId, range: range)),
    );
    final latestAsync  = ref.watch(latestReadingProvider(nodeId));
    final cs           = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color:        cs.surface,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: cs.outline, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _NodeCardHeader(nodeId: nodeId, latestAsync: latestAsync),
          const Divider(height: 1, thickness: 0.5),
          historyAsync.when(
            loading: () => const SizedBox(
              height: 280,
              child: Center(child: CircularProgressIndicator(strokeWidth: 1.5)),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Failed to load history: $e',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.45),
                ),
              ),
            ),
            data: (points) => points.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'No readings yet for $nodeId.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.45),
                      ),
                    ),
                  )
                : _NodeCardCharts(points: points),
          ),
        ],
      ),
    );
  }
}

//Header
class _NodeCardHeader extends StatelessWidget {
  const _NodeCardHeader({
    required this.nodeId,
    required this.latestAsync,
  });

  final String nodeId;
  final AsyncValue latestAsync;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          // Node name
          Text(
            nodeId,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),

          const Spacer(),

          // Latest values 
          latestAsync.maybeWhen(
            data: (reading) {
              if (reading == null) return const SizedBox.shrink();
              final alertType =
                  reading.toMap()['alert_type']?.toString() ?? 'none';
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (alertType != 'none') ...[
                    Text(
                      _capitalize(alertType),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Text(
                    '${reading.temp.toStringAsFixed(1)}°C',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${reading.soil.toStringAsFixed(0)}% soil',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

//Charts section 

class _NodeCardCharts extends StatelessWidget {
  const _NodeCardCharts({required this.points});
  final List<NodeHistoryPoint> points;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SoilChart(points: points),
          const SizedBox(height: 20),
          const Divider(height: 1, thickness: 1),
          const SizedBox(height: 20),
          DhtChart(points: points),
        ],
      ),
    );
  }
}
