import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import '../config/firebase_config.dart';
import '../alerts/alert_entry.dart';
import '../models/sensor_reading.dart';

class RealtimeService {
  final FirebaseDatabase _db;

  RealtimeService({FirebaseDatabase? database})
      : _db = database ??
            FirebaseDatabase.instanceFor(
              app: Firebase.app(),
              databaseURL: firebaseDatabaseUrl,
            );

  /// Streams the most recent reading object for [nodeId].
  /// Emits `SensorReading` or `null` if none.
  Stream<SensorReading?> streamLatestReading(String nodeId) {
    final ref = _db.ref('nodes/$nodeId/readings');

    return ref.orderByKey().limitToLast(1).onValue.map((DatabaseEvent event) {
      final snapshot = event.snapshot;
      if (snapshot.value == null) return null;

      final dynamic data = snapshot.value;
      if (data is Map && data.isNotEmpty) {
        final firstKey = data.keys.first;
        final firstVal = data[firstKey];
        if (firstVal is Map) {
          final Map<String, dynamic> map = Map<String, dynamic>.from(firstVal);
          // Try to derive timestamp from the child key first, then fallback to payload field 'ts'.
          int ts = 0;
          try {
            ts = int.tryParse(firstKey.toString()) ?? 0;
          } catch (_) {
            ts = 0;
          }
          if (ts == 0 && map['ts'] != null) {
            if (map['ts'] is int) { ts = map['ts'] as int;
            }
            else {
              ts = int.tryParse(map['ts'].toString()) ?? 0;
            }
          }

          return SensorReading.fromMap(map, timestamp: ts, nodeId: nodeId);
        }
      }
      return null;
    });
  }

  /// Streams the most recent alert entries for [nodeId].
  /// Emits a descending list ordered by timestamp.
  Stream<List<AlertEntry>> streamRecentAlerts(
    String nodeId, {
    int limit = 10,
  }) {
    final ref = _db.ref('nodes/$nodeId/alerts');

    return ref.orderByKey().limitToLast(limit).onValue.map((event) {
      final snapshot = event.snapshot;
      if (snapshot.value == null) {
        return const <AlertEntry>[];
      }

      final dynamic data = snapshot.value;
      if (data is! Map) {
        return const <AlertEntry>[];
      }

      final alerts = <AlertEntry>[];
      for (final entry in data.entries) {
        if (entry.value is! Map) continue;

        final payload = Map<String, dynamic>.from(entry.value as Map);
        final timestamp = _parseTimestamp(entry.key, payload['ts']);

        alerts.add(
          AlertEntry.fromMap(
            payload,
            timestamp: timestamp,
            alertId: entry.key.toString(),
            nodeId: nodeId,
          ),
        );
      }

      alerts.sort((left, right) => right.timestamp.compareTo(left.timestamp));
      return alerts;
    });
  }

  /// Example: exchange a custom token (minted by your provisioning server)
  /// for an ID token using the Identity Toolkit REST API. Use the returned
  /// `idToken` as the bearer token for authenticated RTDB writes.
  ///
  /// This is a minimal example; in production handle errors, retries, and
  /// securely store the returned tokens.
  Future<String?> exchangeCustomTokenForIdToken({
    required String customToken,
    required String webApiKey,
  }) async {
    final url = Uri.parse(
        'https://identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=$webApiKey');
    final body = {
      'token': customToken,
      'returnSecureToken': true,
    };

    final client = HttpClient();
    try {
      final request = await client.postUrl(url);
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
      final response = await request.close();
      final respBody = await response.transform(utf8.decoder).join();
      if (response.statusCode == 200) {
        final map = jsonDecode(respBody) as Map<String, dynamic>;
        return map['idToken'] as String?;
      }
      return null;
    } finally {
      client.close();
    }
  }

  int _parseTimestamp(dynamic key, dynamic payloadTs) {
    final parsedFromKey = int.tryParse(key.toString()) ?? 0;
    if (parsedFromKey != 0) return parsedFromKey;

    if (payloadTs is int) return payloadTs;
    return int.tryParse(payloadTs?.toString() ?? '') ?? 0;
  }

  /// Streams the list of node IDs present under `/nodes`.
  /// Emits an empty list when no nodes are present.
  Stream<List<String>> streamNodesList() {
    final ref = _db.ref('nodes');
    return ref.onValue.map((event) {
      final snapshot = event.snapshot;
      if (snapshot.value == null) return <String>[];
      final data = snapshot.value;
      if (data is Map) {
        // Defensive handling: sometimes users import JSON with an extra
        // nesting level (e.g. `/nodes: { nodes: { node_001: ... } }`). If
        // so, prefer the inner map's keys.
        if (data.length == 1 && data.containsKey('nodes') && data['nodes'] is Map) {
          final inner = data['nodes'] as Map;
          return inner.keys.map((k) => k.toString()).toList();
        }
        return data.keys.map((k) => k.toString()).toList();
      }
      return <String>[];
    });
  }

  /// Streams the raw `readings` map stored for [nodeId] (or null).
  Stream<Map<String, dynamic>?> streamRawReadings(String nodeId) {
    final ref = _db.ref('nodes/$nodeId/readings');
    return ref.onValue.map((event) {
      final snapshot = event.snapshot;
      if (snapshot.value == null) return null;
      final data = snapshot.value;
      if (data is Map) return Map<String, dynamic>.from(data);
      return null;
    });
  }
}
