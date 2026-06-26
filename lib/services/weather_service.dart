import 'package:dio/dio.dart';
import '../weather/weather_model.dart';

class WeatherService {
  final Dio _dio;
  final String apiKey;
  final double latitude;
  final double longitude;

  WeatherService({
    required this.apiKey,
    required this.latitude,
    required this.longitude,
    Dio? dio,
  }) : _dio = dio ?? Dio();

  Future<WeatherData> getCurrentWeather() async {
    final response = await _dio.get(
      'https://api.tomorrow.io/v4/weather/realtime',
      queryParameters: _baseQueryParameters(latitude, longitude),
    );

    if (response.statusCode == 200) {
      return WeatherData.fromCurrentJson(response.data as Map<String, dynamic>);
    }
    throw Exception('Failed to fetch weather: ${response.statusCode}');
  }

  Future<WeatherData> getWeatherWithForecast({
    double? overrideLatitude,
    double? overrideLongitude,
  }) async {
    try {
      final lat = overrideLatitude ?? latitude;
      final lon = overrideLongitude ?? longitude;

      final responses = await Future.wait([
        _dio.get(
          'https://api.tomorrow.io/v4/weather/realtime',
          queryParameters: _baseQueryParameters(lat, lon),
        ),
        _dio.get(
          'https://api.tomorrow.io/v4/timelines',
          queryParameters: {
            ..._baseQueryParameters(lat, lon),
            'timesteps': '1h',
            'fields': 'temperature,weatherCode',
            'startTime': 'now',
            'endTime': 'nowPlus2h',
          },
        ),
      ]);

      final currentResponse = responses[0];
      final forecastResponse = responses[1];

      if (currentResponse.statusCode != 200) {
        throw Exception('Failed to fetch current weather: ${currentResponse.statusCode}');
      }

      if (forecastResponse.statusCode != 200) {
        throw Exception('Failed to fetch forecast: ${forecastResponse.statusCode}');
      }

      return WeatherData.fromResponses(
        currentJson: currentResponse.data as Map<String, dynamic>,
        forecastJson: forecastResponse.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      final message = e.response?.data?.toString() ?? e.message ?? 'unknown error';
      throw Exception('Weather API error: $message');
    }
  }

  Map<String, dynamic> _baseQueryParameters(double lat, double lon) {
    return {
      'location': '$lat,$lon',
      'apikey': apiKey,
      'units': 'metric',
    };
  }
}
