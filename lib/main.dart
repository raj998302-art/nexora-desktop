import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'src/providers/chat_provider.dart';
import 'src/providers/completion_provider.dart';
import 'src/providers/editor_provider.dart';
import 'src/providers/git_provider.dart';
import 'src/providers/settings_provider.dart';
import 'src/providers/terminal_provider.dart';
import 'src/providers/ui_provider.dart';
import 'src/providers/workspace_provider.dart';
import 'src/screens/main_layout.dart';
import 'src/theme/app_colors.dart';

/// Global navigator key so window-close handling can show dialogs BELOW
/// MaterialApp (audit fix #3: previously the close handler used a context
/// above MaterialApp and dialogs crashed).
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  const options = WindowOptions(
    size: Size(1280, 800),
    minimumSize: Size(800, 500),
    center: true,
    backgroundColor: Color(0xFF1E1E1E),
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
    title: 'NEXORA',
  );

  windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  // --- Provider graph ------------------------------------------------------
  final settingsProvider = SettingsProvider();
  final uiProvider = UiProvider();
  uiProvider.setThemeMode(
      settingsProvider.settings.themeMode == 'light' ? ThemeMode.light : ThemeMode.dark);

  final ai = settingsProvider.ai;

  final workspace = WorkspaceProvider();
  final editor = EditorProvider();
  final terminal = TerminalProvider();
  final chat = ChatProvider(
    ai: ai,
    onFileWritten: (path) {
      editor.reloadTab(path);
      workspace.refresh();
    },
  );
  final completion = CompletionProvider(
    ai,
    () => settingsProvider.settings.ghostTextEnabled,
  );
  final git = GitProvider(ai);

  // Cross-provider wiring (avoids circular imports).
  workspace.closeTabsByPrefix = editor.closeMany;
  editor.onRunFile = (path) {
    final cmd = TerminalProvider.runCommandFor(path);
    final cwd = workspace.rootPath;
    if (cmd == null) {
      terminal.createSession(cwd: cwd);
      final ctx = navigatorKey.currentContext;
      if (ctx != null) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
          content: Text(
              'No run command configured for .${path.split('.').last} files yet.'),
          duration: const Duration(seconds: 2),
        ));
      }
      return;
    }
    terminal.createSession(cwd: cwd, initialCommand: cmd);
    uiProvider.setTerminalOpen(true);
    uiProvider.setView(ViewMode.editor);
  };

  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: settingsProvider),
      ChangeNotifierProvider.value(value: uiProvider),
      ChangeNotifierProvider.value(value: workspace),
      ChangeNotifierProvider.value(value: editor),
      ChangeNotifierProvider.value(value: terminal),
      ChangeNotifierProvider.value(value: chat),
      ChangeNotifierProvider.value(value: completion),
      ChangeNotifierProvider.value(value: git),
    ],
    child: const NexoraApp(),
  ));
}

class NexoraApp extends StatelessWidget {
  const NexoraApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ui = context.watch<UiProvider>();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NEXORA',
      navigatorKey: navigatorKey,
      theme: AppColors.light.toThemeData(),
      darkTheme: AppColors.dark.toThemeData(),
      themeMode: ui.themeMode,
      home: const MainLayout(),
    );
  }
}
