import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/weather_service.dart';
import '../services/push_notification_service.dart';
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
  static const String _weatherCacheKey = 'weather_cache_data_v1';
  static const String _weatherCacheFetchedAtKey = 'weather_cache_fetched_at_v1';
  static const Duration _weatherCacheTtl = Duration(minutes: 20);

  final WeatherService _service;
  WeatherData? _lastWeather;
  bool _isFetching = false;
  DateTime? _lastFetchedAt;
  SharedPreferences? _prefs;
  late final Future<void> _cacheRestoreFuture;

  WeatherController(this._service) : super(const AsyncValue.loading()) {
    _cacheRestoreFuture = _restoreCachedWeather();
  }

  Future<void> ensureLoaded() async {
    await _cacheRestoreFuture;

    if (_isFetching) {
      return;
    }

    if (_isCacheFresh()) {
      return;
    }

    await _loadWeather(showLoadingState: !state.hasValue);
  }

  Future<void> _loadWeather({
    bool showLoadingState = true,
    double? overrideLatitude,
    double? overrideLongitude,
  }) async {
    if (_isFetching) return;
    _isFetching = true;

    if (showLoadingState) {
      state = const AsyncValue.loading();
    }

    try {
      final data = await _service.getWeatherWithForecast(
        overrideLatitude: overrideLatitude,
        overrideLongitude: overrideLongitude,
      );
      final fetchedAt = DateTime.now().toUtc();
      final timestamped = data.copyWith(updatedAtUtc: fetchedAt);
      state = AsyncValue.data(timestamped);
      unawaited(_maybeNotifyRainChange(timestamped));
      _lastWeather = timestamped;
      _lastFetchedAt = fetchedAt;
      unawaited(_persistCachedWeather(timestamped, fetchedAt));
    } catch (e, st) {
      if (_lastWeather != null) {
        // Preserve stale data on transient failures instead of blanking the UI.
        state = AsyncValue.data(_lastWeather!);
        debugPrint('Weather refresh failed; showing cached weather: $e');
      } else {
        state = AsyncValue.error(e, st);
      }
    } finally {
      _isFetching = false;
    }
  }

  Future<void> refresh() => _loadWeather(showLoadingState: true);

  Future<void> refreshWithLocation(double latitude, double longitude) async {
    await _loadWeather(
      showLoadingState: true,
      overrideLatitude: latitude,
      overrideLongitude: longitude,
    );
  }

  Future<void> _restoreCachedWeather() async {
    try {
      final prefs = await _getPrefs();
      final cacheJson = prefs.getString(_weatherCacheKey);
      final fetchedAtMs = prefs.getInt(_weatherCacheFetchedAtKey);
      if (cacheJson == null || cacheJson.isEmpty || fetchedAtMs == null) {
        return;
      }

      final decoded = jsonDecode(cacheJson);
      if (decoded is! Map<String, dynamic>) {
        return;
      }

      final cached = WeatherData.fromMap(decoded);
      final fetchedAt = DateTime.fromMillisecondsSinceEpoch(
        fetchedAtMs,
        isUtc: true,
      );
      final timestamped = cached.copyWith(updatedAtUtc: fetchedAt);
      _lastWeather = timestamped;
      _lastFetchedAt = fetchedAt;
      state = AsyncValue.data(timestamped);
    } catch (e) {
      debugPrint('Failed to restore cached weather: $e');
      await _clearCachedWeather();
    }
  }

  Future<void> _persistCachedWeather(WeatherData data, DateTime fetchedAt) async {
    try {
      final prefs = await _getPrefs();
      await prefs.setString(_weatherCacheKey, jsonEncode(data.toMap()));
      await prefs.setInt(
        _weatherCacheFetchedAtKey,
        fetchedAt.millisecondsSinceEpoch,
      );
    } catch (e) {
      debugPrint('Failed to persist weather cache: $e');
    }
  }

  Future<void> _clearCachedWeather() async {
    final prefs = await _getPrefs();
    await prefs.remove(_weatherCacheKey);
    await prefs.remove(_weatherCacheFetchedAtKey);
  }

  Future<SharedPreferences> _getPrefs() async {
    final cached = _prefs;
    if (cached != null) return cached;
    final created = await SharedPreferences.getInstance();
    _prefs = created;
    return created;
  }

  bool _isCacheFresh() {
    final fetchedAt = _lastFetchedAt;
    if (_lastWeather == null || fetchedAt == null) return false;
    final age = DateTime.now().toUtc().difference(fetchedAt);
    return age <= _weatherCacheTtl;
  }

  Future<void> _maybeNotifyRainChange(WeatherData current) async {
    final previous = _lastWeather;
    if (previous == null) return;

    if (!_isRainy(previous) && _isRainy(current)) {
      await PushNotificationService.instance.showWeatherRainNotification(
        location: current.location,
        precipitationMm: current.precipitation,
        condition: current.condition,
        forecastCondition: current.nextHourForecast?.condition,
      );
    }
  }

  bool _isRainy(WeatherData weather) {
    final condition = weather.condition.toLowerCase();
    final forecastCondition = weather.nextHourForecast?.condition.toLowerCase() ?? '';
    return weather.precipitation > 0.1 ||
        condition.contains('rain') ||
        condition.contains('drizzle') ||
        condition.contains('thunder') ||
        forecastCondition.contains('rain') ||
        forecastCondition.contains('drizzle') ||
        forecastCondition.contains('thunder');
  }
}
