import 'package:agrishield2/auth/login_controller.dart';
import 'package:agrishield2/core/responsive_nav.dart';
import 'package:agrishield2/core/routes.dart';
import 'package:agrishield2/core/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'settings_state.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routes = [ '/dashboard', '/alerts','/node-status', '/history','/settings',
    ];
    final settings = ref.watch(settingsControllerProvider);
    final phoneNumber =
        ref.watch(authServiceProvider).currentUser?.phoneNumber ??
        'Not available';
    final nodeSummary = ref.watch(settingsNodeSummaryProvider);
    final firebaseConnected = ref.watch(firebaseConnectionProvider);
    final nodeSubtitle = nodeSummary.maybeWhen(
      data: (summary) {
        if (summary == null) return null;
        return summary.nodeCount > 1
            ? 'Combined summary for ${summary.nodeCount} nodes'
            : 'Primary node summary';
      },
      orElse: () => null,
    );

    return NavBar(
      currentIndex: 4,
      onTap: (int index) {
        Navigator.pushReplacementNamed(context, routes[index]);
      },
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 18),
              _SettingsGroup(
                title: 'Account',
                children: [
                  _SettingsRow(
                    label: 'Phone number',
                    value: phoneNumber,
                    onTap: phoneNumber == 'Not available'
                        ? null
                        : () async {
                            await Clipboard.setData(
                              ClipboardData(text: phoneNumber),
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Phone number copied'),
                                ),
                              );
                            }
                          },
                  ),
                  _SettingsRow(
                    label: 'SMS language',
                    value: settings.smsLanguage.label,
                    onTap: () =>
                        _showLanguagePicker(context, ref, settings.smsLanguage),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Divider(height: 1, thickness: 0.5),
              const SizedBox(height: 18),
              _SettingsGroup(
                title: 'Notifications',
                children: [
                  _SettingsSwitchRow(
                    label: 'SMS alerts',
                    value: settings.smsAlertsEnabled,
                    onChanged: (value) => ref
                        .read(settingsControllerProvider.notifier)
                        .setSmsAlertsEnabled(value),
                  ),
                  _SettingsSwitchRow(
                    label: 'Push notifications',
                    value: settings.pushNotificationsEnabled,
                    onChanged: (value) => ref
                        .read(settingsControllerProvider.notifier)
                        .setPushNotificationsEnabled(value),
                  ),
                  _SettingsRow(
                    label: 'Alert cooldown',
                    value: '${settings.alertCooldownHours}h',
                    onTap: () => _showCooldownPicker(
                      context,
                      ref,
                      settings.alertCooldownHours,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Divider(height: 1, thickness: 0.5),
              const SizedBox(height: 18),
              _SettingsGroup(
                title: 'Node',
                subtitle: nodeSubtitle,
                children: [
                  // ── Firmware version ─────────────────────────────────────
                  _SettingsAsyncRow(
                    label: 'Firmware version',
                    valueBuilder: () => nodeSummary.when(
                      data: (summary) => Text(
                        summary?.firmwareVersion ?? 'Unknown',
                      ),
                      loading: () => const Text('Loading…'),
                      error: (_, __) => const Text('Unavailable'),
                    ),
                  ),
                  // ── Firebase status ───────────────────────────────────────
                  _SettingsAsyncRow(
                    label: 'Firebase status',
                    valueBuilder: () => firebaseConnected.when(
                      data: (connected) => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: connected
                                  ? const Color(0xFF2ECC71)
                                  : AgriColors.danger,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(connected ? 'Connected' : 'Offline'),
                        ],
                      ),
                      loading: () => const Text('Checking…'),
                      error: (_, __) => const Text('Unavailable'),
                    ),
                  ),
                  // ── Deployment ────────────────────────────────────────────
                  _SettingsAsyncRow(
                    label: 'Deployment',
                    valueBuilder: () => nodeSummary.when(
                      data: (summary) => Text(
                        summary?.deploymentSummary ?? 'Unknown',
                      ),
                      loading: () => const Text('Loading…'),
                      error: (_, __) => const Text('Unavailable'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Divider(height: 1, thickness: 0.5),
              const SizedBox(height: 8),
              _SettingsRow(
                label: 'Sign out',
                value: '',
                labelColor: AgriColors.danger,
                valueColor: AgriColors.danger,
                onTap: () async {
                  await ref.read(loginControllerProvider.notifier).signOut();
                  if (context.mounted) {
                    Navigator.of(context).pushReplacementNamed(Routes.login);
                  }
                },
                trailing: const Icon(
                  Icons.logout_rounded,
                  color: AgriColors.danger,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showLanguagePicker(
    BuildContext context,
    WidgetRef ref,
    SmsLanguage selected,
  ) async {
    final choice = await showModalBottomSheet<SmsLanguage>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final language in SmsLanguage.values)
                ListTile(
                  title: Text(language.label),
                  trailing: language == selected
                      ? const Icon(Icons.check_rounded)
                      : null,
                  onTap: () => Navigator.of(sheetContext).pop(language),
                ),
            ],
          ),
        );
      },
    );

    if (choice != null) {
      await ref
          .read(settingsControllerProvider.notifier)
          .setSmsLanguage(choice);
    }
  }

  Future<void> _showCooldownPicker(
    BuildContext context,
    WidgetRef ref,
    int selected,
  ) async {
    const options = [1, 2, 4, 6, 8, 12, 24];
    final choice = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final hours in options)
                ListTile(
                  title: Text('$hours h'),
                  trailing: hours == selected
                      ? const Icon(Icons.check_rounded)
                      : null,
                  onTap: () => Navigator.of(sheetContext).pop(hours),
                ),
            ],
          ),
        );
      },
    );

    if (choice != null) {
      await ref
          .read(settingsControllerProvider.notifier)
          .setAlertCooldownHours(choice);
    }
  }
}

// ─── _SettingsGroup ───────────────────────────────────────────────────────────

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({
    required this.title,
    required this.children,
    this.subtitle,
  });

  final String title;
  final List<Widget> children;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i != children.length - 1) {
        rows.add(const Divider(height: 1, thickness: 0.5));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        ...rows,
      ],
    );
  }
}

// ─── _SettingsRow ─────────────────────────────────────────────────────────────

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.label,
    required this.value,
    this.onTap,
    this.labelColor,
    this.valueColor,
    this.trailing,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;
  final Color? labelColor;
  final Color? valueColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w600,
      color: labelColor,
    );
    final valueStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: valueColor ?? Theme.of(context).colorScheme.onSurfaceVariant,
    );

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 14),
        child: Row(
          children: [
            Expanded(child: Text(label, style: labelStyle)),
            const SizedBox(width: 16),
            if (trailing != null) trailing! else Text(value, style: valueStyle),
          ],
        ),
      ),
    );
  }
}

// ─── _SettingsAsyncRow ────────────────────────────────────────────────────────

class _SettingsAsyncRow extends StatelessWidget {
  const _SettingsAsyncRow({
    required this.label,
    required this.valueBuilder,
  });

  final String label;
  final Widget Function() valueBuilder; // must always return Widget

  @override
  Widget build(BuildContext context) {
    return _SettingsRow(
      label: label,
      value: '',
      trailing: valueBuilder(),
    );
  }
}

// ─── _SettingsSwitchRow ───────────────────────────────────────────────────────

class _SettingsSwitchRow extends StatelessWidget {
  const _SettingsSwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return _SettingsRow(
      label: label,
      value: '',
      trailing: Switch.adaptive(value: value, onChanged: onChanged),
      onTap: () => onChanged(!value),
    );
  }
}