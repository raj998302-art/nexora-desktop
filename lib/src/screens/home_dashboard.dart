// NEXORA — home dashboard: welcome logo, AI prompt composer, open-folder
// button, recent folders and a new-chat shortcut.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/chat_provider.dart';
import '../providers/git_provider.dart';
import '../providers/ui_provider.dart';
import '../providers/workspace_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/command_palette.dart';

class HomeDashboard extends StatefulWidget {
  const HomeDashboard({super.key});

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  final TextEditingController _controller = TextEditingController();

  /// Own focus node for the composer so Enter sends (Shift+Enter = newline)
  /// without the multiline TextField swallowing the key.
  late final FocusNode _composerFocus = FocusNode(
    onKeyEvent: (node, event) {
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.enter &&
          !HardwareKeyboard.instance.isShiftPressed) {
        _send();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    },
  );

  @override
  void dispose() {
    _controller.dispose();
    _composerFocus.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final workspace = context.read<WorkspaceProvider>();
    final ui = context.read<UiProvider>();

    var root = workspace.rootPath;
    if (root == null || root.isEmpty) {
      // No workspace yet → pick a folder first, then send.
      final path = await showOpenFolderDialog(context);
      if (path == null || path.isEmpty) return;
      if (!mounted) return;
      try {
        await workspace.openFolder(path);
        context.read<GitProvider>().bindWorkspace(path);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Open folder failed: $e')));
        }
        return;
      }
      root = workspace.rootPath;
    }
    if (!mounted) return;
    _controller.clear();
    ui.setView(ViewMode.editor);
    if (!ui.rightPanelOpen) ui.toggleRightPanel();
    context.read<ChatProvider>().sendMessage(text, workspaceRoot: root);
  }

  Future<void> _openPath(String path) async {
    final workspace = context.read<WorkspaceProvider>();
    try {
      await workspace.openFolder(path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Open folder failed: $e')));
      }
      return;
    }
    if (!mounted) return;
    context.read<GitProvider>().bindWorkspace(path);
    context.read<UiProvider>().setView(ViewMode.editor);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<UiProvider>().palette;
    final workspace = context.watch<WorkspaceProvider>();
    final recents = workspace.recents.take(5).toList();

    return Container(
      color: c.background,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          child: LayoutBuilder(
            builder: (ctx, constraints) {
              final width =
                  math.min(560.0, constraints.maxWidth * 0.9).clamp(280.0, 560.0);
              return SizedBox(
                width: width,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ---- Logo ----
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.auto_awesome_outlined,
                            size: 34, color: c.blueLight),
                        const SizedBox(width: 10),
                        Text('NEXORA',
                            style: TextStyle(
                                color: c.textPrimary,
                                fontSize: 34,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 3)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('AI-native coding environment',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: c.textSecondary,
                            fontSize: 13,
                            letterSpacing: 0.5)),
                    const SizedBox(height: 36),
                    // ---- Composer ----
                    _composer(c),
                    const SizedBox(height: 22),
                    // ---- Open folder ----
                    Center(
                      child: OutlinedButton.icon(
                        onPressed: () => NxActions.openFolder(context),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: c.borderLight),
                          foregroundColor: c.textPrimary,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 11),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: Icon(Icons.folder_open,
                            size: 15, color: c.textPrimary),
                        label: Text('Open a folder',
                            style: TextStyle(
                                color: c.textPrimary, fontSize: 12.5)),
                      ),
                    ),
                    // ---- Recents ----
                    if (recents.isNotEmpty) ...[
                      const SizedBox(height: 30),
                      Padding(
                        padding: const EdgeInsets.only(left: 6, bottom: 6),
                        child: Text('RECENT FOLDERS',
                            style: TextStyle(
                                color: c.textSecondary,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1)),
                      ),
                      for (final r in recents)
                        InkWell(
                          onTap: () => _openPath(r.path),
                          borderRadius: BorderRadius.circular(6),
                          hoverColor: c.panelBackground,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 5),
                            child: Row(
                              children: [
                                Icon(Icons.folder,
                                    size: 14, color: c.blueLight),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    r.path,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        color: c.textPrimary,
                                        fontSize: 12,
                                        fontFamily: 'monospace'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                    const SizedBox(height: 26),
                    Center(
                      child: TextButton(
                        onPressed: () =>
                            context.read<ChatProvider>().newSession(),
                        child: Text('New chat',
                            style:
                                TextStyle(color: c.accent, fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _composer(AppColors c) {
    return Container(
      decoration: BoxDecoration(
        color: c.panelBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.borderLight),
      ),
      padding: const EdgeInsets.all(6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _composerFocus,
              maxLines: 3,
              minLines: 1,
              style: TextStyle(color: c.textPrimary, fontSize: 13.5),
              decoration: InputDecoration(
                hintText: 'Ask NEXORA to build something… (Ctrl+K)',
                hintStyle:
                    TextStyle(color: c.textSecondary, fontSize: 13),
                border: InputBorder.none,
                isCollapsed: false,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 10),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 2, right: 2),
            child: Material(
              color: c.accent,
              borderRadius: BorderRadius.circular(7),
              child: InkWell(
                borderRadius: BorderRadius.circular(7),
                hoverColor: c.textOnAccent.withValues(alpha: 0.15),
                onTap: () => _send(),
                child: SizedBox(
                  width: 34,
                  height: 34,
                  child: Icon(Icons.arrow_upward,
                      size: 17, color: c.textOnAccent),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
