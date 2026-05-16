class WeatherData {
  final String location;
  final double temperature;
  final String condition;
  final double humidity;
  final double precipitation;
  final double windSpeed;
  final double feelsLike;
  final HourlyForecast? nextHourForecast;

  WeatherData({
    required this.location,
    required this.temperature,
    required this.condition,
    required this.humidity,
    required this.precipitation,
    required this.windSpeed,
    required this.feelsLike,
    this.nextHourForecast,
  });

  factory WeatherData.fromCurrentJson(Map<String, dynamic> json) {
    final currentData = (json['data'] as Map<String, dynamic>)['values'] as Map<String, dynamic>;
    final locationMap = json['location'] as Map<String, dynamic>?;
    final locationName = locationMap?['name']?.toString();
    final lat = locationMap?['lat'];
    final lon = locationMap?['lon'];
    final location = locationName?.isNotEmpty == true
        ? locationName!
        : (lat != null && lon != null ? '$lat, $lon' : 'Unknown Location');

    final temp = (currentData['temperature'] as num?)?.toDouble() ?? 0.0;
    final humidity = (currentData['humidity'] as num?)?.toDouble() ?? 0.0;
    final precip = (currentData['precipitationIntensity'] as num?)?.toDouble() ?? 0.0;
    final windSpeed = (currentData['windSpeed'] as num?)?.toDouble() ?? 0.0;
    final feelsLike = (currentData['temperatureApparent'] as num?)?.toDouble() ?? temp;
    final weatherCode = currentData['weatherCode'] as int? ?? 0;
    final condition = _mapWeatherCode(weatherCode);

    HourlyForecast? nextHour;
    final timelines = json['timelines'] as List?;
    if (timelines != null && timelines.isNotEmpty) {
      final hourlyData = timelines.firstWhere(
        (t) => t['timestep'] == 'hourly',
        orElse: () => null,
      ) as Map<String, dynamic>?;
      if (hourlyData != null && hourlyData['intervals'] != null) {
        final intervals = hourlyData['intervals'] as List;
        if (intervals.isNotEmpty) {
          nextHour = HourlyForecast.fromJson(intervals[0]);
        }
      }
    }

    return WeatherData(
      location: location,
      temperature: temp,
      condition: condition,
      humidity: humidity,
      precipitation: precip,
      windSpeed: windSpeed,
      feelsLike: feelsLike,
      nextHourForecast: nextHour,
    );
  }

  factory WeatherData.fromResponses({
    required Map<String, dynamic> currentJson,
    required Map<String, dynamic> forecastJson,
  }) {
    final current = WeatherData.fromCurrentJson(currentJson);
    final nextHour = HourlyForecast.fromTimelinesJson(forecastJson);

    return WeatherData(
      location: current.location,
      temperature: current.temperature,
      condition: current.condition,
      humidity: current.humidity,
      precipitation: current.precipitation,
      windSpeed: current.windSpeed,
      feelsLike: current.feelsLike,
      nextHourForecast: nextHour,
    );
  }

  static String _mapWeatherCode(int code) {
    switch (code) {
      case 0: return 'Clear';
      case 1000: return 'Sunny';
      case 1001: return 'Cloudy';
      case 1002: return 'Mostly Cloudy';
      case 1003: return 'Partly Cloudy';
      case 2000: return 'Fog';
      case 2100: return 'Light Fog';
      case 3000: return 'Light Wind';
      case 3001: return 'Wind';
      case 3002: return 'Strong Wind';
      case 4000: return 'Drizzle';
      case 4001: return 'Rain';
      case 4200: return 'Light Rain';
      case 4201: return 'Heavy Rain';
      case 8000: return 'Thunderstorm';
      case 8001: return 'Thunderstorm with Rain';
      default: return 'Unknown';
    }
  }
}

class HourlyForecast {
  final String time;
  final String condition;
  final double temperature;

  HourlyForecast({
    required this.time,
    required this.condition,
    required this.temperature,
  });

  factory HourlyForecast.fromJson(Map<String, dynamic> json) {
    final values = json['values'] as Map<String, dynamic>;
    final weatherCode = values['weatherCode'] as int? ?? 0;
    final condition = WeatherData._mapWeatherCode(weatherCode);
    final temp = (values['temperature'] as num?)?.toDouble() ?? 0.0;
    final time = json['startTime'] as String? ?? '';

    return HourlyForecast(
      time: time,
      condition: condition,
      temperature: temp,
    );
  }

  factory HourlyForecast.fromTimelinesJson(Map<String, dynamic> json) {
    final timelines = json['data'] as Map<String, dynamic>?;
    if (timelines == null) {
      return HourlyForecast(time: '', condition: 'Unknown', temperature: 0.0);
    }

    final hourlyTimelines = timelines['timelines'] as List<dynamic>?;
    if (hourlyTimelines == null || hourlyTimelines.isEmpty) {
      return HourlyForecast(time: '', condition: 'Unknown', temperature: 0.0);
    }

    final hourly = hourlyTimelines.firstWhere(
      (item) => item is Map<String, dynamic> && item['timestep'] == '1h',
      orElse: () => null,
    );

    if (hourly is! Map<String, dynamic>) {
      return HourlyForecast(time: '', condition: 'Unknown', temperature: 0.0);
    }

    final intervals = hourly['intervals'] as List<dynamic>?;
    if (intervals == null || intervals.isEmpty) {
      return HourlyForecast(time: '', condition: 'Unknown', temperature: 0.0);
    }

    final firstInterval = intervals.first as Map<String, dynamic>;
    final values = firstInterval['values'] as Map<String, dynamic>;
    final weatherCode = values['weatherCode'] as int? ?? 0;
    final condition = WeatherData._mapWeatherCode(weatherCode);
    final temp = (values['temperature'] as num?)?.toDouble() ?? 0.0;
    final time = firstInterval['startTime'] as String? ?? '';

    return HourlyForecast(
      time: time,
      condition: condition,
      temperature: temp,
    );
  }
}
