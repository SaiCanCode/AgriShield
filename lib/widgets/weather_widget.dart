import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/agri_text.dart';
import '../core/theme.dart';
import '../weather/weather_controller.dart';

class WeatherWidget extends ConsumerStatefulWidget {
  const WeatherWidget({super.key});

  @override
  ConsumerState<WeatherWidget> createState() => _WeatherWidgetState();
}

class _WeatherWidgetState extends ConsumerState<WeatherWidget> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(weatherControllerProvider.notifier).ensureLoaded();
    });
  }

  @override
  Widget build(BuildContext context) {
    final weatherAsync = ref.watch(weatherControllerProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return weatherAsync.when(
      data: (weather) => LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 360;
          final accent = _weatherAccent(weather.condition);

          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () => Navigator.pushNamed(context, '/weather'),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      cs.surface,
                      cs.surfaceContainerHighest,
                    ],
                  ),
                  border: Border.all(color: cs.outline),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: theme.brightness == Brightness.dark ? 0.24 : 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -28,
                      top: -28,
                      child: _GlowOrb(color: accent),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    AgriText.caption('Weather now', color: cs.onSurface.withValues(alpha: 0.75)),
                                    const SizedBox(height: 6),
                                    Text(
                                      weather.location,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: cs.onSurface,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.14),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: accent.withValues(alpha: 0.16)),
                                ),
                                child: Icon(
                                    _weatherIcon(weather.condition),
                                  color: accent,
                                  size: 30,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Flexible(
                                child: Text(
                                  '${weather.temperature.toStringAsFixed(0)}°',
                                  maxLines: 1,
                                  overflow: TextOverflow.fade,
                                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        height: 0.95,
                                        color: cs.onSurface,
                                      ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text(
                                  'C',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                        color: cs.onSurface.withValues(alpha: 0.7),
                                        fontWeight: FontWeight.w500,
                                      ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            weather.condition,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: cs.onSurface.withValues(alpha: 0.7),
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                          if (weather.updatedAtUtc != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              _updatedAgoLabel(weather.updatedAtUtc!),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.onSurface.withValues(alpha: 0.62),
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          LayoutBuilder(
                            builder: (context, metricConstraints) {
                              final metricWidth = isCompact ? metricConstraints.maxWidth : (metricConstraints.maxWidth - 12) / 2;
                              return Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  _Metrics(
                                    width: metricWidth,
                                    label: 'Humidity',
                                    value: '${weather.humidity.toStringAsFixed(0)}%',
                                    icon: Icons.water_drop_outlined,
                                  ),
                                  _Metrics(
                                    width: metricWidth,
                                    label: 'Wind',
                                    value: '${weather.windSpeed.toStringAsFixed(1)} km/h',
                                    icon: Icons.air,
                                  ),
                                  _Metrics(
                                    width: metricWidth,
                                    label: 'Precipitation',
                                    value: '${weather.precipitation.toStringAsFixed(1)} mm',
                                    icon: Icons.umbrella_outlined,
                                  ),
                                  _Metrics(
                                    width: metricWidth,
                                    label: 'Feels like',
                                    value: '${weather.feelsLike.toStringAsFixed(0)}°C',
                                    icon: Icons.thermostat_outlined,
                                  ),
                                ],
                              );
                            },
                          ),
                          if (weather.nextHourForecast != null) ...[
                            const SizedBox(height: 16),
                            _ForecastStrip(
                              forecastText: weather.nextHourForecast!.condition,
                              forecastTime: weather.nextHourForecast!.time,
                              forecastTemp: '${weather.nextHourForecast!.temperature.toStringAsFixed(0)}°C',
                              accent: accent,
                            ),
                          ],
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              'Tap for details',
                              style: theme.textTheme.bodySmall?.copyWith(
                                    color: cs.onSurface.withValues(alpha: 0.75),
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      loading: () => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: cs.surface,
          border: Border.all(color: cs.outline),
        ),
        child: const SizedBox(
          height: 170,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (error, st) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: cs.surface,
          border: Border.all(color: cs.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AgriText.caption('Weather', color: cs.onSurface.withValues(alpha: 0.75)),
            const SizedBox(height: 8),
            Text(
              'Weather unavailable',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '$error',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.75),
                  ),
            ),
          ],
        ),
      ),
    );
  }

}

String _updatedAgoLabel(DateTime updatedAtUtc) {
  final minutes = DateTime.now().toUtc().difference(updatedAtUtc).inMinutes;
  if (minutes <= 0) return 'Updated just now';
  if (minutes < 60) return 'Updated $minutes min ago';
  final hours = minutes ~/ 60;
  if (hours < 24) return 'Updated $hours h ago';
  final days = hours ~/ 24;
  return 'Updated $days d ago';
}

IconData _weatherIcon(String condition) {
  final cond = condition.toLowerCase();
  if (cond.contains('sunny') || cond.contains('clear')) return Icons.wb_sunny;
  if (cond.contains('cloudy')) return Icons.wb_cloudy;
  if (cond.contains('rain') || cond.contains('drizzle')) return Icons.grain;
  if (cond.contains('wind')) return Icons.air;
  if (cond.contains('storm') || cond.contains('thunder')) return Icons.thunderstorm;
  if (cond.contains('fog')) return Icons.foggy;
  return Icons.cloud;
}

Color _weatherAccent(String condition) {
  final cond = condition.toLowerCase();
  if (cond.contains('sunny') || cond.contains('clear')) return AgriColors.secondary;
  if (cond.contains('cloudy')) return AgriColors.textSecondary;
  if (cond.contains('rain') || cond.contains('drizzle')) return AgriColors.info;
  if (cond.contains('wind')) return AgriColors.primary;
  if (cond.contains('storm') || cond.contains('thunder')) return AgriColors.danger;
  if (cond.contains('fog')) return AgriColors.textHint;
  return AgriColors.primary;
}

class _Metrics extends StatelessWidget {
  const _Metrics({
    required this.width,
    required this.label,
    required this.value,
    required this.icon,
  });

  final double width;
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ForecastStrip extends StatelessWidget {
  const _ForecastStrip({
    required this.forecastText,
    required this.forecastTime,
    required this.forecastTemp,
    required this.accent,
  });

  final String forecastText;
  final String forecastTime;
  final String forecastTemp;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.14),
            Theme.of(context).colorScheme.surfaceContainerHighest,
          ],
        ),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(_weatherIcon(forecastText), color: accent, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Next hour',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75)),
                ),
                const SizedBox(height: 2),
                Text(
                  '$forecastText · $forecastTime',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            forecastTemp,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: 0.18),
            color.withValues(alpha: 0.05),
            Colors.transparent,
          ],
          stops: const [0.0, 0.55, 1.0],
        ),
      ),
    );
  }
}
