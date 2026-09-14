// NEXORA — embedded terminal pane. Real shell sessions (spawned by
// TerminalProvider) rendered as a scrollback of lines plus a per-session
// input row. IMPORTANT: the parent workspace owns this pane's height (it is
// wrapped in a SizedBox driven by UiProvider.terminalHeight) — this widget
// only fills the box it is given.
//
// Visual language ported from the Web Prototype: VS Code-style panel header
// (PROBLEMS / OUTPUT / DEBUG CONSOLE / TERMINAL / PORTS, TERMINAL active with
// a 2px blue-500 underline), shell-chip session switcher, FiraCode 13px body
// with a colored user@nexora:~$ prompt, and a matching input row.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/terminal_provider.dart';
import '../providers/ui_provider.dart';
import '../providers/workspace_provider.dart';
import '../theme/app_colors.dart';

/// The bottom terminal panel. Fills the height provided by the parent.
class TerminalPane extends StatefulWidget {
  const TerminalPane({super.key});

  @override
  State<TerminalPane> createState() => _TerminalPaneState();
}

class _TerminalPaneState extends State<TerminalPane> {
  late final TerminalProvider _term;
  final ScrollController _scroll = ScrollController();
  final FocusNode _inputFocus = FocusNode();

  /// One input controller per session id, so typed-but-unsent text survives
  /// switching between terminal tabs.
  final Map<String, TextEditingController> _inputs = {};
  String? _lastActiveId;

  @override
  void initState() {
    super.initState();
    _term = context.read<TerminalProvider>();
    _term.addListener(_onTermChanged);
    _lastActiveId = _term.active?.id;
  }

  @override
  void dispose() {
    _term.removeListener(_onTermChanged);
    _inputFocus.dispose();
    _scroll.dispose();
    for (final controller in _inputs.values) {
      controller.dispose();
    }
    _inputs.clear();
    super.dispose();
  }

  void _onTermChanged() {
    final active = _term.active;
    final switched = active?.id != _lastActiveId;
    _lastActiveId = active?.id;

    if (switched) {
      // Focus follows the newly active session's input line.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _inputFocus.requestFocus();
      });
    }

    // Stick to the bottom while output streams in — unless the user has
    // scrolled up to read. Metrics are read pre-layout, i.e. against the
    // extent before the new lines land.
    final wasNearBottom = !_scroll.hasClients ||
        (_scroll.position.maxScrollExtent - _scroll.position.pixels) < 80;
    if (switched || wasNearBottom) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scroll.hasClients) return;
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      });
    }
  }

  TextEditingController _controllerFor(TerminalSession session) =>
      _inputs.putIfAbsent(session.id, TextEditingController.new);

  void _createSession() {
    _term.createSession(cwd: context.read<WorkspaceProvider>().rootPath);
  }

  void _toggleMaximize() {
    final ui = context.read<UiProvider>();
    ui.setTerminalHeight(ui.terminalHeight < 400 ? 600 : 256);
  }

  // ----------------------------------------------------------------- layout

  @override
  Widget build(BuildContext context) {
    final term = context.watch<TerminalProvider>();
    final c = context.watch<UiProvider>().palette;
    final active = term.active;

    return Container(
      color: c.background,
      child: Column(
        children: [
          _buildHeader(term, c),
          Expanded(
            child: (term.sessions.isEmpty || active == null)
                ? Center(
                    child: Text(
                      'No terminal — create one (+)',
                      style:
                          TextStyle(fontSize: 11, color: c.textSecondary),
                    ),
                  )
                : Column(
                    children: [
                      Expanded(child: _buildOutput(active, c)),
                      _buildInput(active, c),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(TerminalProvider term, AppColors c) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: c.activityBar,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          // LEFT: panel tabs (PROBLEMS/OUTPUT/DEBUG CONSOLE/TERMINAL/PORTS).
          // Only TERMINAL is real — the rest are display-only mock tabs, and
          // the TERMINAL tab is a no-op because this pane IS the terminal.
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const _PanelTab(label: 'PROBLEMS', badge: '0'),
                  const _PanelTab(label: 'OUTPUT'),
                  const _PanelTab(label: 'DEBUG CONSOLE'),
                  const _PanelTab(label: 'TERMINAL', active: true),
                  const _PanelTab(label: 'PORTS'),
                ],
              ),
            ),
          ),
          // RIGHT: shell chips (session switcher) + action icons.
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0;
                      i < term.sessions.length && i < 4;
                      i++)
                    _buildSessionChip(term, i, c),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          _HeaderIcon(
            icon: Icons.add,
            tooltip: 'New terminal session',
            palette: c,
            onTap: _createSession,
          ),
          _HeaderIcon(
            icon: Icons.vertical_split,
            tooltip: 'Split terminal',
            palette: c,
            onTap: () {}, // mock
          ),
          _HeaderIcon(
            icon: Icons.delete_outline,
            tooltip: 'Kill active process',
            palette: c,
            onTap: () => term.active?.kill(),
          ),
          Container(
            width: 1,
            height: 16,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            color: c.borderLight,
          ),
          _HeaderIcon(
            icon: Icons.web_asset,
            tooltip: 'Maximize terminal',
            palette: c,
            onTap: _toggleMaximize,
          ),
          _HeaderIcon(
            icon: Icons.expand_more,
            tooltip: 'Hide terminal panel',
            palette: c,
            onTap: () => context.read<UiProvider>().setTerminalOpen(false),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionChip(TerminalProvider term, int index, AppColors c) {
    final session = term.sessions[index];
    final isActive = index == term.activeIndex;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => term.setActive(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 24,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: c.inputBackground,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isActive
                    ? c.blue500.withValues(alpha: 0.5)
                    : c.borderLight,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.terminal,
                    size: 12,
                    color: isActive ? c.textPrimary : c.textSecondary),
                const SizedBox(width: 4),
                Text(
                  session.title.toLowerCase(),
                  style: TextStyle(fontSize: 12, color: c.textPrimary),
                ),
                const SizedBox(width: 6),
                Tooltip(
                  message: 'Close session',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => term.closeSession(index),
                    child: Icon(Icons.close, size: 10, color: c.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOutput(TerminalSession session, AppColors c) {
    return GestureDetector(
      // Clicking the scrollback moves focus to the input line, like a real
      // terminal.
      behavior: HitTestBehavior.opaque,
      onTap: _inputFocus.requestFocus,
      child: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.all(16),
        itemCount: session.lines.length,
        itemBuilder: (context, index) {
          return _buildTermLine(session.lines[index], c);
        },
      ),
    );
  }

  /// One scrollback line. Echoed input lines (our provider writes them as
  /// `'\$ …'`) are rendered with the prototype's colored prompt; stderr is
  /// red; everything else is the default terminal text.
  Widget _buildTermLine(TermLine line, AppColors c) {
    final white =
        c.brightness == Brightness.dark ? c.textOnAccent : c.textPrimary;
    final base = TextStyle(
      fontFamily: 'FiraCode',
      fontSize: 13,
      height: 1.6,
      color: line.isStderr ? c.red400 : c.textPrimary,
    );
    if (!line.isStderr && line.text.startsWith(r'$ ')) {
      return Text.rich(
        TextSpan(
          style: base,
          children: [
            TextSpan(
              text: 'user@nexora',
              style: TextStyle(color: c.green400, fontWeight: FontWeight.w700),
            ),
            TextSpan(text: ':', style: TextStyle(color: white)),
            TextSpan(
              text: '~',
              style: TextStyle(color: c.blue400, fontWeight: FontWeight.w700),
            ),
            TextSpan(text: r'$', style: TextStyle(color: white)),
            TextSpan(
              text: ' ${line.text.substring(2)}',
              style: TextStyle(color: white),
            ),
          ],
        ),
        softWrap: true,
        overflow: TextOverflow.clip,
      );
    }
    return Text(
      line.text,
      softWrap: true,
      overflow: TextOverflow.clip,
      style: base,
    );
  }

  Widget _buildInput(TerminalSession session, AppColors c) {
    final controller = _controllerFor(session);
    final white =
        c.brightness == Brightness.dark ? c.textOnAccent : c.textPrimary;
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: c.background,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          Text.rich(
            TextSpan(
              style: const TextStyle(
                fontFamily: 'FiraCode',
                fontSize: 12,
                height: 1.6,
              ),
              children: [
                TextSpan(
                  text: 'user@nexora',
                  style:
                      TextStyle(color: c.green400, fontWeight: FontWeight.w700),
                ),
                TextSpan(text: ':', style: TextStyle(color: white)),
                TextSpan(
                  text: '~',
                  style:
                      TextStyle(color: c.blue400, fontWeight: FontWeight.w700),
                ),
                TextSpan(text: r'$', style: TextStyle(color: white)),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: _inputFocus,
              autofocus: true,
              cursorColor: c.blue400,
              style: TextStyle(
                fontSize: 13,
                fontFamily: 'FiraCode',
                height: 1.6,
                color: c.textPrimary,
              ),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 6),
              ),
              onSubmitted: (value) {
                _term.sendInput(value);
                controller.clear();
                _inputFocus.requestFocus();
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// One panel-tab label in the terminal header. 11px uppercase, #858585,
/// white on hover; the active tab (TERMINAL) is 12px semibold white with a
/// 2px blue-500 bottom underline (150ms).
class _PanelTab extends StatefulWidget {
  final String label;
  final bool active;
  final String? badge;

  const _PanelTab({
    required this.label,
    this.active = false,
    this.badge,
  });

  @override
  State<_PanelTab> createState() => _PanelTabState();
}

class _PanelTabState extends State<_PanelTab> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<UiProvider>().palette;
    final active = widget.active;
    final brightFg =
        c.brightness == Brightness.dark ? c.textOnAccent : c.textPrimary;
    final fg = active || _hover ? brightFg : c.textSecondary;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        // 31 = header height (32) minus its 1px bottom border, so the
        // active tab's 2px underline sits flush against the header edge.
        height: 31,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              width: 2,
              color: active ? c.blue500 : Colors.transparent,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.label,
              style: TextStyle(
                fontSize: active ? 12 : 11,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                letterSpacing: 1,
                color: fg,
              ),
            ),
            if (widget.badge != null) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: c.borderLight,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  widget.badge!,
                  style: TextStyle(fontSize: 10, color: c.textOnAccent),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Header action icon: 14px, #858585 → white on hover.
class _HeaderIcon extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final AppColors palette;

  const _HeaderIcon({
    required this.icon,
    required this.tooltip,
    required this.palette,
    this.onTap,
  });

  @override
  State<_HeaderIcon> createState() => _HeaderIconState();
}

class _HeaderIconState extends State<_HeaderIcon> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.palette;
    final hoverFg =
        c.brightness == Brightness.dark ? c.textOnAccent : c.textPrimary;
    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 300),
      child: MouseRegion(
        cursor:
            widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Icon(widget.icon,
                size: 14, color: _hover ? hoverFg : c.textSecondary),
          ),
        ),
      ),
    );
  }
}
