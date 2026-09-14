// NEXORA — status bar (24px, accent background, palette-driven text).
//
// Audit fixes: #5 (all text uses c.textOnAccent — never hardcoded white),
// #8 (Ln/Col is ALWAYS live: EditorProvider.updateCursor notifies even for
// clean files).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/editor_provider.dart';
import '../providers/git_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/ui_provider.dart';
import 'command_palette.dart';

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
    final dirtyCount = editor.tabs.where((t) => t.dirty).length;
    final branch =
        git.status.repo ? (git.status.branch.isEmpty ? 'repo' : git.status.branch) : 'no repo';
    final aheadBehind = StringBuffer();
    if (git.status.repo) {
      if (git.status.ahead > 0) aheadBehind.write(' ↑${git.status.ahead}');
      if (git.status.behind > 0) aheadBehind.write(' ↓${git.status.behind}');
    }
    // Defaults to 1, 1 — the provider keeps these live on clean files too.
    final ln = (tab?.cursorLine ?? 0) + 1;
    final col = (tab?.cursorCol ?? 0) + 1;

    final base = TextStyle(
        color: c.textOnAccent, fontSize: 11, fontFamily: 'Segoe UI');
    final dim = base.copyWith(color: c.textOnAccent.withValues(alpha: 0.85));

    return Container(
      height: 24,
      color: c.accent,
      child: DefaultTextStyle(
        style: base,
        child: IconTheme(
          data: IconThemeData(size: 12, color: c.textOnAccent),
          child: Row(
            children: [
              // ---- Left: git ----
              _StatusItem(
                first: true,
                onTap: () =>
                    NxActions.showLeftPanel(context, LeftPanelMode.git),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.merge_type, size: 12),
                    const SizedBox(width: 4),
                    Text(branch),
                    if (aheadBehind.isNotEmpty)
                      Text(aheadBehind.toString()),
                  ],
                ),
              ),
              if (editor.anyDirty)
                _StatusItem(child: Text('● $dirtyCount')),
              const Spacer(),
              // ---- Right ----
              _StatusItem(
                onTap: () => ui.toggleTerminal(),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: ui.terminalOpen
                        ? c.accentSoft
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: const Icon(Icons.terminal, size: 12),
                ),
              ),
              _StatusItem(child: Text('Ln $ln, Col $col', style: dim)),
              _StatusItem(
                  child: Text('Spaces: ${settings.tabSizeEffective}',
                      style: dim)),
              _StatusItem(child: Text('UTF-8', style: dim)),
              _StatusItem(
                  child: Text(
                      tab?.language.toUpperCase() ?? 'No file',
                      style: dim)),
            ],
          ),
        ),
      ),
    );
  }
}

/// One tappable status bar cell: 6px horizontal padding (none on the left of
/// the first item) wrapped in an InkWell.
class _StatusItem extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool first;

  const _StatusItem({required this.child, this.onTap, this.first = false});

  @override
  Widget build(BuildContext context) {
    final c = context.read<UiProvider>().palette;
    return InkWell(
      onTap: onTap,
      hoverColor:
          onTap == null ? Colors.transparent : c.textOnAccent.withValues(alpha: 0.12),
      child: Padding(
        padding: first
            ? const EdgeInsets.only(right: 6)
            : const EdgeInsets.symmetric(horizontal: 6),
        child: Center(child: child),
      ),
    );
  }
}
