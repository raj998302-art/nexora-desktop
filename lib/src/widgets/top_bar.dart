// NEXORA — top bar: app glyph, menu bar, center search pill (command palette
// entry point + drag zone) and window controls.
//
// Audit fixes: #5 (palette colors only — no hardcoded white), #13 (menu
// shortcut labels match the global bindings exactly).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import '../providers/editor_provider.dart';
import '../providers/ui_provider.dart';
import '../theme/app_colors.dart';
import 'command_palette.dart';

class TopBar extends StatelessWidget {
  const TopBar({super.key});

  static const List<_MenuEntry> _fileMenu = [
    _MenuEntry('file.new', 'New File', 'Ctrl+N'),
    _MenuEntry('file.openFolder', 'Open Folder…', 'Ctrl+O'),
    _MenuEntry.divider(),
    _MenuEntry('file.save', 'Save', 'Ctrl+S'),
    _MenuEntry('file.saveAll', 'Save All', 'Ctrl+Shift+S'),
    _MenuEntry('file.closeTab', 'Close Tab', 'Ctrl+W'),
    _MenuEntry.divider(),
    _MenuEntry('file.exit', 'Exit'),
  ];

  static const List<_MenuEntry> _editMenu = [
    _MenuEntry('edit.findInFiles', 'Find in Files', 'Ctrl+Shift+F'),
    _MenuEntry('edit.replaceAll', 'Replace All…', null, false),
  ];

  static const List<_MenuEntry> _selectionMenu = [
    _MenuEntry('sel.selectAll', 'Select All', 'Ctrl+A', false),
  ];

  static const List<_MenuEntry> _viewMenu = [
    _MenuEntry('view.explorer', 'Explorer', 'Ctrl+Shift+E'),
    _MenuEntry('view.search', 'Search', 'Ctrl+Shift+F'),
    _MenuEntry('view.git', 'Source Control', 'Ctrl+Shift+G'),
    _MenuEntry('view.chat', 'AI Chat', 'Ctrl+J'),
    _MenuEntry('view.terminal', 'Terminal', 'Ctrl+`'),
    _MenuEntry.divider(),
    _MenuEntry('view.theme', 'Toggle Theme'),
    _MenuEntry('view.settings', 'Settings'),
  ];

  static const List<_MenuEntry> _goMenu = [
    _MenuEntry('go.home', 'Home'),
    _MenuEntry('go.nextTab', 'Next Tab'),
    _MenuEntry('go.prevTab', 'Previous Tab'),
    _MenuEntry.divider(),
    _MenuEntry('go.palette', 'Command Palette', 'Ctrl+Shift+P'),
  ];

  static const List<_MenuEntry> _runMenu = [
    _MenuEntry('run.activeFile', 'Run Active File', 'F5'),
  ];

  static const List<_MenuEntry> _terminalMenu = [
    _MenuEntry('terminal.new', 'New Terminal', 'Ctrl+Shift+K'),
  ];

  static const List<_MenuEntry> _helpMenu = [
    _MenuEntry('help.about', 'About NEXORA'),
  ];

  void _onMenuSelected(BuildContext context, String id) {
    switch (id) {
      case 'file.new':
        context.read<EditorProvider>().openUntitled();
        break;
      case 'file.openFolder':
        NxActions.openFolder(context);
        break;
      case 'file.save':
        NxActions.save(context);
        break;
      case 'file.saveAll':
        NxActions.saveAll(context);
        break;
      case 'file.closeTab':
        NxActions.closeTab(context);
        break;
      case 'file.exit':
        windowManager.close();
        break;
      case 'edit.findInFiles':
        NxActions.showLeftPanel(context, LeftPanelMode.search);
        break;
      case 'view.explorer':
        NxActions.showLeftPanel(context, LeftPanelMode.explorer);
        break;
      case 'view.search':
        NxActions.showLeftPanel(context, LeftPanelMode.search);
        break;
      case 'view.git':
        NxActions.showLeftPanel(context, LeftPanelMode.git);
        break;
      case 'view.chat':
        NxActions.toggleChatPanel(context);
        break;
      case 'view.terminal':
        NxActions.toggleTerminalPanel(context);
        break;
      case 'view.theme':
        NxActions.toggleTheme(context);
        break;
      case 'view.settings':
        context.read<UiProvider>().setView(ViewMode.settings);
        break;
      case 'go.home':
        context.read<UiProvider>().setView(ViewMode.home);
        break;
      case 'go.nextTab':
        NxActions.nextTab(context);
        break;
      case 'go.prevTab':
        NxActions.prevTab(context);
        break;
      case 'go.palette':
        showCommandPalette(context);
        break;
      case 'run.activeFile':
        NxActions.runActiveFile(context);
        break;
      case 'terminal.new':
        NxActions.newTerminal(context);
        break;
      case 'help.about':
        _showAbout(context);
        break;
    }
  }

  void _showAbout(BuildContext context) {
    final c = context.read<UiProvider>().palette;
    showDialog<void>(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: c.panelBackground,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: c.borderLight),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, size: 18, color: c.blueLight),
            const SizedBox(width: 8),
            Text('NEXORA',
                style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Version 1.0.0',
                style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 12,
                    fontFamily: 'monospace')),
            const SizedBox(height: 6),
            Text('AI-native coding environment',
                style: TextStyle(color: c.textPrimary, fontSize: 12.5)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx),
            child: Text('Close',
                style: TextStyle(color: c.accent, fontSize: 12.5)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<UiProvider>().palette;
    return Container(
      height: 35,
      decoration: BoxDecoration(
        color: c.background,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 10, right: 4),
            child: Icon(Icons.auto_awesome, size: 15, color: c.blueLight),
          ),
          _MenuButton(
              label: 'File',
              entries: _fileMenu,
              onSelected: (id) => _onMenuSelected(context, id)),
          _MenuButton(
              label: 'Edit',
              entries: _editMenu,
              onSelected: (id) => _onMenuSelected(context, id)),
          _MenuButton(
              label: 'Selection',
              entries: _selectionMenu,
              onSelected: (id) => _onMenuSelected(context, id)),
          _MenuButton(
              label: 'View',
              entries: _viewMenu,
              onSelected: (id) => _onMenuSelected(context, id)),
          _MenuButton(
              label: 'Go',
              entries: _goMenu,
              onSelected: (id) => _onMenuSelected(context, id)),
          _MenuButton(
              label: 'Run',
              entries: _runMenu,
              onSelected: (id) => _onMenuSelected(context, id)),
          _MenuButton(
              label: 'Terminal',
              entries: _terminalMenu,
              onSelected: (id) => _onMenuSelected(context, id)),
          _MenuButton(
              label: 'Help',
              entries: _helpMenu,
              onSelected: (id) => _onMenuSelected(context, id)),
          // ---- Middle: drag zone + command palette pill ------------------
          Expanded(
            child: Stack(
              children: [
                // Only the EMPTY middle zone drags the window; the pill sits
                // above and keeps its own clicks.
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onDoubleTap: () => windowManager.startDragging(),
                    child: const SizedBox.expand(),
                  ),
                ),
                Center(child: _searchPill(context, c)),
              ],
            ),
          ),
          // ---- Window controls --------------------------------------------
          _WindowButton(
            icon: Icons.horizontal_rule,
            tooltip: 'Minimize',
            onTap: () => windowManager.minimize(),
          ),
          _WindowButton(
            icon: Icons.crop_square,
            tooltip: 'Maximize / Restore',
            onTap: () async {
              final maximized = await windowManager.isMaximized();
              if (maximized) {
                await windowManager.unmaximize();
              } else {
                await windowManager.maximize();
              }
            },
          ),
          _WindowButton(
            icon: Icons.close,
            tooltip: 'Close',
            isClose: true,
            onTap: () => windowManager.close(),
          ),
        ],
      ),
    );
  }

  Widget _searchPill(BuildContext context, AppColors c) {
    return SizedBox(
      width: 240,
      height: 26,
      child: Container(
        decoration: BoxDecoration(
          color: c.panelBackground,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: c.borderLight),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(13),
          child: InkWell(
            borderRadius: BorderRadius.circular(13),
            hoverColor: c.accentSoft,
            onTap: () => showCommandPalette(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  Icon(Icons.search, size: 13, color: c.textSecondary),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'NEXORA · Ctrl+K',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(color: c.textSecondary, fontSize: 11.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Menu model + trigger button.
// ---------------------------------------------------------------------------

class _MenuEntry {
  final String id;
  final String label;
  final String? shortcut;
  final bool enabled;
  final bool divider;

  const _MenuEntry(this.id, this.label, [this.shortcut, this.enabled = true])
      : divider = false;

  const _MenuEntry.divider()
      : id = '',
        label = '',
        shortcut = null,
        enabled = false,
        divider = true;
}

class _MenuButton extends StatelessWidget {
  final String label;
  final List<_MenuEntry> entries;
  final ValueChanged<String> onSelected;

  const _MenuButton({
    required this.label,
    required this.entries,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.watch<UiProvider>().palette;
    return Theme(
      data: Theme.of(context).copyWith(
        brightness: c.brightness,
        hoverColor: c.panelBackground,
        colorScheme: Theme.of(context).colorScheme.copyWith(
              brightness: c.brightness,
              surface: c.panelBackground,
              onSurface: c.textPrimary,
              primary: c.accent,
            ),
        popupMenuTheme: PopupMenuThemeData(
          color: c.panelBackground,
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(7),
            side: BorderSide(color: c.borderLight),
          ),
          textStyle: TextStyle(
              color: c.textPrimary, fontSize: 12.5, fontFamily: 'Segoe UI'),
        ),
      ),
      child: PopupMenuButton<String>(
        position: PopupMenuPosition.under,
        offset: const Offset(0, 2),
        tooltip: '$label menu',
        onSelected: onSelected,
        itemBuilder: (popupCtx) => [
          for (final e in entries)
            if (e.divider)
              const PopupMenuDivider()
            else
              PopupMenuItem<String>(
                value: e.id,
                height: 32,
                enabled: e.enabled,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    SizedBox(
                      width: 168,
                      child: Text(
                        e.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color:
                              e.enabled ? c.textPrimary : c.textSecondary,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 96,
                      child: Text(
                        e.shortcut ?? '',
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: c.textSecondary,
                            fontSize: 11,
                            fontFamily: 'monospace'),
                      ),
                    ),
                  ],
                ),
              ),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
          child: Text(label,
              style: TextStyle(color: c.textPrimary, fontSize: 12)),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Window control buttons (40x35 zones, red hover on close).
// ---------------------------------------------------------------------------

class _WindowButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool isClose;

  const _WindowButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.isClose = false,
  });

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = context.read<UiProvider>().palette;
    final hoverBg =
        widget.isClose ? const Color(0xFFC42B1C) : c.panelBackground;
    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 600),
      child: MouseRegion(
        onEnter: (event) => setState(() => _hover = true),
        onExit: (event) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: Container(
            width: 40,
            height: 35,
            color: _hover ? hoverBg : Colors.transparent,
            child: Icon(
              widget.icon,
              size: 16,
              color: _hover && widget.isClose ? c.textOnAccent : c.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
