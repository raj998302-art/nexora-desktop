// NEXORA — status bar (Web Prototype StatusBar.tsx): 24px accent bar, 11px
// text, px-12. Left: branch (real, `*` when dirty) + mock error/warning
// counters. Right: pulsing Radio + "Port: 5173" (mock), then the REAL items
// (Ln/Col always live, Spaces, UTF-8, language) + "Prettier" mock. Every
// item is a full-height hover cell (white/10, 150ms).
//
// Audit fixes kept: #5 (all text c.textOnAccent — never hardcoded white),
// #8 (Ln/Col ALWAYS live: EditorProvider.updateCursor notifies even for
// clean files).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/editor_provider.dart';
import '../providers/git_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/ui_provider.dart';
import 'command_palette.dart';
import 'nexora_ui.dart';

class StatusBar extends StatelessWidget {
  const StatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    final ui = context.watch<UiProvider>();
    final c = ui.palette;
    final git = context.watch<GitProvider>();
    final editor = context.watch<EditorProvider>();
    final settings = context.watch<SettingsProvider>();

    final tab = editor.activeTab;
    final branch = git.status.repo
        ? (git.status.branch.isEmpty ? 'repo' : git.status.branch)
        : 'no repo';
    // Prototype: "main*" — the * appears while any file is dirty.
    final branchLabel = '$branch${editor.anyDirty ? '*' : ''}';

    // Defaults to 1, 1 — the provider keeps these live on clean files too.
    final ln = (tab?.cursorLine ?? 0) + 1;
    final col = (tab?.cursorCol ?? 0) + 1;

    return Container(
      height: 24,
      color: c.accent,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DefaultTextStyle(
        style: TextStyle(color: c.textOnAccent, fontSize: 11, fontFamily: 'Inter'),
        child: IconTheme(
          data: IconThemeData(size: 12, color: c.textOnAccent),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ---- Left: real branch (click → git panel) + mock counters ----
              _StatusItem(
                onTap: () =>
                    NxActions.showLeftPanel(context, LeftPanelMode.git),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.account_tree, size: 12),
                    const SizedBox(width: 4),
                    Text(branchLabel),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const _StatusItem(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cancel, size: 12),
                    SizedBox(width: 4),
                    Text('0'),
                    SizedBox(width: 12),
                    Icon(Icons.warning_amber, size: 12),
                    SizedBox(width: 4),
                    Text('0'),
                  ],
                ),
              ),
              const Spacer(),
              // ---- Right: port (mock) + real editor state + Prettier (mock) --
              const _StatusItem(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Pulse(child: Icon(Icons.sensors, size: 12)),
                    SizedBox(width: 6),
                    Text('Port: 5173'),
                  ],
                ),
              ),
              _StatusItem(child: Text('Ln $ln, Col $col')),
              _StatusItem(
                  child: Text('Spaces: ${settings.tabSizeEffective}')),
              const _StatusItem(child: Text('UTF-8')),
              _StatusItem(
                  child: Text(
                      tab?.language.toUpperCase() ?? 'No file')),
              const _StatusItem(child: Text('Prettier')),
            ],
          ),
        ),
      ),
    );
  }
}

/// One status bar cell: full height, px-8, hover fill white/10 (150ms).
class _StatusItem extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _StatusItem({required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.read<UiProvider>().palette;
    return _StatusItemHover(hoverColor: c.textOnAccent, onTap: onTap, child: child);
  }
}

class _StatusItemHover extends StatefulWidget {
  final Color hoverColor;
  final VoidCallback? onTap;
  final Widget child;

  const _StatusItemHover({
    required this.hoverColor,
    required this.onTap,
    required this.child,
  });

  @override
  State<_StatusItemHover> createState() => _StatusItemHoverState();
}

class _StatusItemHoverState extends State<_StatusItemHover> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor:
          widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: NxMotion.fast,
          curve: NxMotion.curve,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          color: _hover
              ? widget.hoverColor.withValues(alpha: 0.10)
              : Colors.transparent,
          child: Center(child: widget.child),
        ),
      ),
    );
  }
}

/// Pulsing opacity for the Radio icon (prototype `animate-pulse` 600ms):
/// an AnimationController repeating in reverse wraps ONLY the icon.
class _Pulse extends StatefulWidget {
  final Widget child;
  const _Pulse({required this.child});

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 1.0, end: 0.0).animate(_controller),
      child: widget.child,
    );
  }
}
