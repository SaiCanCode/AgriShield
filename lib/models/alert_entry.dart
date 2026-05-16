class AlertEntry {
  final String alertId;
  final int timestamp;
  final String type;
  final double value;
  final double threshold;
  final bool smsSent;

  const AlertEntry({
    required this.alertId,
    required this.timestamp,
    required this.type,
    required this.value,
    required this.threshold,
    required this.smsSent,
  });

  factory AlertEntry.fromMap(
    Map<String, dynamic> map, {
    required int timestamp,
    required String alertId,
  }) {
    return AlertEntry(
      alertId: alertId,
      timestamp: timestamp,
      type: _toString(map['type'] ?? map['alert_type'], 'unknown'),
      value: _toDouble(map['value']),
      threshold: _toDouble(map['threshold']),
      smsSent: _toBool(map['sms_sent']),
    );
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static String _toString(dynamic value, String defaultValue) {
    if (value == null) return defaultValue;
    if (value is String) return value;
    return value.toString();
  }

  static bool _toBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value != 0;
    if (value is String) {
      final normalized = value.toLowerCase().trim();
      return normalized == 'true' || normalized == '1' || normalized == 'yes';
    }
    return false;
  }
}