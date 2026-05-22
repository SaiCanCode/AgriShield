import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../core/agri_text.dart';
import '../core/responsive_nav.dart';
import '../core/theme.dart';
import 'weather_controller.dart';
import 'weather_model.dart';

class WeatherScreen extends ConsumerWidget {
  const WeatherScreen({super.key});

  Future<void> _useCurrentLocation(BuildContext context, WidgetRef ref) async {
    final locationEnabled = await Geolocator.isLocationServiceEnabled();
    if (!locationEnabled) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are turned off')),
        );
      }
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied')),
        );
      }
      return;
    }

    final position = await Geolocator.getCurrentPosition();
    await ref
        .read(weatherControllerProvider.notifier)
        .refreshWithLocation(position.latitude, position.longitude);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routes = ['/dashboard', '/alerts', '/node-status', '/history', '/settings'];
    final weatherAsync = ref.watch(weatherControllerProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return NavBar(
      currentIndex: 0,
      onTap: (int index) {
        Navigator.pushReplacementNamed(context, routes[index]);
      },
      child: SafeArea(
        child: weatherAsync.when(
          data: (weather) => LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 760;
              final horizontalPadding = constraints.maxWidth >= 1100 ? 32.0 : 16.0;

              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(horizontalPadding, 16, horizontalPadding, 96),
                child: isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: _CurrentWeatherPanel(
                              weather: weather,
                              onRefresh: () => ref.refresh(weatherControllerProvider),
                              onUseLocation: () => _useCurrentLocation(context, ref),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: _ForecastPanel(weather: weather),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _CurrentWeatherPanel(
                            weather: weather,
                            onRefresh: () => ref.refresh(weatherControllerProvider),
                            onUseLocation: () => _useCurrentLocation(context, ref),
                          ),
                          const SizedBox(height: 16),
                          _ForecastPanel(weather: weather),
                        ],
                      ),
              );
            },
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, st) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_off_outlined, size: 40, color: cs.onSurface.withValues(alpha: 0.7)),
                      const SizedBox(height: 12),
                      AgriText.h3('Weather unavailable'),
                      const SizedBox(height: 8),
                      Text(
                        '$error',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.7),
                            ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: 180,
                        child: ElevatedButton(
                          onPressed: () => ref.refresh(weatherControllerProvider),
                          child: const Text('Retry'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CurrentWeatherPanel extends StatelessWidget {
  const _CurrentWeatherPanel({
    required this.weather,
    required this.onRefresh,
    required this.onUseLocation,
  });

  final WeatherData weather;
  final VoidCallback onRefresh;
  final VoidCallback onUseLocation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final icon = _weatherIcon(weather.condition);
    final accent = _weatherAccent(weather.condition);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AgriText.label('Weather', color: cs.onSurface.withValues(alpha: 0.8)),
                      const SizedBox(height: 4),
                      Text(
                        weather.location,
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: accent.withValues(alpha: 0.2)),
                  ),
                  child: Icon(icon, color: accent, size: 32),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    '${weather.temperature.toStringAsFixed(1)}°',
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    'C',
                    style: theme.textTheme.titleLarge?.copyWith(color: cs.onSurface.withValues(alpha: 0.7)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              weather.condition,
              style: theme.textTheme.titleMedium?.copyWith(color: cs.onSurface.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 10),
            Text(
              'Feels like ${weather.feelsLike.toStringAsFixed(1)}°C',
              style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurface.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 420;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _WeatherMetricTile(label: 'Humidity', value: '${weather.humidity.toStringAsFixed(0)}%', compact: compact),
                    _WeatherMetricTile(label: 'Wind', value: '${weather.windSpeed.toStringAsFixed(1)} km/h', compact: compact),
                    _WeatherMetricTile(label: 'Precipitation', value: '${weather.precipitation.toStringAsFixed(1)} mm', compact: compact),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onUseLocation,
                icon: const Icon(Icons.my_location),
                label: const Text('Use my location'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ForecastPanel extends StatelessWidget {
  const _ForecastPanel({required this.weather});

  final WeatherData weather;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AgriText.label('1 hour prediction'),
            const SizedBox(height: 6),
            Text(
              'What weather may look like in the next hour',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            if (weather.nextHourForecast != null)
              _ForecastCard(forecast: weather.nextHourForecast!)
            else
              const _EmptyForecastCard(),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            AgriText.label('Quick summary'),
            const SizedBox(height: 10),
            _SummaryRow(label: 'Current state', value: weather.condition),
            _SummaryRow(label: 'Temperature', value: '${weather.temperature.toStringAsFixed(1)}°C'),
            _SummaryRow(label: 'Humidity', value: '${weather.humidity.toStringAsFixed(0)}%'),
            _SummaryRow(label: 'Precipitation', value: '${weather.precipitation.toStringAsFixed(1)} mm'),
            _SummaryRow(label: 'Wind', value: '${weather.windSpeed.toStringAsFixed(1)} km/h'),
          ],
        ),
      ),
    );
  }
}

class _ForecastCard extends StatelessWidget {
  const _ForecastCard({required this.forecast});

  final HourlyForecast forecast;

  @override
  Widget build(BuildContext context) {
    final accent = _weatherAccent(forecast.condition);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(_weatherIcon(forecast.condition), color: accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  forecast.condition,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  forecast.time,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${forecast.temperature.toStringAsFixed(1)}°C',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _EmptyForecastCard extends StatelessWidget {
  const _EmptyForecastCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Row(
        children: [
          Icon(Icons.schedule_outlined, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'No hourly forecast available yet.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeatherMetricTile extends StatelessWidget {
  const _WeatherMetricTile({required this.label, required this.value, required this.compact});

  final String label;
  final String value;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: compact ? double.infinity : 150,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AgriColors.textSecondary),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

IconData _weatherIcon(String condition) {
  final value = condition.toLowerCase();
  if (value.contains('sun') || value.contains('clear')) return Icons.wb_sunny_outlined;
  if (value.contains('cloud')) return Icons.cloud_outlined;
  if (value.contains('rain') || value.contains('drizzle')) return Icons.umbrella_outlined;
  if (value.contains('storm') || value.contains('thunder')) return Icons.thunderstorm_outlined;
  if (value.contains('fog')) return Icons.cloud_queue_outlined;
  if (value.contains('wind')) return Icons.air;
  return Icons.wb_cloudy_outlined;
}

Color _weatherAccent(String condition) {
  final value = condition.toLowerCase();
  if (value.contains('sun') || value.contains('clear')) return AgriColors.secondary;
  if (value.contains('rain') || value.contains('drizzle')) return AgriColors.info;
  if (value.contains('storm') || value.contains('thunder')) return AgriColors.danger;
  if (value.contains('cloud') || value.contains('fog')) return AgriColors.textSecondary;
  return AgriColors.primary;
}
