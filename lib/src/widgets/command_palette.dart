// NEXORA — command palette (Ctrl+Shift+P / Ctrl+K) + shared shell actions.
//
// Audit fixes baked in:
//  #1  The palette pops exactly ONCE (inside the dialog) and the command
//      callback runs AFTER `showCommandPalette` resolves — commands never
//      call Navigator.pop themselves (the old double-pop black-screened the
//      app).
//  #5  Every color comes from the live UiProvider palette — no hardcoded
//      Colors.white text anywhere.
//  #13 Shortcut labels shown here match the bindings wired in
//      main_layout.dart exactly.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/chat_provider.dart';
import '../providers/editor_provider.dart';
import '../providers/git_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/terminal_provider.dart';
import '../providers/ui_provider.dart';
import '../providers/workspace_provider.dart';
import '../services/fs_service.dart';
import '../theme/app_colors.dart';

/// One selectable entry in the command palette.
class CommandItem {
  final String id;
  final String title;
  final String? shortcut;
  final VoidCallback callback;
  const CommandItem(this.id, this.title, this.shortcut, this.callback);
}

/// Opens the command palette. The dialog is popped exactly once (audit fix
/// #1); the selected command runs after the dialog is gone.
Future<void> showCommandPalette(BuildContext context) async {
  // Commands are built with the CALLER's context so their callbacks execute
  // against a still-mounted element after the dialog has closed.
  final commands = buildCommands(context);
  final cmd = await showDialog<CommandItem>(
    context: context,
    barrierColor: Colors.black45,
    builder: (_) => CommandPaletteDialog(commands: commands),
  );
  if (cmd != null) cmd.callback();
}

/// The palette command list. [ctx] must be the context of the widget that
/// opened the palette (NOT the dialog's context).
List<CommandItem> buildCommands(BuildContext ctx) {
  return [
    // ---- File ----
    CommandItem('file.new', 'New File', 'Ctrl+N',
        () => ctx.read<EditorProvider>().openUntitled()),
    CommandItem('file.openFolder', 'Open Folder…', 'Ctrl+O',
        () => NxActions.openFolder(ctx)),
    CommandItem('file.save', 'Save', 'Ctrl+S', () => NxActions.save(ctx)),
    CommandItem(
        'file.saveAll', 'Save All', 'Ctrl+Shift+S', () => NxActions.saveAll(ctx)),
    CommandItem('file.closeTab', 'Close Tab', 'Ctrl+W',
        () => NxActions.closeTab(ctx)),
    // ---- View ----
    CommandItem('view.explorer', 'View: Show Explorer', 'Ctrl+Shift+E',
        () => NxActions.showLeftPanel(ctx, LeftPanelMode.explorer)),
    CommandItem('view.search', 'View: Show Search', 'Ctrl+Shift+F',
        () => NxActions.showLeftPanel(ctx, LeftPanelMode.search)),
    CommandItem('view.git', 'View: Show Source Control', 'Ctrl+Shift+G',
        () => NxActions.showLeftPanel(ctx, LeftPanelMode.git)),
    CommandItem('view.chat', 'View: Toggle AI Chat', 'Ctrl+J',
        () => ctx.read<UiProvider>().toggleRightPanel()),
    CommandItem('view.terminal', 'View: Toggle Terminal', 'Ctrl+`',
        () => ctx.read<UiProvider>().toggleTerminal()),
    CommandItem('view.theme', 'View: Toggle Theme', null,
        () => NxActions.toggleTheme(ctx)),
    CommandItem('view.settings', 'View: Open Settings', null,
        () => ctx.read<UiProvider>().setView(ViewMode.settings)),
    // ---- Go ----
    CommandItem('go.home', 'Go: Go Home', null,
        () => ctx.read<UiProvider>().setView(ViewMode.home)),
    CommandItem('go.nextTab', 'Go: Next Tab', null, () => NxActions.nextTab(ctx)),
    CommandItem('go.prevTab', 'Go: Previous Tab', null,
        () => NxActions.prevTab(ctx)),
    CommandItem('go.palette', 'Go: Command Palette', 'Ctrl+Shift+P',
        () => showCommandPalette(ctx)),
    // ---- Run ----
    CommandItem('run.activeFile', 'Run: Run Active File', 'F5',
        () => NxActions.runActiveFile(ctx)),
    // ---- Terminal ----
    CommandItem('terminal.new', 'Terminal: New Terminal', 'Ctrl+Shift+K',
        () => NxActions.newTerminal(ctx)),
    // ---- AI ----
    CommandItem('ai.newChat', 'AI: New Chat Session', null,
        () => NxActions.newChat(ctx)),
    CommandItem('ai.commitMessage', 'AI: Generate Commit Message', null,
        () => NxActions.showLeftPanel(ctx, LeftPanelMode.git)),
  ];
}

/// Shared shell actions used by BOTH the command palette and the global
/// keyboard bindings in main_layout.dart — one behavior, two entry points.
class NxActions {
  NxActions._();

  static void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(milliseconds: 1600)),
    );
  }

  // ------------------------------------------------------------------- file

  /// Ctrl+S. Saves the active tab; when the buffer is untitled (saveActive()
  /// returns false) prompts for a path, writes the file and re-opens it.
  static Future<void> save(BuildContext context) async {
    final editor = context.read<EditorProvider>();
    final tab = editor.activeTab;
    if (tab == null) {
      _snack(context, 'Nothing to save');
      return;
    }
    try {
      if (editor.saveActive()) {
        _snack(context, 'Saved');
        return;
      }
    } catch (e) {
      _snack(context, 'Save failed: $e');
      return;
    }

    // Untitled buffer → save-as prompt.
    final path = await _promptSaveAsPath(context, tab);
    if (path == null || path.isEmpty) return;
    if (!context.mounted) return;
    try {
      FsService.writeFile(path, tab.content);
    } catch (e) {
      if (context.mounted) _snack(context, 'Save failed: $e');
      return;
    }
    final alreadyOpen = editor.tabs.any((t) => t.path == path);
    try {
      editor.openFile(path);
      if (alreadyOpen) editor.reloadTab(path);
    } catch (e) {
      if (context.mounted) _snack(context, 'Saved, but re-open failed: $e');
      return;
    }
    // Drop the untitled buffer (its content now lives at [path]).
    final idx = editor.tabs.indexOf(tab);
    if (idx != -1) editor.discardAndClose(idx);
    if (context.mounted) _snack(context, 'Saved');
  }

  /// Ctrl+Shift+S.
  static void saveAll(BuildContext context) {
    final n = context.read<EditorProvider>().saveAll();
    _snack(context, 'Saved $n file(s)');
  }

  /// Ctrl+W. Confirms before discarding a dirty tab.
  static Future<void> closeTab(BuildContext context) async {
    final editor = context.read<EditorProvider>();
    final i = editor.activeIndex;
    if (i < 0 || i >= editor.openCount) return;
    if (editor.closeTab(i)) return; // clean tab → closed directly
    final tab = editor.tabs[i];
    final discard = await _confirm(
      context,
      title: 'Unsaved changes',
      message: '"${tab.name}" has unsaved changes. Discard & close?',
      confirmLabel: 'Discard & Close',
    );
    if (discard) editor.discardAndClose(i);
  }

  // --------------------------------------------------------------- panels

  /// Ctrl+Shift+E / Ctrl+Shift+F / Ctrl+Shift+G. Opens the given left panel
  /// and guarantees the editor view is showing.
  static void showLeftPanel(BuildContext context, LeftPanelMode mode) {
    final ui = context.read<UiProvider>();
    if (ui.view != ViewMode.editor) ui.setView(ViewMode.editor);
    ui.setLeftPanelMode(mode); // also opens the sidebar
  }

  /// Ctrl+J as used from the View menu / activity bar: in the editor view it
  /// toggles the chat panel; from another view it switches to the editor and
  /// makes sure the panel is visible.
  static void toggleChatPanel(BuildContext context) {
    final ui = context.read<UiProvider>();
    if (ui.view != ViewMode.editor) {
      ui.setView(ViewMode.editor);
      if (!ui.rightPanelOpen) ui.toggleRightPanel();
    } else {
      ui.toggleRightPanel();
    }
  }

  /// Ctrl+` as used from the View menu / activity bar (guarded like above).
  static void toggleTerminalPanel(BuildContext context) {
    final ui = context.read<UiProvider>();
    if (ui.view != ViewMode.editor) {
      ui.setView(ViewMode.editor);
      ui.setTerminalOpen(true);
    } else {
      ui.toggleTerminal();
    }
  }

  // ------------------------------------------------------------- terminal

  /// Ctrl+Shift+K — starts a fresh shell session in the workspace root.
  static void newTerminal(BuildContext context) {
    final terminal = context.read<TerminalProvider>();
    final root = context.read<WorkspaceProvider>().rootPath;
    terminal.createSession(cwd: root);
    context.read<UiProvider>().setTerminalOpen(true);
  }

  // -------------------------------------------------------------------- run

  /// F5 — delegates to EditorProvider (main.dart wires the run command).
  static void runActiveFile(BuildContext context) {
    context.read<EditorProvider>().runActiveFile();
  }

  // -------------------------------------------------------------------- ai

  static void newChat(BuildContext context) {
    context.read<ChatProvider>().newSession();
  }

  // ---------------------------------------------------------------- folder

  /// Ctrl+O — folder picker → workspace + git binding → editor view.
  static Future<void> openFolder(BuildContext context) async {
    final path = await showOpenFolderDialog(context);
    if (path == null || path.isEmpty) return;
    if (!context.mounted) return;
    final workspace = context.read<WorkspaceProvider>();
    try {
      await workspace.openFolder(path);
    } catch (e) {
      if (context.mounted) _snack(context, 'Open folder failed: $e');
      return;
    }
    if (!context.mounted) return;
    // bindWorkspace() refreshes git status for the new root.
    context.read<GitProvider>().bindWorkspace(path);
    context.read<UiProvider>().setView(ViewMode.editor);
  }

  // ------------------------------------------------------------------ tabs

  static void nextTab(BuildContext context) {
    final editor = context.read<EditorProvider>();
    final n = editor.openCount;
    if (n == 0) return;
    editor.setActive((editor.activeIndex + 1) % n);
  }

  static void prevTab(BuildContext context) {
    final editor = context.read<EditorProvider>();
    final n = editor.openCount;
    if (n == 0) return;
    editor.setActive((editor.activeIndex - 1 + n) % n);
  }

  // ----------------------------------------------------------------- theme

  static void toggleTheme(BuildContext context) {
    final sp = context.read<SettingsProvider>();
    final next = sp.settings.themeMode == 'light' ? 'dark' : 'light';
    sp.update((s) => s.themeMode = next);
    context
        .read<UiProvider>()
        .setThemeMode(next == 'light' ? ThemeMode.light : ThemeMode.dark);
  }

  // ------------------------------------------------------------ internals

  static Future<String?> _promptSaveAsPath(
      BuildContext context, EditorTab tab) {
    final root = context.read<WorkspaceProvider>().rootPath;
    final initial =
        root == null || root.isEmpty ? tab.name : '$root${Platform.pathSeparator}${tab.name}';
    return showDialog<String>(
      context: context,
      builder: (dctx) => _SaveAsDialog(initialPath: initial),
    );
  }

  static Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dctx) {
        final c = dctx.read<UiProvider>().palette;
        return AlertDialog(
          backgroundColor: c.panelBackground,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: c.borderLight),
          ),
          title: Text(title,
              style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          content: Text(message,
              style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dctx, false),
              child: Text('Cancel',
                  style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dctx, true),
              child: Text(confirmLabel,
                  style: TextStyle(
                      color: c.error,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }
}

// ---------------------------------------------------------------------------
// Folder picker (dependency-free): a text field for the absolute path with
// inline validation.
// ---------------------------------------------------------------------------

Future<String?> showOpenFolderDialog(BuildContext context) {
  final initial = context.read<WorkspaceProvider>().rootPath ?? '';
  return showDialog<String>(
    context: context,
    builder: (dctx) => _FolderPickerDialog(initialPath: initial),
  );
}

InputDecoration _fieldDecoration(AppColors c, {String? hint}) => InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
          color: c.textSecondary, fontSize: 12.5, fontFamily: 'FiraCode'),
      filled: true,
      fillColor: c.background,
      isDense: true,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: c.borderLight)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: c.accent, width: 1.2)),
    );

class _FolderPickerDialog extends StatefulWidget {
  final String initialPath;
  const _FolderPickerDialog({required this.initialPath});

  @override
  State<_FolderPickerDialog> createState() => _FolderPickerDialogState();
}

class _FolderPickerDialogState extends State<_FolderPickerDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialPath);
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _open() {
    final path = _controller.text.trim();
    if (path.isEmpty) {
      setState(() => _error = 'Enter a folder path.');
      return;
    }
    if (!Directory(path).existsSync()) {
      setState(() => _error = 'Folder does not exist: $path');
      return;
    }
    Navigator.pop(context, path);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.read<UiProvider>().palette;
    return AlertDialog(
      backgroundColor: c.panelBackground,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: c.borderLight),
      ),
      title: Text('Open Folder',
          style: TextStyle(
              color: c.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600)),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Absolute folder path',
                style: TextStyle(color: c.textSecondary, fontSize: 11.5)),
            const SizedBox(height: 6),
            TextField(
              controller: _controller,
              autofocus: true,
              style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 12.5,
                  fontFamily: 'FiraCode'),
              decoration: _fieldDecoration(c, hint: '/home/you/project'),
              onSubmitted: (_) => _open(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: c.error, fontSize: 11.5)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel',
              style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
        ),
        FilledButton(
          onPressed: _open,
          style: FilledButton.styleFrom(
            backgroundColor: c.accent,
            foregroundColor: c.textOnAccent,
            textStyle: const TextStyle(fontSize: 12.5),
          ),
          child: const Text('Open'),
        ),
      ],
    );
  }
}

class _SaveAsDialog extends StatefulWidget {
  final String initialPath;
  const _SaveAsDialog({required this.initialPath});

  @override
  State<_SaveAsDialog> createState() => _SaveAsDialogState();
}

class _SaveAsDialogState extends State<_SaveAsDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialPath);
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final path = _controller.text.trim();
    if (path.isEmpty) {
      setState(() => _error = 'Enter a file path.');
      return;
    }
    final sep = path.lastIndexOf(Platform.pathSeparator);
    if (sep > 0) {
      final parent = path.substring(0, sep);
      if (!Directory(parent).existsSync()) {
        setState(() => _error = 'Folder does not exist: $parent');
        return;
      }
    }
    Navigator.pop(context, path);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.read<UiProvider>().palette;
    return AlertDialog(
      backgroundColor: c.panelBackground,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: c.borderLight),
      ),
      title: Text('Save As',
          style: TextStyle(
              color: c.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600)),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('File path (absolute or workspace-relative)',
                style: TextStyle(color: c.textSecondary, fontSize: 11.5)),
            const SizedBox(height: 6),
            TextField(
              controller: _controller,
              autofocus: true,
              style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 12.5,
                  fontFamily: 'FiraCode'),
              decoration: _fieldDecoration(c, hint: 'path/to/file.dart'),
              onSubmitted: (_) => _save(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: c.error, fontSize: 11.5)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel',
              style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
        ),
        FilledButton(
          onPressed: _save,
          style: FilledButton.styleFrom(
            backgroundColor: c.accent,
            foregroundColor: c.textOnAccent,
            textStyle: const TextStyle(fontSize: 12.5),
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// The palette dialog itself.
// ---------------------------------------------------------------------------

class CommandPaletteDialog extends StatefulWidget {
  final List<CommandItem> commands;
  const CommandPaletteDialog({super.key, required this.commands});

  @override
  State<CommandPaletteDialog> createState() => _CommandPaletteDialogState();
}

class _CommandPaletteDialogState extends State<CommandPaletteDialog> {
  static const double _rowHeight = 32;

  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  String _query = '';
  int _selected = 0;

  @override
  void initState() {
    super.initState();
    _input.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _input.removeListener(_onQueryChanged);
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    setState(() {
      _query = _input.text;
      _selected = 0;
    });
    _ensureSelectionVisible();
  }

  List<CommandItem> get _visible {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.commands;
    return widget.commands
        .where((cmd) =>
            _fuzzyMatch(q, '${cmd.title} ${cmd.shortcut ?? ''}'.toLowerCase()))
        .toList();
  }

  /// Case-insensitive subsequence match.
  static bool _fuzzyMatch(String query, String text) {
    if (query.isEmpty) return true;
    var qi = 0;
    for (var i = 0; i < text.length && qi < query.length; i++) {
      if (text.codeUnitAt(i) == query.codeUnitAt(qi)) qi++;
    }
    return qi == query.length;
  }

  void _move(int delta) {
    final n = _visible.length;
    if (n == 0) return;
    setState(() => _selected = (_selected + delta + n) % n);
    _ensureSelectionVisible();
  }

  void _submit() {
    final list = _visible;
    if (_selected >= 0 && _selected < list.length) {
      // The ONLY pop (audit fix #1) — the caller runs the command later.
      Navigator.pop(context, list[_selected]);
    }
  }

  void _dismiss() => Navigator.pop(context, null);

  void _ensureSelectionVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final pos = _scroll.position;
      final rowTop = _selected * _rowHeight;
      final rowBottom = rowTop + _rowHeight;
      if (rowTop < pos.pixels) {
        pos.jumpTo(rowTop.clamp(0.0, pos.maxScrollExtent));
      } else if (rowBottom > pos.pixels + pos.viewportDimension) {
        pos.jumpTo((rowBottom - pos.viewportDimension)
            .clamp(0.0, pos.maxScrollExtent));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.read<UiProvider>().palette;
    final list = _visible;
    final sel = list.isEmpty ? 0 : _selected.clamp(0, list.length - 1);

    return Dialog(
      alignment: Alignment.topCenter,
      insetPadding: const EdgeInsets.fromLTRB(16, 60, 16, 24),
      backgroundColor: c.panelBackground,
      elevation: 8,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: c.borderLight),
      ),
      child: SizedBox(
        width: 560,
        child: Focus(
          skipTraversal: true,
          onKeyEvent: (node, event) {
            if (event is KeyUpEvent) return KeyEventResult.ignored;
            final key = event.logicalKey;
            if (key == LogicalKeyboardKey.arrowDown) {
              _move(1);
              return KeyEventResult.handled;
            }
            if (key == LogicalKeyboardKey.arrowUp) {
              _move(-1);
              return KeyEventResult.handled;
            }
            if (event is KeyDownEvent) {
              if (key == LogicalKeyboardKey.escape) {
                _dismiss();
                return KeyEventResult.handled;
              }
              if (key == LogicalKeyboardKey.enter) {
                _submit();
                return KeyEventResult.handled;
              }
            }
            return KeyEventResult.ignored;
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _input,
                autofocus: true,
                style: TextStyle(color: c.textPrimary, fontSize: 13.5),
                decoration: InputDecoration(
                  hintText: 'Type a command…',
                  hintStyle:
                      TextStyle(color: c.textSecondary, fontSize: 13.5),
                  prefixIcon:
                      Icon(Icons.search, size: 16, color: c.textSecondary),
                  filled: true,
                  fillColor: c.background,
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
                ),
                onSubmitted: (_) => _submit(),
              ),
              Container(height: 1, color: c.border),
              ConstrainedBox(
                constraints:
                    const BoxConstraints(minHeight: 40, maxHeight: 320),
                child: list.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 16),
                        child: Text('No matching commands',
                            style: TextStyle(
                                color: c.textSecondary, fontSize: 12.5)),
                      )
                    : ListView.builder(
                        controller: _scroll,
                        shrinkWrap: true,
                        itemExtent: _rowHeight,
                        itemCount: list.length,
                        itemBuilder: (ctx, i) => _buildRow(ctx, c, list[i], i == sel),
                      ),
              ),
              Container(height: 1, color: c.border),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 7, 14, 9),
                child: Text('↑↓ navigate · Enter select · Esc close',
                    style: TextStyle(
                        color: c.textSecondary.withValues(alpha: 0.9),
                        fontSize: 10.5)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(
      BuildContext ctx, AppColors c, CommandItem cmd, bool selected) {
    return InkWell(
      onTap: () => Navigator.pop(ctx, cmd),
      hoverColor: Colors.transparent,
      onHover: (hover) {
        if (hover && !selected) setState(() => _selected = _visible.indexOf(cmd));
      },
      child: Container(
        height: _rowHeight,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        color: selected ? c.accentSoft : Colors.transparent,
        child: Row(
          children: [
            Expanded(
              child: Text(
                cmd.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                ),
              ),
            ),
            const SizedBox(width: 12),
            if (cmd.shortcut != null)
              Text(
                cmd.shortcut!,
                style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 11,
                    fontFamily: 'FiraCode'),
              ),
          ],
        ),
      ),
    );
  }
}
