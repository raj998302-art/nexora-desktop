// NEXORA — embedded terminal pane. Real shell sessions (spawned by
// TerminalProvider) rendered as a scrollback of lines plus a per-session
// input row. IMPORTANT: the parent workspace owns this pane's height (it is
// wrapped in a SizedBox driven by UiProvider.terminalHeight) — this widget
// only fills the box it is given.
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
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: c.activityBar,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          Text(
            'TERMINAL',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0;
                      i < term.sessions.length && i < 5;
                      i++)
                    _buildSessionChip(term, i, c),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          _headerButton(
            c,
            Icons.add,
            'New terminal session',
            _createSession,
          ),
          _headerButton(
            c,
            Icons.power_settings_new,
            'Kill active process',
            () => term.active?.kill(),
            color: c.error,
          ),
          _headerButton(
            c,
            Icons.expand_more,
            'Hide terminal panel',
            () => context.read<UiProvider>().setTerminalOpen(false),
          ),
        ],
      ),
    );
  }

  Widget _headerButton(
    AppColors c,
    IconData icon,
    String tooltip,
    VoidCallback onPressed, {
    Color? color,
  }) {
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon, size: 14, color: color ?? c.textSecondary),
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
          child: Container(
            height: 24,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: isActive ? c.panelBackground : null,
              borderRadius: BorderRadius.circular(4),
              border: isActive ? Border.all(color: c.borderLight) : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  session.title,
                  style: TextStyle(
                    fontSize: 11,
                    color: isActive ? c.textPrimary : c.textSecondary,
                  ),
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
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: session.lines.length,
        itemBuilder: (context, index) {
          final line = session.lines[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
            child: Text(
              line.text,
              softWrap: true,
              overflow: TextOverflow.clip,
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                height: 1.4,
                color: line.isStderr ? c.error : c.textPrimary,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInput(TerminalSession session, AppColors c) {
    final controller = _controllerFor(session);
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: c.background,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          Text(
            '\$',
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              color: c.success,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: _inputFocus,
              autofocus: true,
              cursorColor: c.accent,
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
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
