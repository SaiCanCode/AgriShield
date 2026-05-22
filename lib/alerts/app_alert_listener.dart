import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'alert_entry.dart';
import '../providers/readings_provider.dart';
import '../services/push_notification_service.dart';

class AppAlertListener extends ConsumerStatefulWidget {
  const AppAlertListener({
    super.key,
    required this.child,
    this.nodeId = 'node_001',
  });

  final Widget child;
  final String nodeId;

  @override
  ConsumerState<AppAlertListener> createState() => _AppAlertListenerState();
}

class _AppAlertListenerState extends ConsumerState<AppAlertListener> {
  final Set<String> _seenAlertIds = <String>{};
  bool _isPrimed = false;

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<List<AlertEntry>>>(
      recentAlertsProvider(widget.nodeId),
      (previous, next) {
        final alerts = next.asData?.value;
        if (alerts == null) return;

        if (!_isPrimed) {
          for (final alert in alerts) {
            _seenAlertIds.add(alert.alertId);
          }
          _isPrimed = true;
          return;
        }

        for (final alert in alerts) {
          if (_seenAlertIds.add(alert.alertId)) {
            PushNotificationService.instance.showAlertNotification(alert);
          }
        }
      },
    );

    return widget.child;
  }
}
