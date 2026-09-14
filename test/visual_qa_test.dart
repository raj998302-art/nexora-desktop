import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:nexora/main.dart';
import 'package:nexora/src/models/models.dart';
import 'package:nexora/src/providers/chat_provider.dart';
import 'package:nexora/src/providers/completion_provider.dart';
import 'package:nexora/src/providers/editor_provider.dart';
import 'package:nexora/src/providers/git_provider.dart';
import 'package:nexora/src/providers/settings_provider.dart';
import 'package:nexora/src/providers/terminal_provider.dart';
import 'package:nexora/src/providers/ui_provider.dart';
import 'package:nexora/src/providers/workspace_provider.dart';

/// Visual QA harness — renders the FULL NEXORA app shell (TopBar +
/// ActivityBar + views + StatusBar + AgentRunner) at fixed resolutions and
/// writes PNG screenshots to test/goldens/ (run with --update-goldens).
///
/// Real fonts are loaded via FontLoader (tests otherwise use Ahem blocks)
/// and the window_manager MethodChannel is mocked (no OS window in tests).
/// Renders are compared against Web Prototype screenshots.
Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Mock window_manager so MainLayout's WindowListener works headlessly.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('window_manager'),
            (call) async {
      return true;
    });

    // Load real fonts so goldens show real glyphs, not Ahem boxes.
    Future<FontLoader> load(String family, List<String> files) async {
      final loader = FontLoader(family);
      for (final f in files) {
        final bytes = File(f).readAsBytesSync();
        final data = ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.length);
        loader.addFont(Future.value(data));
      }
      await loader.load();
      return loader;
    }

    await load('Inter', [
      'assets/fonts/Inter-Regular.ttf',
      'assets/fonts/Inter-Medium.ttf',
      'assets/fonts/Inter-SemiBold.ttf',
      'assets/fonts/Inter-Bold.ttf',
    ]);
    await load('FiraCode', ['assets/fonts/FiraCode-Regular.ttf']);

    // Material icons (otherwise all Icons.* render as tofu boxes in goldens).
    final iconLoader = FontLoader('MaterialIcons');
    final iconBytes =
        File('/home/z/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf')
            .readAsBytesSync();
    iconLoader.addFont(Future.value(ByteData.view(
        iconBytes.buffer, iconBytes.offsetInBytes, iconBytes.length)));
    await iconLoader.load();
  });

  final settings = SettingsProvider();
  final ui = UiProvider();
  final defaultWorkspace = WorkspaceProvider();
  final defaultEditor = EditorProvider();
  final defaultTerminal = TerminalProvider();
  final defaultChat = ChatProvider(ai: settings.ai, onFileWritten: (_) {});
  final defaultCompletion = CompletionProvider(settings.ai, () => false);
  final defaultGit = GitProvider(settings.ai);

  Widget shell({
    WorkspaceProvider? workspace,
    EditorProvider? editor,
    ChatProvider? chat,
    TerminalProvider? terminal,
    CompletionProvider? completion,
    GitProvider? git,
  }) =>
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider.value(value: ui),
          ChangeNotifierProvider.value(value: workspace ?? defaultWorkspace),
          ChangeNotifierProvider.value(value: editor ?? defaultEditor),
          ChangeNotifierProvider.value(value: chat ?? defaultChat),
          ChangeNotifierProvider.value(value: terminal ?? defaultTerminal),
          ChangeNotifierProvider.value(value: completion ?? defaultCompletion),
          ChangeNotifierProvider.value(value: git ?? defaultGit),
        ],
        child: const NexoraApp(),
      );

  Future<void> at(WidgetTester tester, int w, int h) async {
    tester.view.physicalSize = Size(w.toDouble(), h.toDouble());
    tester.view.devicePixelRatio = 1.0;
  }

  testWidgets('golden: home 1280x720 (full shell)', (tester) async {
    await at(tester, 1280, 720);
    final workspace = WorkspaceProvider();
    // Fixed demo recents (prototype grid: NEXORA UI / AI Platform /
    // Flutter App / API Gateway) with pinned dates — no wall-clock drift.
    workspace.seedRecentsForTest([
      RecentFolder(
          path: '/home/user/Projects/NEXORA',
          openedAt: DateTime(2024, 3, 12)),
      RecentFolder(
          path: '/home/user/Projects/ai-platform',
          openedAt: DateTime(2024, 3, 11)),
      RecentFolder(
          path: '/home/user/Projects/flutter-app',
          openedAt: DateTime(2024, 3, 9)),
      RecentFolder(
          path: '/home/user/Projects/api-gateway',
          openedAt: DateTime(2024, 3, 2)),
    ]);
    final chat = ChatProvider(ai: settings.ai, onFileWritten: (_) {});
    await tester.pumpWidget(
        shell(workspace: workspace, chat: chat));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await expectLater(find.byType(NexoraApp),
        matchesGoldenFile('goldens/flutter_home_1280.png'));
  });

  testWidgets('golden: editor 1280x720 (full shell)', (tester) async {
    await at(tester, 1280, 720);

    final dir = Directory('/tmp/qa_workspace/lib/src');
    dir.createSync(recursive: true);
    File('/tmp/qa_workspace/lib/main.dart').writeAsStringSync('''
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(body: Center(child: Text('Hello NEXORA'))),
    );
  }
}
''');
    File('/tmp/qa_workspace/pubspec.yaml').writeAsStringSync('name: sample\n');
    File('/tmp/qa_workspace/README.md').writeAsStringSync('# Sample\n');

    final workspace = WorkspaceProvider();
    await workspace.openFolder('/tmp/qa_workspace');
    final editor = EditorProvider();
    editor.openFile('/tmp/qa_workspace/lib/main.dart');
    final chat = ChatProvider(ai: settings.ai, onFileWritten: (_) {});
    chat.currentSession.messages.addAll([
      ChatMessage(
          role: ChatRole.user,
          content: 'Make sure all IDE features are perfectly added!'),
      ChatMessage(
          role: ChatRole.assistant,
          content:
              'Done! Here are the newest additions:\n- History in the chat header\n- Minimap with syntax colors\n- Quick fix lightbulb\n- Thinking levels Normal/High/Max/Ultra'),
    ]);
    final terminal = TerminalProvider();
    final completion = CompletionProvider(settings.ai, () => false);
    final git = GitProvider(settings.ai);
    final session = terminal.createSession(cwd: '/tmp/qa_workspace');
    session.lines
      ..add(TermLine('user@nexora:~/qa_workspace\$ npm run dev'))
      ..add(TermLine('VITE v5.4.21  ready in 687 ms'))
      ..add(TermLine('  Local:   http://localhost:5173/'))
      ..add(TermLine('  Network: http://192.0.0.4:5173/'))
      ..add(TermLine('  press h + enter to show help'));

    ui.setTerminalOpen(true);
    ui.setLeftPanelMode(LeftPanelMode.explorer);
    ui.setView(ViewMode.editor);
    if (!ui.rightPanelOpen) ui.toggleRightPanel();

    await tester.pumpWidget(shell(
        workspace: workspace,
        editor: editor,
        chat: chat,
        terminal: terminal,
        completion: completion,
        git: git));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await expectLater(find.byType(NexoraApp),
        matchesGoldenFile('goldens/flutter_editor_1280.png'));
    terminal.killAll();
    ui.setTerminalOpen(false);
    ui.setView(ViewMode.home);
  });

  testWidgets('golden: settings 1280x720 (full shell)', (tester) async {
    await at(tester, 1280, 720);
    ui.setView(ViewMode.settings);
    await tester.pumpWidget(shell());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await expectLater(find.byType(NexoraApp),
        matchesGoldenFile('goldens/flutter_settings_1280.png'));
    ui.setView(ViewMode.home);
  });

  testWidgets('golden: home 1920x1080 + agent runner (full shell)',
      (tester) async {
    await at(tester, 1920, 1080);
    final workspace = WorkspaceProvider();
    workspace.seedRecentsForTest([
      RecentFolder(
          path: '/home/user/Projects/NEXORA',
          openedAt: DateTime(2024, 3, 12)),
      RecentFolder(
          path: '/home/user/Projects/ai-platform',
          openedAt: DateTime(2024, 3, 11)),
      RecentFolder(
          path: '/home/user/Projects/flutter-app',
          openedAt: DateTime(2024, 3, 9)),
      RecentFolder(
          path: '/home/user/Projects/api-gateway',
          openedAt: DateTime(2024, 3, 2)),
    ]);
    final chat = ChatProvider(ai: settings.ai, onFileWritten: (_) {});
    ui.setAgentRunning(true);
    await tester.pumpWidget(
        shell(workspace: workspace, chat: chat));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await expectLater(find.byType(NexoraApp),
        matchesGoldenFile('goldens/flutter_home_1080.png'));
    ui.setAgentRunning(false);
  });

  testWidgets('golden: editor 1920x1080 (full shell)', (tester) async {
    await at(tester, 1920, 1080);
    final workspace = WorkspaceProvider();
    await workspace.openFolder('/tmp/qa_workspace');
    final editor = EditorProvider();
    editor.openFile('/tmp/qa_workspace/lib/main.dart');
    final chat = ChatProvider(ai: settings.ai, onFileWritten: (_) {});
    chat.currentSession.messages.addAll([
      ChatMessage(
          role: ChatRole.user,
          content: 'Make sure all IDE features are perfectly added!'),
      ChatMessage(
          role: ChatRole.assistant,
          content:
              'Done! Here are the newest additions:\n- History in the chat header\n- Minimap with syntax colors\n- Quick fix lightbulb\n- Thinking levels Normal/High/Max/Ultra'),
    ]);
    final terminal = TerminalProvider();
    final git = GitProvider(settings.ai);
    final session = terminal.createSession(cwd: '/tmp/qa_workspace');
    session.lines
      ..add(TermLine('user@nexora:~/qa_workspace\$ npm run dev'))
      ..add(TermLine('VITE v5.4.21  ready in 687 ms'))
      ..add(TermLine('  Local:   http://localhost:5173/'))
      ..add(TermLine('  Network: http://192.0.0.4:5173/'))
      ..add(TermLine('  press h + enter to show help'));

    ui.setAgentRunning(true);
    ui.setTerminalOpen(true);
    ui.setView(ViewMode.editor);
    if (!ui.rightPanelOpen) ui.toggleRightPanel();

    await tester.pumpWidget(shell(
        workspace: workspace,
        editor: editor,
        chat: chat,
        terminal: terminal,
        git: git));
    await tester.pump();
    // 7s: AgentRunner steps (1500ms interval) all reach "done" — the
    // prototype screenshot shows the completed state.
    await tester.pump(const Duration(seconds: 7));
    await expectLater(find.byType(NexoraApp),
        matchesGoldenFile('goldens/flutter_editor_1080.png'));
    ui.setAgentRunning(false);
    terminal.killAll();
    ui.setTerminalOpen(false);
    ui.setView(ViewMode.home);
  });

  testWidgets('golden: editor 2560x1440 (full shell)', (tester) async {
    await at(tester, 2560, 1440);
    final workspace = WorkspaceProvider();
    await workspace.openFolder('/tmp/qa_workspace');
    final editor = EditorProvider();
    editor.openFile('/tmp/qa_workspace/lib/main.dart');
    final chat = ChatProvider(ai: settings.ai, onFileWritten: (_) {});
    chat.currentSession.messages.addAll([
      ChatMessage(
          role: ChatRole.user,
          content: 'Make sure all IDE features are perfectly added!'),
      ChatMessage(
          role: ChatRole.assistant,
          content:
              'Done! Here are the newest additions:\n- History in the chat header\n- Minimap with syntax colors\n- Quick fix lightbulb\n- Thinking levels Normal/High/Max/Ultra'),
    ]);
    final terminal = TerminalProvider();
    final git = GitProvider(settings.ai);
    final session = terminal.createSession(cwd: '/tmp/qa_workspace');
    session.lines
      ..add(TermLine('user@nexora:~/qa_workspace\$ npm run dev'))
      ..add(TermLine('VITE v5.4.21  ready in 687 ms'))
      ..add(TermLine('  Local:   http://localhost:5173/'))
      ..add(TermLine('  Network: http://192.0.0.4:5173/'))
      ..add(TermLine('  press h + enter to show help'));

    ui.setAgentRunning(true);
    ui.setTerminalOpen(true);
    ui.setView(ViewMode.editor);
    if (!ui.rightPanelOpen) ui.toggleRightPanel();

    await tester.pumpWidget(shell(
        workspace: workspace,
        editor: editor,
        chat: chat,
        terminal: terminal,
        git: git));
    await tester.pump();
    // 7s: AgentRunner steps (1500ms interval) all reach "done" — the
    // prototype screenshot shows the completed state.
    await tester.pump(const Duration(seconds: 7));
    await expectLater(find.byType(NexoraApp),
        matchesGoldenFile('goldens/flutter_editor_1440.png'));
    ui.setAgentRunning(false);
    terminal.killAll();
    ui.setTerminalOpen(false);
    ui.setView(ViewMode.home);
  });
}
