import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'alert_entry.dart';
import 'alert_guidance.dart';

Future<void> showAlertDetailSheet(BuildContext context, AlertEntry alert) {
  return showModalBottomSheet<void>(
    context: context,
    barrierLabel: 'Dismiss alert details',
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: false,
    useSafeArea: false,
    backgroundColor: Colors.transparent,
    transitionAnimationController: null,
    builder: (sheetContext) {
      final height = MediaQuery.sizeOf(sheetContext).height * 0.80;
      return SizedBox(
        height: height,
        width: double.infinity,
        child: _AlertDetailSheet(alert: alert),
      );
    },
  );
}

class _AlertDetailSheet extends StatelessWidget {
  const _AlertDetailSheet({
    required this.alert,
  });

  final AlertEntry alert;

  @override
  Widget build(BuildContext context) {
    final guidance = guidanceForAlertEntry(alert);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: guidance.accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.warning_amber_rounded, color: guidance.accentColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            guidance.title,
                            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Triggered at ${_formatTimestamp(alert.timestamp)}',
                            style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                        tooltip: 'Close',
                        iconSize: 26,
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _InfoBlock(
                  label: 'Alert Type',
                  value: alert.type.toUpperCase(),
                  accentColor: guidance.accentColor,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _Pill(label: 'Value', value: alert.value.toStringAsFixed(2)),
                    _Pill(label: 'Threshold', value: alert.threshold.toStringAsFixed(2)),
                    _Pill(label: 'SMS', value: alert.smsSent ? 'Sent' : 'Not sent'),
                  ],
                ),
                const SizedBox(height: 20),
                _SectionTitle('Recommended solution'),
                const SizedBox(height: 8),
                Text(
                  guidance.solution,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                _SectionTitle('Why this is the best response'),
                const SizedBox(height: 8),
                Text(
                  guidance.rationale,
                  style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant, height: 1.5),
                ),
                if (alert.action.isNotEmpty || alert.message.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _SectionTitle('Alert details'),
                  const SizedBox(height: 8),
                  if (alert.action.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('Action: ${alert.action}'),
                    ),
                  if (alert.message.isNotEmpty)
                    Text(
                      alert.message,
                      style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({
    required this.label,
    required this.value,
    required this.accentColor,
  });

  final String label;
  final String value;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accentColor.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelLarge?.copyWith(color: accentColor)),
          const SizedBox(height: 4),
          Text(value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: theme.textTheme.labelLarge,
      ),
    );
  }
}

String _formatTimestamp(dynamic ts) {
  try {
    if (ts == null) return '';
    final raw = ts is String ? int.tryParse(ts) ?? 0 : (ts is num ? ts.toInt() : 0);
    if (raw <= 0) return ts.toString();

    // Normalize to milliseconds
    int ms = raw;
    if (raw < 10000000000) {
      // probably seconds
      ms = raw * 1000;
    }

    final dt = DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
    final date = DateFormat.yMMMd().format(dt);
    final time = DateFormat.jm().format(dt);
    return '$date $time';
  } catch (_) {
    return ts.toString();
  }
}