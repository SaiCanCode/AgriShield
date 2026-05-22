import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import '../services/realtime_service.dart';
import '../alerts/alert_entry.dart';
import '../models/sensor_reading.dart';

const String _databaseUrl = 'https://agrishield-71213-default-rtdb.firebaseio.com';

final realtimeServiceProvider = Provider<RealtimeService>((ref) {
  return RealtimeService(
    database: FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: _databaseUrl,
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
