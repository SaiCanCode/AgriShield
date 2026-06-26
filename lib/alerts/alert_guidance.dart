import 'package:flutter/material.dart';

import 'alert_entry.dart';
import '../core/theme.dart';
import 'alert_rules_loader.dart';

class AlertGuidance {
  const AlertGuidance({
    required this.title,
    required this.solution,
    required this.rationale,
    required this.accentColor,
  });

  final String title;
  final String solution;
  final String rationale;
  final Color accentColor;
}

AlertGuidance guidanceForAlertType(String type) {
  // Prefer JSON-driven guidance when loaded
  try {
    final repo = AlertRulesRepository.instance;
    final guidance = repo.guidanceForType(type);
    if (guidance != null) return guidance;
  } catch (_) {
    // ignore and fall back to built-in mapping
  }

  // Built-in fallback mapping (keeps previous behavior)
  switch (type.trim().toLowerCase()) {
    case 'drought':
      return const AlertGuidance(
        title: 'Drought Alert',
        solution: 'Increase irrigation immediately and verify soil moisture coverage across the zone.',
        rationale: 'Raising moisture now restores crop stress quickly and prevents yield loss before the root zone dries further.',
        accentColor: AgriColors.drought,
      );
    case 'flood':
      return const AlertGuidance(
        title: 'Flood Alert',
        solution: 'Pause irrigation, improve drainage, and clear runoff paths around the affected area.',
        rationale: 'Reducing standing water and moving excess moisture away lowers root damage and disease pressure fastest.',
        accentColor: AgriColors.flood,
      );
    case 'heat':
      return const AlertGuidance(
        title: 'Heat Alert',
        solution: 'Add shade or cooling support and shift watering to early morning or late evening.',
        rationale: 'This reduces transpiration stress during peak heat while keeping water loss and leaf burn under control.',
        accentColor: AgriColors.heat,
      );
    case 'blight':
      return const AlertGuidance(
        title: 'Blight Risk Alert',
        solution: 'Inspect the crop, remove infected material, and apply the recommended treatment or spray protocol.',
        rationale: 'Early containment limits spread, protects healthy plants, and gives the treatment the best chance to work.',
        accentColor: AgriColors.blight,
      );
    default:
      return const AlertGuidance(
        title: 'Alert',
        solution: 'Review the reading, verify the sensor, and follow the local response plan for this condition.',
        rationale: 'A manual review is safest when the alert type is unfamiliar because it avoids the wrong automated response.',
        accentColor: AgriColors.primary,
      );
  }
}

AlertGuidance guidanceForAlertEntry(AlertEntry alert) {
  return guidanceForAlertType(alert.type);
}