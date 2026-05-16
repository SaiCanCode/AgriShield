class SensorReading {
  final double temp;
  final double humidity;
  final double soil;
  final String alertType;
  final bool smsSent;
  final int timestamp;

  SensorReading({
    required this.temp,
    required this.humidity,
    required this.soil,
    this.alertType = 'none',
    required this.smsSent,
    required this.timestamp,
  });

  factory SensorReading.fromMap(Map<String, dynamic> map, {required int timestamp}) {
    return SensorReading(
      temp: _toDouble(map['temp']),
      humidity: _toDouble(map['humidity']),
      soil: _toDouble(map['soil']),
      alertType: map['alert_type']?.toString() ?? 'none',
      smsSent: _toBool(map['sms_sent']),
      timestamp: timestamp,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'temp': temp,
      'humidity': humidity,
      'soil': soil,
      'alert_type': alertType,
      'sms_sent': smsSent,
      'ts': timestamp,
    };
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
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
