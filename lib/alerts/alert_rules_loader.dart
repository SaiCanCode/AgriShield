import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'alert_guidance.dart';

class AlertRulesRepository {
  AlertRulesRepository._();

  static final AlertRulesRepository instance = AlertRulesRepository._();

  bool _initialized = false;
  late Map<String, dynamic> _raw;
  final Map<String, AlertGuidance> _byAlertType = {};

  Future<void> initFromAsset([String assetPath = 'assets/data/faoguidance.json']) async {
    if (_initialized) return;
    try {
      final jsonStr = await rootBundle.loadString(assetPath);
      _raw = jsonDecode(jsonStr) as Map<String, dynamic>;
      _buildIndex();
      _initialized = true;
    } catch (e) {
      // Keep uninitialized on error; caller should fall back to defaults
      debugPrint('Failed to load alert rules asset: $e');
    }
  }

  void _buildIndex() {
    _byAlertType.clear();

    final solutions = <String, Map<String, dynamic>>{};
    final solList = (_raw['solutions'] as List<dynamic>?) ?? [];
    for (final s in solList) {
      if (s is Map<String, dynamic>) {
        final id = s['solutionId']?.toString() ?? '';
        if (id.isNotEmpty) solutions[id] = s;
      }
    }

    final alerts = (_raw['alerts'] as List<dynamic>?) ?? [];
    for (final a in alerts) {
      if (a is Map<String, dynamic>) {
        final type = (a['alertType'] ?? '').toString();
        final sid = (a['solutionId'] ?? '').toString();
        if (type.isEmpty) continue;

        final sol = solutions[sid];
        final title = sol != null ? (sol['title'] ?? type).toString() : type;
        final solutionText = sol != null ? (sol['solution'] ?? '').toString() : '';
        final rationale = sol != null ? (sol['rationale'] ?? '').toString() : '';

        final color = AgriColors.forAlertType(type);

        _byAlertType[type.toLowerCase()] = AlertGuidance(
          title: title,
          solution: solutionText,
          rationale: rationale,
          accentColor: color,
        );
      }
    }
  }

  AlertGuidance? guidanceForType(String type) {
    if (!_initialized) return null;
    return _byAlertType[type.trim().toLowerCase()];
  }

  /// Returns the source used for guidance for [type].
  /// Returns 'json' when the rules asset contained a mapping for [type],
  /// otherwise returns 'fallback'. If repository isn't initialized returns 'fallback'.
  String guidanceSourceForType(String type) {
    if (!_initialized) return 'fallback';
    return _byAlertType.containsKey(type.trim().toLowerCase()) ? 'json' : 'fallback';
  }
}
