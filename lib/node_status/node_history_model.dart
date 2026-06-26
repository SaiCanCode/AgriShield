class NodeHistoryPoint {
  final int timestamp;      
  final double temp;        
  final double humidity;    
  final double soil;        
  final String alertType;   
  const NodeHistoryPoint({
    required this.timestamp,
    required this.temp,
    required this.humidity,
    required this.soil,
    required this.alertType,
  });

  factory NodeHistoryPoint.fromMap(Map<String, dynamic> map, int timestamp) {
    return NodeHistoryPoint(
      timestamp: timestamp,
      temp:      _d(map['temp']),
      humidity:  _d(map['humidity']),
      soil:      _d(map['soil']),
      alertType: (map['alert_type'] ?? 'none').toString(),
    );
  }

  static double _d(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }
}

enum TimeRange {
  h6(label: '6h',  points: 24),
  h24(label: '24h', points: 96),
  d7(label: '7d',  points: 672);

  const TimeRange({required this.label, required this.points});
  final String label;
  final int points; // how many readings to fetch (15-min intervals)
}
