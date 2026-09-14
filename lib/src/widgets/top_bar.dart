// NEXORA — top bar (Web Prototype TopBar.tsx): 36px bar on #181818 with a
// #2b2b2b bottom border — menu bar (left), command-palette search pill
// (center), action cluster + Windows controls (right). The bar's EMPTY areas
// are a window drag region (Stack: background GestureDetector + interactive
// Row on top) — clicks on the children still work.
//
// Audit fixes kept: #5 (palette colors only — no hardcoded white), #13 (menu
// shortcut labels match the global bindings exactly).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import '../providers/editor_provider.dart';
import '../providers/ui_provider.dart';
import '../theme/app_colors.dart';
import 'command_palette.dart';
import 'nexora_ui.dart';

/// Prototype `text-white` on a dark surface: pure white in dark mode, the
/// palette's readable dark text in light mode (audit #5 — never invisible).
Color _brightText(AppColors c) =>
    c.brightness == Brightness.dark ? c.textOnAccent : c.textPrimary;

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
                    fontFamily: 'FiraCode')),
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
    final ui = context.watch<UiProvider>();
    final c = ui.palette;

    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: c.activityBar,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Stack(
        children: [
          // ---- Window drag region (EMPTY areas only) ----------------------
          // Sits BELOW the interactive row: the Row's children absorb their
          // own pointer events, everything else (padding strips, gaps, the
          // space around the pill) starts a native window drag.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (_) => windowManager.startDragging(),
              onDoubleTap: () async {
                final maximized = await windowManager.isMaximized();
                if (maximized) {
                  await windowManager.unmaximize();
                } else {
                  await windowManager.maximize();
                }
              },
              child: const SizedBox.expand(),
            ),
          ),
          // ---- Interactive content ----------------------------------------
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(Icons.menu, size: 14, color: c.textPrimary),
                const SizedBox(width: 12),
                _MenuButton(
                    label: 'File',
                    entries: _fileMenu,
                    onSelected: (id) => _onMenuSelected(context, id)),
                const SizedBox(width: 12),
                _MenuButton(
                    label: 'Edit',
                    entries: _editMenu,
                    onSelected: (id) => _onMenuSelected(context, id)),
                const SizedBox(width: 12),
                _MenuButton(
                    label: 'Selection',
                    entries: _selectionMenu,
                    onSelected: (id) => _onMenuSelected(context, id)),
                const SizedBox(width: 12),
                _MenuButton(
                    label: 'View',
                    entries: _viewMenu,
                    onSelected: (id) => _onMenuSelected(context, id)),
                const SizedBox(width: 12),
                _MenuButton(
                    label: 'Go',
                    entries: _goMenu,
                    onSelected: (id) => _onMenuSelected(context, id)),
                const SizedBox(width: 12),
                _MenuButton(
                    label: 'Run',
                    entries: _runMenu,
                    onSelected: (id) => _onMenuSelected(context, id)),
                const SizedBox(width: 12),
                _MenuButton(
                    label: 'Terminal',
                    entries: _terminalMenu,
                    onSelected: (id) => _onMenuSelected(context, id)),
                const SizedBox(width: 12),
                _MenuButton(
                    label: 'Help',
                    entries: _helpMenu,
                    onSelected: (id) => _onMenuSelected(context, id)),
                // ---- Center: command palette pill --------------------------
                Expanded(
                  child: Center(child: _searchPill(context, c)),
                ),
                // ---- Right: actions + window controls ----------------------
                NexoraIconButton(
                  icon: ui.themeMode == ThemeMode.light
                      ? Icons.dark_mode
                      : Icons.light_mode,
                  size: 14,
                  tooltip: 'Toggle Theme',
                  onPressed: () => NxActions.toggleTheme(context),
                ),
                const SizedBox(width: 4),
                _BellButton(),
                const SizedBox(width: 6),
                _VBar(color: c.borderLight),
                const SizedBox(width: 6),
                if (ui.agentRunning)
                  NexoraTintButton.stop(
                    icon: Icons.stop,
                    onPressed: () => ui.setAgentRunning(false),
                    child: const Text('Stop'),
                  )
                else
                  NexoraTintButton.agent(
                    icon: Icons.play_arrow,
                    onPressed: () => ui.setAgentRunning(true),
                    child: const Text('Agent'),
                  ),
                const SizedBox(width: 6),
                _VBar(color: c.borderLight),
                const SizedBox(width: 6),
                NexoraIconButton(
                  icon: Icons.dashboard_outlined,
                  size: 14,
                  tooltip: 'Panel Layout',
                  onPressed: () => ui.toggleRightPanel(),
                ),
                const SizedBox(width: 4),
                _WindowButton(
                  icon: Icons.remove,
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
          ),
        ],
      ),
    );
  }

  /// Prototype search pill: max-w-sm (384), bg #2a2d2e, border #3c3c3c,
  /// rounded-md, Search 12 + "NEXORA (⌘K)" 12 medium #858585, hover #333,
  /// click opens the command palette (single-pop contract).
  Widget _searchPill(BuildContext context, AppColors c) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 384),
      child: SizedBox(
        height: 26,
        width: double.infinity,
        child: _PillButton(c: c, onTap: () => showCommandPalette(context)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Menu model + trigger button (prototype styling).
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

/// Menu trigger: 12px #cccccc, hover white on #2a2d2e rounded 4.
class _MenuButton extends StatefulWidget {
  final String label;
  final List<_MenuEntry> entries;
  final ValueChanged<String> onSelected;

  const _MenuButton({
    required this.label,
    required this.entries,
    required this.onSelected,
  });

  @override
  State<_MenuButton> createState() => _MenuButtonState();
}

class _MenuButtonState extends State<_MenuButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<UiProvider>().palette;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: NxMotion.fast,
        curve: NxMotion.curve,
        decoration: BoxDecoration(
          color: _hover ? c.inputBackground : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(
            brightness: c.brightness,
            hoverColor: Colors.transparent,
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  brightness: c.brightness,
                  surface: c.panelBackground,
                  onSurface: c.textPrimary,
                  primary: c.accent,
                ),
            popupMenuTheme: PopupMenuThemeData(
              color: c.panelBackground,
              elevation: 8,
              menuPadding: const EdgeInsets.symmetric(vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
                side: BorderSide(color: c.borderLight),
              ),
            ),
          ),
          child: PopupMenuButton<String>(
            position: PopupMenuPosition.under,
            offset: const Offset(0, 7),
            tooltip: '${widget.label} menu',
            onSelected: widget.onSelected,
            itemBuilder: (popupCtx) => [
              for (final e in widget.entries)
                if (e.divider)
                  PopupMenuDivider(height: 10, color: c.border)
                else
                  PopupMenuItem<String>(
                    value: e.id,
                    height: 30,
                    enabled: e.enabled,
                    padding: EdgeInsets.zero,
                    child: _MenuItemRow(entry: e),
                  ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                widget.label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: _hover ? _brightText(c) : c.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One popup row: height 30, px-12, 13px label + right-aligned 11px mono
/// shortcut, hover fill #37373d across the full item width.
class _MenuItemRow extends StatefulWidget {
  final _MenuEntry entry;
  const _MenuItemRow({required this.entry});

  @override
  State<_MenuItemRow> createState() => _MenuItemRowState();
}

class _MenuItemRowState extends State<_MenuItemRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<UiProvider>().palette;
    final e = widget.entry;
    return SizedBox(
      width: double.infinity,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: AnimatedContainer(
          duration: NxMotion.fast,
          curve: NxMotion.curve,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          color: _hover && e.enabled ? c.selectedBackground : Colors.transparent,
          child: Row(
            children: [
              SizedBox(
                width: 168,
                child: Text(
                  e.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: e.enabled ? c.textPrimary : c.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 92,
                child: Text(
                  e.shortcut ?? '',
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'FiraCode',
                    fontSize: 11,
                    color: c.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Center pill.
// ---------------------------------------------------------------------------

class _PillButton extends StatefulWidget {
  final AppColors c;
  final VoidCallback onTap;
  const _PillButton({required this.c, required this.onTap});

  @override
  State<_PillButton> createState() => _PillButtonState();
}

class _PillButtonState extends State<_PillButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: NxMotion.fast,
          curve: NxMotion.curve,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: _hover ? c.hoverBackground : c.inputBackground,
            border: Border.all(color: c.borderLight),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(Icons.search, size: 12, color: c.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'NEXORA (⌘K)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: c.textSecondary,
                  ),
                ),
              ),
              // Balance the leading icon+gap so the label is pill-centered.
              const SizedBox(width: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bell with the 8px blue-500 notification dot (prototype: -top-1 -right-1).
// ---------------------------------------------------------------------------

class _BellButton extends StatefulWidget {
  const _BellButton();

  @override
  State<_BellButton> createState() => _BellButtonState();
}

class _BellButtonState extends State<_BellButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<UiProvider>().palette;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: SizedBox(
        width: 22,
        height: 22,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(
              child: Icon(
                Icons.notifications_none,
                size: 14,
                color: _hover ? _brightText(c) : c.textSecondary,
              ),
            ),
            Positioned(
              top: -1,
              right: -1,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: c.blue500,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Vertical divider between right-cluster groups (1×16 #3c3c3c).
class _VBar extends StatelessWidget {
  final Color color;
  const _VBar({required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 1,
      height: 16,
      child: ColoredBox(color: color),
    );
  }
}

// ---------------------------------------------------------------------------
// Window control buttons: 40×36 hover zones (#333, red-500 on close), 16px
// #858585 icons that turn white on hover.
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
    final hoverBg = widget.isClose ? c.red500 : c.hoverBackground;
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
            height: 36,
            color: _hover ? hoverBg : Colors.transparent,
            child: Icon(
              widget.icon,
              size: 16,
              color: _hover
                  ? (widget.isClose ? c.textOnAccent : _brightText(c))
                  : c.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
