// NEXORA — root shell (Web Prototype App.tsx): TopBar + (ActivityBar | view)
// + StatusBar, wrapped in the global keyboard shortcut map (CallbackShortcuts
// + an autofocus Focus node so bindings work when nothing else has focus).
// The body is a Stack hosting the AgentRunner overlay (fixed bottom-48
// right-24 like the prototype), and the main view switcher cross-fades in
// 150ms (AnimatePresence).
//
// Audit fix #3: onWindowClose uses the GLOBAL navigatorKey exported from
// lib/main.dart — never a context above MaterialApp.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import '../../main.dart' show navigatorKey;
import '../providers/editor_provider.dart';
import '../providers/ui_provider.dart';
import '../widgets/activity_bar.dart';
import '../widgets/agent_runner.dart';
import '../widgets/command_palette.dart';
import '../widgets/nexora_ui.dart';
import '../widgets/status_bar.dart';
import '../widgets/top_bar.dart';
import 'editor_workspace.dart';
import 'home_dashboard.dart';
import 'settings_screen.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> with WindowListener {
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      windowManager.setPreventClose(true);
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowClose() async {
    // Use the GLOBAL navigator (audit fix #3): this State's own context is
    // fine, but the dialog must be shown below MaterialApp via navigatorKey.
    final ctx = navigatorKey.currentContext;
    if (ctx == null) {
      await windowManager.destroy();
      return;
    }
    final editor = Provider.of<EditorProvider>(ctx, listen: false);
    if (!editor.anyDirty) {
      await windowManager.destroy();
      return;
    }
    final discard = await showDialog<bool>(
      context: ctx,
      barrierDismissible: false,
      builder: (dctx) {
        final c = Provider.of<UiProvider>(dctx, listen: false).palette;
        return AlertDialog(
          backgroundColor: c.panelBackground,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: c.borderLight),
          ),
          title: Text('Unsaved changes',
              style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          content: Text('Discard unsaved changes and exit?',
              style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dctx, false),
              child: Text('Cancel',
                  style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dctx, true),
              child: Text('Discard & Exit',
                  style: TextStyle(
                      color: c.error,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );
    if (discard == true) {
      await windowManager.destroy();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = context.watch<UiProvider>();

    // ---- Global keyboard bindings (labels in menus match these exactly) ----
    final bindings = <ShortcutActivator, VoidCallback>{
      SingleActivator(LogicalKeyboardKey.keyS, control: true):
          () => NxActions.save(context),
      SingleActivator(LogicalKeyboardKey.keyS, control: true, shift: true):
          () => NxActions.saveAll(context),
      SingleActivator(LogicalKeyboardKey.keyW, control: true):
          () => NxActions.closeTab(context),
      SingleActivator(LogicalKeyboardKey.keyN, control: true):
          () => context.read<EditorProvider>().openUntitled(),
      SingleActivator(LogicalKeyboardKey.keyO, control: true):
          () => NxActions.openFolder(context),
      SingleActivator(LogicalKeyboardKey.keyP, control: true, shift: true):
          () => showCommandPalette(context),
      SingleActivator(LogicalKeyboardKey.keyK, control: true):
          () => showCommandPalette(context),
      SingleActivator(LogicalKeyboardKey.keyK, control: true, shift: true):
          () => NxActions.newTerminal(context),
      SingleActivator(LogicalKeyboardKey.backquote, control: true):
          () => context.read<UiProvider>().toggleTerminal(),
      SingleActivator(LogicalKeyboardKey.keyB, control: true):
          () => context.read<UiProvider>().toggleSidebar(),
      SingleActivator(LogicalKeyboardKey.keyJ, control: true):
          () => context.read<UiProvider>().toggleRightPanel(),
      SingleActivator(LogicalKeyboardKey.f5):
          () => NxActions.runActiveFile(context),
      SingleActivator(LogicalKeyboardKey.keyE, control: true, shift: true):
          () => NxActions.showLeftPanel(context, LeftPanelMode.explorer),
      SingleActivator(LogicalKeyboardKey.keyF, control: true, shift: true):
          () => NxActions.showLeftPanel(context, LeftPanelMode.search),
      SingleActivator(LogicalKeyboardKey.keyG, control: true, shift: true):
          () => NxActions.showLeftPanel(context, LeftPanelMode.git),
    };

    return CallbackShortcuts(
      bindings: bindings,
      child: Focus(
        autofocus: true,
        skipTraversal: true,
        child: Scaffold(
          backgroundColor: ui.palette.background,
          body: Stack(
            children: [
              Positioned.fill(
                child: Column(
                  children: [
                    const TopBar(),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const ActivityBar(),
                          Expanded(
                            // View transition: 150ms fade (AnimatePresence).
                            child: AnimatedSwitcher(
                              duration: NxMotion.fast,
                              switchInCurve: NxMotion.curve,
                              switchOutCurve: Curves.easeIn,
                              transitionBuilder: (child, animation) =>
                                  FadeTransition(
                                      opacity: animation, child: child),
                              layoutBuilder: (currentChild, previousChildren) =>
                                  Stack(
                                    alignment: Alignment.center,
                                    fit: StackFit.expand,
                                    children: <Widget>[
                                      ...previousChildren.cast<Widget>(),
                                      if (currentChild != null) currentChild,
                                    ],
                                  ),
                              child: KeyedSubtree(
                                key: ValueKey(ui.view),
                                child: _buildView(ui.view),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const StatusBar(),
                  ],
                ),
              ),
              // AgentRunner overlay (prototype: fixed bottom-48 right-24).
              const Positioned(
                bottom: 48,
                right: 24,
                child: AgentRunner(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildView(ViewMode view) {
    switch (view) {
      case ViewMode.home:
        return const HomeDashboard();
      case ViewMode.settings:
        return const SettingsScreen();
      case ViewMode.editor:
        return const EditorWorkspace();
    }
  }
}
