import 'dart:convert';
import 'dart:io';

import '../models/models.dart';

/// Persists app state (settings, recents, chat history) under
/// `<user-home>/.nexora/`.
class SettingsService {
  static String get configDir {
    final env = Platform.environment;
    final home = env['USERPROFILE'] ?? env['HOME'] ?? Directory.current.path;
    return '$home${Platform.pathSeparator}.nexora';
  }

  static String get _settingsPath =>
      '$configDir${Platform.pathSeparator}settings.json';
  static String get _recentsPath =>
      '$configDir${Platform.pathSeparator}recents.json';
  static String get _chatHistoryPath =>
      '$configDir${Platform.pathSeparator}chat_history.json';

  static void ensureDirs() {
    final dir = Directory(configDir);
    if (!dir.existsSync()) dir.createSync(recursive: true);
  }

  // ---------------------------------------------------------------- settings

  static AppSettings loadSettings() {
    try {
      final f = File(_settingsPath);
      if (f.existsSync()) {
        return AppSettings.fromJson(
            jsonDecode(f.readAsStringSync()) as Map<String, dynamic>);
      }
    } catch (_) {/* corrupt file -> defaults */}
    return AppSettings();
  }

  static void saveSettings(AppSettings s) {
    ensureDirs();
    File(_settingsPath)
        .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(s));
  }

  // ---------------------------------------------------------------- recents

  static List<RecentFolder> loadRecents() {
    try {
      final f = File(_recentsPath);
      if (f.existsSync()) {
        final list = jsonDecode(f.readAsStringSync()) as List;
        return list
            .map((e) => RecentFolder.fromJson(e as Map<String, dynamic>))
            .where((r) => Directory(r.path).existsSync())
            .toList();
      }
    } catch (_) {}
    return [];
  }

  static void saveRecents(List<RecentFolder> recents) {
    ensureDirs();
    File(_recentsPath).writeAsStringSync(
        jsonEncode(recents.take(10).map((r) => r.toJson()).toList()));
  }

  // ------------------------------------------------------------ chat history

  static List<ChatSession> loadChatSessions() {
    try {
      final f = File(_chatHistoryPath);
      if (f.existsSync()) {
        final list = jsonDecode(f.readAsStringSync()) as List;
        return list
            .map((e) => ChatSession.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  static void saveChatSessions(List<ChatSession> sessions) {
    ensureDirs();
    // Keep the 50 most recent sessions to bound the file size.
    final bounded = sessions.take(50).map((s) => s.toJson()).toList();
    File(_chatHistoryPath).writeAsStringSync(jsonEncode(bounded));
  }
}
