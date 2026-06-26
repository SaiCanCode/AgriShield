import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../config/firebase_config.dart';
import 'node_history_model.dart';

// time range selector
final timeRangeProvider = StateProvider<TimeRange>(
  (ref) => TimeRange.h24,
);

//History stream per node + time range

final nodeHistoryProvider = StreamProvider.family<
    List<NodeHistoryPoint>,
    ({String nodeId, TimeRange range})>((ref, args) {
  final db = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: firebaseDatabaseUrl,
  );

  final ref_ = db
      .ref('nodes/${args.nodeId}/readings')
      .orderByKey()
      .limitToLast(args.range.points);

  return ref_.onValue.map((event) {
    final snap = event.snapshot;
    if (snap.value == null) return <NodeHistoryPoint>[];

    final data = snap.value;
    if (data is! Map) return <NodeHistoryPoint>[];

    final points = <NodeHistoryPoint>[];

    for (final entry in data.entries) {
      if (entry.value is! Map) continue;
      final map = Map<String, dynamic>.from(entry.value as Map);
      final ts  = int.tryParse(entry.key.toString()) ?? 0;
      if (ts == 0) continue;
      points.add(NodeHistoryPoint.fromMap(map, ts));
    }

    // ascending by time so charts render left → right
    points.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return points;
  });
});
