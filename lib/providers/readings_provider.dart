import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import '../config/firebase_config.dart';
import '../services/realtime_service.dart';
import '../alerts/alert_entry.dart';
import '../models/sensor_reading.dart';

final realtimeServiceProvider = Provider<RealtimeService>((ref) {
  return RealtimeService(
    database: FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: firebaseDatabaseUrl,
    ),
  );
});

final latestReadingProvider = StreamProvider.family<SensorReading?, String>((ref, nodeId) {
  final svc = ref.watch(realtimeServiceProvider);
  return svc.streamLatestReading(nodeId);
});

final recentAlertsProvider =
    StreamProvider.family<List<AlertEntry>, String>((ref, nodeId) {
  final svc = ref.watch(realtimeServiceProvider);
  return svc.streamRecentAlerts(nodeId);
});

final nodesListProvider = StreamProvider<List<String>>((ref) {
  final svc = ref.watch(realtimeServiceProvider);
  return svc.streamNodesList();
});

/// Debug: stream the raw readings map for a node (returns null if none)
final nodeRawReadingsProvider = StreamProvider.family<Map<String, dynamic>?, String>((ref, nodeId) {
  final svc = ref.watch(realtimeServiceProvider);
  return svc.streamRawReadings(nodeId);
});

/// Streams alerts from all nodes combined into a single sorted list.
/// Merges alerts from node_001 and node_002 and sorts by timestamp (newest first).
final allNodesAlertsProvider = StreamProvider<List<AlertEntry>>((ref) {
  final svc = ref.watch(realtimeServiceProvider);
  return _combineAlertsFromAllNodes(svc);
});

/// Helper function that combines alert streams from multiple nodes.
/// Manually listens to both node streams and emits combined sorted results.
Stream<List<AlertEntry>> _combineAlertsFromAllNodes(RealtimeService svc) async* {
  List<AlertEntry>? latest1;
  List<AlertEntry>? latest2;
  
  final stream1 = svc.streamRecentAlerts('node_001');
  final stream2 = svc.streamRecentAlerts('node_002');
  
  final controller = StreamController<List<AlertEntry>>();
  
  final subscription1 = stream1.listen((alerts) {
    latest1 = alerts;
    if (latest1 != null && latest2 != null) {
      final combined = <AlertEntry>[...latest1!, ...latest2!];
      combined.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      controller.add(combined);
    }
  });
  
  final subscription2 = stream2.listen((alerts) {
    latest2 = alerts;
    if (latest1 != null && latest2 != null) {
      final combined = <AlertEntry>[...latest1!, ...latest2!];
      combined.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      controller.add(combined);
    }
  });
  
  // Yield from the controller stream and clean up on close
  try {
    yield* controller.stream;
  } finally {
    subscription1.cancel();
    subscription2.cancel();
    await controller.close();
  }
}
