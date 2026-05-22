class AlertEntry {
  final String alertId;
  final int timestamp;
  final String type;
  // Primary numeric value for display (kept for compatibility)
  final double value;
  final double threshold;
  final bool smsSent;

  // New structured fields
  final double triggerValue;
  final int severity;
  final String message;
  final String action;
  final String source;

  const AlertEntry({
    required this.alertId,
    required this.timestamp,
    required this.type,
    required this.value,
    required this.threshold,
    required this.smsSent,
    required this.triggerValue,
    required this.severity,
    required this.message,
    required this.action,
    required this.source,
  });

  factory AlertEntry.fromMap(
    Map<String, dynamic> map, {
    required int timestamp,
    required String alertId,
  }) {
    final trigger = _firstNonNull(map['trigger_value'], map['triggerValue'], map['value'], map['threshold']);
    final double triggerVal = _toDouble(trigger);

    final double thresh = _toDouble(map['threshold']);
    final bool sms = _toBool(_firstNonNull(map['sms_sent'], map['smsSent']));

    return AlertEntry(
      alertId: alertId,
      timestamp: timestamp,
      type: _toString(_firstNonNull(map['type'], map['alert_type']), 'unknown'),
      value: triggerVal,
      threshold: thresh,
      smsSent: sms,
      triggerValue: triggerVal,
      severity: _toInt(map['severity']),
      message: _toString(_firstNonNull(map['message'], map['msg']), ''),
      action: _toString(map['action'], ''),
      source: _toString(map['source'], 'server'),
    );
  }

  static dynamic _firstNonNull(dynamic a, dynamic b, [dynamic c, dynamic d]) {
    if (a != null) return a;
    if (b != null) return b;
    if (c != null) return c;
    if (d != null) return d;
    return null;
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
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