import 'dart:async';

import 'package:agrishield2/providers/readings_provider.dart';
// import 'package:agrishield2/services/realtime_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/firebase_config.dart';

const String settingsSmsLanguageKey = 'settings.smsLanguage';
const String settingsSmsAlertsEnabledKey = 'settings.smsAlertsEnabled';
const String settingsPushNotificationsEnabledKey =
  'settings.pushNotificationsEnabled';
const String settingsAlertCooldownHoursKey = 'settings.alertCooldownHours';

enum SmsLanguage { english, hausa, yoruba, igbo }

extension SmsLanguageLabel on SmsLanguage {
  String get label {
    switch (this) {
      case SmsLanguage.english:
        return 'English';
      case SmsLanguage.hausa:
        return 'Hausa';
      case SmsLanguage.yoruba:
        return 'Yoruba';
      case SmsLanguage.igbo:
        return 'Igbo';
    }
  }
}

class SettingsState {
  const SettingsState({
    required this.smsLanguage,
    required this.smsAlertsEnabled,
    required this.pushNotificationsEnabled,
    required this.alertCooldownHours,
  });

  const SettingsState.defaults()
    : smsLanguage = SmsLanguage.english,
      smsAlertsEnabled = true,
      pushNotificationsEnabled = true,
      alertCooldownHours = 4;

  final SmsLanguage smsLanguage;
  final bool smsAlertsEnabled;
  final bool pushNotificationsEnabled;
  final int alertCooldownHours;

  SettingsState copyWith({
    SmsLanguage? smsLanguage,
    bool? smsAlertsEnabled,
    bool? pushNotificationsEnabled,
    int? alertCooldownHours,
  }) {
    return SettingsState(
      smsLanguage: smsLanguage ?? this.smsLanguage,
      smsAlertsEnabled: smsAlertsEnabled ?? this.smsAlertsEnabled,
      pushNotificationsEnabled:
          pushNotificationsEnabled ?? this.pushNotificationsEnabled,
      alertCooldownHours: alertCooldownHours ?? this.alertCooldownHours,
    );
  }
}

class SettingsRepository {
  Future<SettingsState> load() async {
    final prefs = await SharedPreferences.getInstance();
    final languageIndex = prefs.getInt(settingsSmsLanguageKey) ?? 0;
    return SettingsState(
      smsLanguage: SmsLanguage.values[
        languageIndex.clamp(0, SmsLanguage.values.length - 1)],
      smsAlertsEnabled: prefs.getBool(settingsSmsAlertsEnabledKey) ?? true,
      pushNotificationsEnabled:
          prefs.getBool(settingsPushNotificationsEnabledKey) ?? true,
      alertCooldownHours: prefs.getInt(settingsAlertCooldownHoursKey) ?? 4,
    );
  }

  Future<void> saveSmsLanguage(SmsLanguage language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(settingsSmsLanguageKey, language.index);
  }

  Future<void> saveSmsAlertsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(settingsSmsAlertsEnabledKey, enabled);
  }

  Future<void> savePushNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(settingsPushNotificationsEnabledKey, enabled);
  }

  Future<void> saveAlertCooldownHours(int hours) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(settingsAlertCooldownHoursKey, hours);
  }
}

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository();
});

final settingsControllerProvider =
    StateNotifierProvider<SettingsController, SettingsState>((ref) {
      return SettingsController(ref.read(settingsRepositoryProvider));
    });

class SettingsController extends StateNotifier<SettingsState> {
  SettingsController(this._repository) : super(const SettingsState.defaults()) {
    unawaited(_load());
  }

  final SettingsRepository _repository;

  Future<void> _load() async {
    state = await _repository.load();
  }

  Future<void> setSmsLanguage(SmsLanguage language) async {
    state = state.copyWith(smsLanguage: language);
    await _repository.saveSmsLanguage(language);
  }

  Future<void> setSmsAlertsEnabled(bool enabled) async {
    state = state.copyWith(smsAlertsEnabled: enabled);
    await _repository.saveSmsAlertsEnabled(enabled);
  }

  Future<void> setPushNotificationsEnabled(bool enabled) async {
    state = state.copyWith(pushNotificationsEnabled: enabled);
    await _repository.savePushNotificationsEnabled(enabled);
  }

  Future<void> setAlertCooldownHours(int hours) async {
    state = state.copyWith(alertCooldownHours: hours);
    await _repository.saveAlertCooldownHours(hours);
  }
}

class SettingsNodeSummary {
  const SettingsNodeSummary({
    required this.primaryNodeId,
    required this.nodeCount,
    required this.firmwareVersion,
    required this.deploymentDay,
    required this.growthStage,
  });

  final String primaryNodeId;
  final int nodeCount;
  final String firmwareVersion;
  final int? deploymentDay;
  final String growthStage;

  factory SettingsNodeSummary.fromMap(
    Map<String, dynamic> map, {
    required String primaryNodeId,
    required int nodeCount,
  }) {
    return SettingsNodeSummary(
      primaryNodeId: primaryNodeId,
      nodeCount: nodeCount,
      firmwareVersion: _stringOrDash(map['fw_version']),
      deploymentDay: _intOrNull(map['day']),
      growthStage: _humanize(_stringOrDash(map['stage'])),
    );
  }

  String get deploymentSummary {
    final dayLabel = deploymentDay == null ? 'Day —' : 'Day $deploymentDay';
    return '$dayLabel • $growthStage';
  }
}

final firebaseConnectionProvider = StreamProvider<bool>((ref) {
  final database = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: firebaseDatabaseUrl,
  );

  return database.ref('.info/connected').onValue.map((event) {
    return event.snapshot.value == true;
  });
});

final settingsNodeSummaryProvider = StreamProvider<SettingsNodeSummary?>((ref) {
  final nodesAsync = ref.watch(nodesListProvider);
  final nodes = nodesAsync.asData?.value ?? const <String>[];
  if (nodes.isEmpty) {
    return Stream.value(null);
  }

  final service = ref.watch(realtimeServiceProvider);
  final primaryNodeId = nodes.first;

  return service.streamRawReadings(primaryNodeId).map((raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }

    final latest = _latestPayload(raw);
    if (latest == null) {
      return null;
    }

    return SettingsNodeSummary.fromMap(
      latest,
      primaryNodeId: primaryNodeId,
      nodeCount: nodes.length,
    );
  });
});

Map<String, dynamic>? _latestPayload(Map<String, dynamic> raw) {
  Map<String, dynamic>? latestPayload;
  int latestTimestamp = -1;

  for (final entry in raw.entries) {
    if (entry.value is! Map) {
      continue;
    }

    final payload = Map<String, dynamic>.from(entry.value as Map);
    final timestamp = _intOrNull(entry.key) ?? _intOrNull(payload['ts']) ?? 0;
    if (timestamp >= latestTimestamp) {
      latestTimestamp = timestamp;
      latestPayload = payload;
    }
  }

  return latestPayload;
}

String _stringOrDash(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? '—' : text;
}

int? _intOrNull(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '');
}

String _humanize(String value) {
  if (value == '—' || value.isEmpty) return '—';
  return value
      .split(RegExp(r'[_\s]+'))
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1).toLowerCase())
      .join(' ');
}
