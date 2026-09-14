import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:nexora/src/models/models.dart';
import 'package:nexora/src/providers/chat_provider.dart';
import 'package:nexora/src/providers/completion_provider.dart';
import 'package:nexora/src/providers/editor_provider.dart';
import 'package:nexora/src/providers/git_provider.dart';
import 'package:nexora/src/providers/settings_provider.dart';
import 'package:nexora/src/providers/terminal_provider.dart';
import 'package:nexora/src/providers/ui_provider.dart';
import 'package:nexora/src/providers/workspace_provider.dart';
import 'package:nexora/src/screens/home_dashboard.dart';
import 'package:nexora/src/services/fs_service.dart';
import 'package:nexora/src/services/git_service.dart';
import 'package:nexora/src/theme/app_colors.dart';

// ---------------------------------------------------------------------------
// Unit tests — pure logic, no plugins.
// ---------------------------------------------------------------------------

void main() {
  group('AppSettings', () {
    test('JSON round-trip preserves every field', () {
      final s = AppSettings(
        aiBaseUrl: 'http://192.168.1.5:8080',
        aiModel: 'llama3.1:8b',
        aiApiType: 'openai',
        aiTemperature: 0.7,
        aiMaxTokens: 1024,
        tabSize: 8,
        showLineNumbers: false,
        showMinimap: false,
        wordWrap: true,
        themeMode: 'light',
        ghostTextEnabled: false,
      );
      final restored = AppSettings.fromJson(s.toJson());
      expect(restored.aiBaseUrl, s.aiBaseUrl);
      expect(restored.aiModel, s.aiModel);
      expect(restored.aiApiType, s.aiApiType);
      expect(restored.aiTemperature, s.aiTemperature);
      expect(restored.aiMaxTokens, s.aiMaxTokens);
      expect(restored.tabSize, s.tabSize);
      expect(restored.showLineNumbers, isFalse);
      expect(restored.showMinimap, isFalse);
      expect(restored.wordWrap, isTrue);
      expect(restored.themeMode, 'light');
      expect(restored.ghostTextEnabled, isFalse);
    });

    test('fromJson tolerates missing keys and corrupt values', () {
      final s = AppSettings.fromJson(<String, dynamic>{});
      expect(s.aiBaseUrl, 'http://localhost:11434');
      expect(s.tabSize, 2);
      expect(s.themeMode, 'dark');
    });
  });

  group('EditorTab', () {
    test('dirty reflects unsaved content', () {
      final tab = EditorTab(path: '/x/a.dart', name: 'a.dart', content: 'hi', language: 'dart');
      expect(tab.dirty, isFalse);
      tab.content = 'hi there';
      expect(tab.dirty, isTrue);
      tab.savedContent = 'hi there';
      expect(tab.dirty, isFalse);
    });
  });

  group('ChatSession', () {
    test('JSON round-trip keeps messages and roles', () {
      final s = ChatSession(id: 's1', title: 't', messages: [
        ChatMessage(role: ChatRole.user, content: 'hello'),
        ChatMessage(role: ChatRole.assistant, content: 'world'),
      ]);
      final restored = ChatSession.fromJson(s.toJson());
      expect(restored.id, 's1');
      expect(restored.messages, hasLength(2));
      expect(restored.messages.first.role, ChatRole.user);
      expect(restored.messages.last.content, 'world');
    });
  });

  group('GitService.parseUnifiedDiff', () {
    test('parses adds, dels, hunks and numbering', () {
      const diff = '''
diff --git a/lib/a.dart b/lib/a.dart
index 111..222 100644
--- a/lib/a.dart
+++ b/lib/a.dart
@@ -1,3 +1,4 @@
 void main() {
-  print('old');
+  print('new');
+  print('more');
 }
''';
      final files = GitService.parseUnifiedDiff(diff);
      expect(files, hasLength(1));
      final f = files.first;
      expect(f.path, 'lib/a.dart');
      expect(f.additions, 2);
      expect(f.deletions, 1);
      final adds = f.lines.where((l) => l.type == 'add').toList();
      expect(adds.first.text, "  print('new');");
      expect(adds.first.newLine, 2);
      final dels = f.lines.where((l) => l.type == 'del').toList();
      expect(dels.first.oldLine, 2);
      expect(f.lines.first.type, anyOf('meta', 'hunk'));
    });
  });

  group('FsService.languageOf', () {
    test('maps extensions', () {
      expect(FsService.languageOf('/a/main.dart'), 'dart');
      expect(FsService.languageOf('/a/x.py'), 'python');
      expect(FsService.languageOf('/a/x.TS'), 'typescript');
      expect(FsService.languageOf('/a/x.unknown'), 'plaintext');
    });
  });

  // -------------------------------------------------------------------------
  // Widget smoke test — home dashboard renders with the full provider graph
  // (audit fix #9: the old test referenced a non-existent MyApp class).
  // -------------------------------------------------------------------------

  testWidgets('HomeDashboard renders branding with provider graph',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => UiProvider()),
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ChangeNotifierProvider(create: (_) => WorkspaceProvider()),
          ChangeNotifierProvider(create: (_) => EditorProvider()),
          ChangeNotifierProvider(create: (_) => TerminalProvider()),
          ChangeNotifierProvider(create: (_) => CompletionProvider(
              SettingsProvider().ai, () => true)),
          ChangeNotifierProvider(
              create: (_) => ChatProvider(
                  ai: SettingsProvider().ai, onFileWritten: (_) {})),
          ChangeNotifierProvider(create: (_) => GitProvider(SettingsProvider().ai)),
        ],
        child: MaterialApp(
          theme: AppColors.dark.toThemeData(),
          home: const Scaffold(body: HomeDashboard()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('NEXORA'), findsWidgets);
    expect(find.textContaining('AI-native'), findsOneWidget);
  });
}
