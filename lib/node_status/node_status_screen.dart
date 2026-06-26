import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/responsive_nav.dart';
import '../providers/readings_provider.dart';
import 'node_card.dart';
import 'node_history_model.dart';
import 'node_history_provider.dart';

class NodeStatusScreen extends ConsumerWidget {
  const NodeStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routes = [
      '/dashboard',
      '/alerts',
      '/node-status',
      '/history',
      '/settings',
    ];

    return NavBar(
      currentIndex: 2,
      onTap: (index) =>
          Navigator.pushReplacementNamed(context, routes[index]),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Screen header
            _NodeStatusHeader(),
            const Divider(height: 1, thickness: 0.5),

            //Scrollable node cards
            Expanded(
              child: Consumer(
                builder: (context, ref, _) {
                  final nodesAsync = ref.watch(nodesListProvider);

                  return nodesAsync.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(strokeWidth: 1.5),
                    ),
                    error: (e, _) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Could not load nodes: $e',
                          style: Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    data: (nodes) {
                      if (nodes.isEmpty) {
                        return _EmptyNodes();
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
                        itemCount: nodes.length,
                        itemBuilder: (context, index) =>
                            NodeCard(nodeId: nodes[index]),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Screen header with time range selector 

class _NodeStatusHeader extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(timeRangeProvider);
    final cs    = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nodes',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Live sensor graphs',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
          const Spacer(),

          //  Time range toggle
          Container(
            decoration: BoxDecoration(
              color:        cs.surface,
              borderRadius: BorderRadius.circular(8),
              border:       Border.all(color: cs.outline, width: 0.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: TimeRange.values.map((r) {
                final isActive = r == range;
                return GestureDetector(
                  onTap: () => ref
                      .read(timeRangeProvider.notifier)
                      .state = r,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isActive
                          ? cs.primary.withValues(alpha: 0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      r.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isActive
                            ? FontWeight.w700
                            : FontWeight.w400,
                        color: isActive
                            ? cs.primary
                            : cs.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

//Empty state

class _EmptyNodes extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.sensors_off_outlined,
              size: 40,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.25),
            ),
            const SizedBox(height: 14),
            Text(
              'No nodes found',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.45),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Power on a node and wait for the first reading to appear.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
