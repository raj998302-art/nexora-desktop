import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/ai_service.dart';
import '../services/settings_service.dart';

/// Owns [AppSettings], persists them, and hosts the single [AiService]
/// instance (live settings are read via a getter — no recreation needed).
class SettingsProvider extends ChangeNotifier {
  AppSettings settings = AppSettings();
  final AiService ai = AiService(() => _settingsSnapshot);

  static AppSettings _settingsSnapshot = AppSettings();

  bool _testing = false;
  AiTestResult? _lastTest;
  List<String> _availableModels = [];

  bool get testing => _testing;
  AiTestResult? get lastTest => _lastTest;
  List<String> get availableModels => _availableModels;
  AppSettings get s => settings;

  SettingsProvider() {
    settings = SettingsService.loadSettings();
    _settingsSnapshot = settings;
  }

  // ------------------------------------------------------------- mutations

  void update(void Function(AppSettings) mutator) {
    mutator(settings);
    _settingsSnapshot = settings;
    SettingsService.saveSettings(settings);
    notifyListeners();
  }

  /// Tab size setter that always snaps to a valid supported value —
  /// the settings UI uses a segmented button {2,4,8} (audit fix #11: never
  /// crash when a persisted value is outside the set).
  int get tabSizeEffective {
    const supported = {2, 4, 8};
    if (supported.contains(settings.tabSize)) return settings.tabSize;
    return 2;
  }

  Future<void> testConnection() async {
    if (_testing) return;
    _testing = true;
    _lastTest = null;
    notifyListeners();
    try {
      _lastTest = await ai.testConnection();
      _availableModels = await ai.listModels();
    } catch (e) {
      _lastTest = AiTestResult(false, e.toString());
    } finally {
      _testing = false;
      notifyListeners();
    }
  }

  Future<void> refreshModels() async {
    _availableModels = await ai.listModels();
    notifyListeners();
  }

  @override
  void dispose() {
    ai.dispose();
    super.dispose();
  }
}
