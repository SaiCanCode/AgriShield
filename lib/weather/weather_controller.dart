import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../services/weather_service.dart';
import 'weather_model.dart';
import '../config/weather_config.dart';

final weatherServiceProvider = Provider<WeatherService>((ref) {
  return WeatherService(
    apiKey: weatherApiKey,
    latitude: weatherLatitude,
    longitude: weatherLongitude,
  );
});

final weatherProvider = FutureProvider<WeatherData>((ref) async {
  final service = ref.watch(weatherServiceProvider);
  return service.getWeatherWithForecast();
});

final weatherControllerProvider =
    StateNotifierProvider<WeatherController, AsyncValue<WeatherData>>((ref) {
  final service = ref.watch(weatherServiceProvider);
  return WeatherController(service);
});

class WeatherController extends StateNotifier<AsyncValue<WeatherData>> {
  final WeatherService _service;

  WeatherController(this._service) : super(const AsyncValue.loading()) {
    _loadWeather();
  }

  Future<void> _loadWeather() async {
    state = const AsyncValue.loading();
    try {
      final data = await _service.getWeatherWithForecast();
      state = AsyncValue.data(data);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() => _loadWeather();

  Future<void> refreshWithLocation(double latitude, double longitude) async {
    state = const AsyncValue.loading();
    try {
      final data = await _service.getWeatherWithForecast(
        overrideLatitude: latitude,
        overrideLongitude: longitude,
      );
      state = AsyncValue.data(data);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
