import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/editor_provider.dart';
import '../providers/ui_provider.dart';
import '../providers/workspace_provider.dart';
import '../services/fs_service.dart';
import '../theme/app_colors.dart';
import '../widgets/nexora_ui.dart';

/// Workspace-wide content search — the Web Prototype's SearchPanel visuals on
/// the REAL FsService.search: plain / regex / case-sensitive / whole-word
/// modes, results grouped by file, click-to-reveal in the editor, Enter (or
/// the leading chevron) triggers the search.
class SearchPanel extends StatefulWidget {
  const SearchPanel({Key? key}) : super(key: key);

  @override
  State<SearchPanel> createState() => _SearchPanelState();
}

class _SearchPanelState extends State<SearchPanel> {
  final TextEditingController _query = TextEditingController();
  final TextEditingController _replace = TextEditingController(); // mock field
  bool _caseSensitive = false;
  bool _wholeWord = false;
  bool _useRegex = false;
  bool _searching = false;
  bool _searched = false;
  final Map<String, List<SearchHit>> _groups = {};

  @override
  void initState() {
    super.initState();
    // Rebuild on query edits so the leading search action follows.
    _query.addListener(_onQueryChanged);
  }

  void _onQueryChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _query.removeListener(_onQueryChanged);
    _query.dispose();
    _replace.dispose();
    super.dispose();
  }

  String _relPath(String root, String path) {
    final prefix = root.endsWith(Platform.pathSeparator)
        ? root
        : '$root${Platform.pathSeparator}';
    if (path.startsWith(prefix)) return path.substring(prefix.length);
    return path;
  }

  String _escapeRegex(String s) =>
      s.replaceAllMapped(RegExp(r'[.*+?^${}()|[\]\\]'), (m) => '\\${m[0]}');

  Future<void> _runSearch() async {
    final ws = context.read<WorkspaceProvider>();
    final root = ws.rootPath;
    var q = _query.text.trim();
    if (root == null || q.isEmpty) return;
    // Whole-word mode: literal word match via \b…\b on the regex path.
    var useRegex = _useRegex;
    if (_wholeWord) {
      if (!_useRegex) q = _escapeRegex(q);
      q = '\\b$q\\b';
      useRegex = true;
    }
    FocusScope.of(context).unfocus();
    setState(() => _searching = true);
    List<SearchHit> hits = [];
    try {
      // Run off the current build phase; results land after the frame.
      await Future(() {
        hits = FsService.search(root, q,
            caseSensitive: _caseSensitive, useRegex: useRegex);
      });
    } catch (_) {
      // FsService swallows per-file IO errors; ignore.
    }
    if (!mounted) return;
    final groups = <String, List<SearchHit>>{};
    for (final h in hits) {
      groups.putIfAbsent(h.path, () => <SearchHit>[]).add(h);
    }
    setState(() {
      _groups
        ..clear()
        ..addAll(groups);
      _searched = true;
      _searching = false;
    });
  }

  // --------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final ws = context.watch<WorkspaceProvider>();
    final c = context.watch<UiProvider>().palette;
    final totalHits =
        _groups.values.fold<int>(0, (sum, list) => sum + list.length);

    return Container(
      color: c.activityBar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const NexoraPanelHeader(title: 'Search'),
          // Search + replace fields (prototype: replace row indented 16).
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                _PanelField(
                  controller: _query,
                  hint: 'Search',
                  autofocus: true,
                  onSubmitted: (_) => _runSearch(),
                  leading: NexoraIconButton(
                    icon: Icons.chevron_right,
                    size: 14,
                    tooltip: 'Search (Enter)',
                    color: _query.text.trim().isEmpty
                        ? c.textSecondary.withValues(alpha: 0.4)
                        : c.textSecondary,
                    onPressed:
                        _query.text.trim().isEmpty ? null : _runSearch,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ToggleSquare(
                        label: 'Aa',
                        tooltip: 'Match Case',
                        active: _caseSensitive,
                        onTap: () => setState(
                            () => _caseSensitive = !_caseSensitive),
                      ),
                      const SizedBox(width: 2),
                      _ToggleSquare(
                        label: 'ab',
                        tooltip: 'Match Whole Word',
                        active: _wholeWord,
                        underline: true,
                        onTap: () =>
                            setState(() => _wholeWord = !_wholeWord),
                      ),
                      const SizedBox(width: 2),
                      _ToggleSquare(
                        label: '.*',
                        tooltip: 'Use Regular Expression',
                        active: _useRegex,
                        onTap: () =>
                            setState(() => _useRegex = !_useRegex),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: _PanelField(
                    controller: _replace,
                    hint: 'Replace',
                    trailing: Icon(
                      Icons.find_replace,
                      size: 14,
                      color: c.textSecondary.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Results count header (real counts; 0/0 initially, like prototype).
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '$totalHits results in ${_groups.length} files',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: c.textSecondary,
                    ),
                  ),
                ),
                if (_searching)
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.6,
                      color: c.blue400,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: !ws.hasWorkspace
                ? Center(
                    child: Text('Open a folder to search',
                        style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: c.textSecondary)),
                  )
                : _groups.isEmpty
                    ? Center(
                        child: Text(
                          _searched
                              ? 'No results'
                              : 'Type a query and press Enter',
                          style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: c.textSecondary),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.only(bottom: 8),
                        children: _buildResults(ws.rootPath!, c),
                      ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildResults(String root, AppColors c) {
    final out = <Widget>[];
    var filesShown = 0;
    for (final entry in _groups.entries) {
      if (filesShown >= 50) break;
      filesShown++;
      final path = entry.key;
      final hits = entry.value;
      out.add(Container(
        height: 22,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        color: c.hoverBackground.withValues(alpha: 0.18),
        child: Row(
          children: [
            Icon(Icons.description_outlined, size: 12, color: c.textSecondary),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                _relPath(root, path),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    color: c.textSecondary),
              ),
            ),
            const SizedBox(width: 6),
            Text('${hits.length}',
                style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    color: c.textSecondary)),
          ],
        ),
      ));
      out.addAll(hits.map((hit) => _HitRow(
            hit: hit,
            palette: c,
            onTap: () => context
                .read<EditorProvider>()
                .requestRevealLine(hit.path, hit.line),
          )));
    }
    if (_groups.length > 50) {
      out.add(Padding(
        padding: const EdgeInsets.all(8),
        child: Text('… ${_groups.length - 50} more files not shown',
            style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                color: c.textSecondary)),
      ));
    }
    return out;
  }
}

// ------------------------------------------------------------------ field

/// Prototype input field: bg inputBackground, borderLight, rounded 6, focus
/// border blue500 (150ms), 13px white text + #858585 hint.
class _PanelField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;
  final Widget? leading;
  final Widget? trailing;

  const _PanelField({
    required this.controller,
    required this.hint,
    this.autofocus = false,
    this.onSubmitted,
    this.leading,
    this.trailing,
  });

  @override
  State<_PanelField> createState() => _PanelFieldState();
}

class _PanelFieldState extends State<_PanelField> {
  final FocusNode _focusNode = FocusNode();
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    if (mounted) setState(() => _hasFocus = _focusNode.hasFocus);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<UiProvider>().palette;
    return AnimatedContainer(
      duration: NxMotion.fast,
      curve: NxMotion.curve,
      decoration: BoxDecoration(
        color: c.inputBackground,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _hasFocus ? c.blue500 : c.borderLight),
      ),
      child: Row(
        children: [
          if (widget.leading != null) widget.leading!,
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              autofocus: widget.autofocus,
              onSubmitted: widget.onSubmitted,
              style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: c.textOnAccent),
              cursorColor: c.blue400,
              decoration: InputDecoration(
                isDense: true,
                hintText: widget.hint,
                hintStyle: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: c.textSecondary),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              ),
            ),
          ),
          if (widget.trailing != null) widget.trailing!,
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- toggles

/// 24×24 prototype toggle square: inactive #858585 + hover #333 bg; active
/// blue-500/10 tint + blue-400 text + blue-500/30 border. The 'ab' variant
/// renders a 2px underline under the label.
class _ToggleSquare extends StatefulWidget {
  final String label;
  final String tooltip;
  final bool active;
  final bool underline;
  final VoidCallback onTap;

  const _ToggleSquare({
    required this.label,
    required this.tooltip,
    required this.active,
    required this.onTap,
    this.underline = false,
  });

  @override
  State<_ToggleSquare> createState() => _ToggleSquareState();
}

class _ToggleSquareState extends State<_ToggleSquare> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<UiProvider>().palette;
    final active = widget.active;
    final fg = active
        ? c.blue400
        : (_hover ? c.textOnAccent.withValues(alpha: 0.95) : c.textSecondary);
    final label = Text(
      widget.label,
      style: TextStyle(
          fontFamily: 'Inter', fontSize: 12, height: 1.0, color: fg),
    );
    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 300),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: NxMotion.fast,
            curve: NxMotion.curve,
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: active
                  ? c.blue500.withValues(alpha: 0.1)
                  : (_hover ? c.hoverBackground : Colors.transparent),
              border: Border.all(
                color: active
                    ? c.blue500.withValues(alpha: 0.3)
                    : Colors.transparent,
                width: 1,
              ),
            ),
            child: widget.underline
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      label,
                      const SizedBox(height: 1),
                      Container(width: 14, height: 2, color: fg),
                    ],
                  )
                : label,
          ),
        ),
      ),
    );
  }
}

// --------------------------------------------------------------- hit rows

/// One search hit: line number (FiraCode 12, width 32, right) + line text
/// with the matched range highlighted on accentSoft; hover bg inputBackground;
/// click → editor.requestRevealLine.
class _HitRow extends StatefulWidget {
  final SearchHit hit;
  final AppColors palette;
  final VoidCallback onTap;

  const _HitRow({
    required this.hit,
    required this.palette,
    required this.onTap,
  });

  @override
  State<_HitRow> createState() => _HitRowState();
}

class _HitRowState extends State<_HitRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.palette;
    final hit = widget.hit;
    final line = hit.lineText;
    var start = hit.matchStart.clamp(0, line.length);
    var end = hit.matchEnd.clamp(start, line.length);
    if (end < start) end = start;
    final spans = <TextSpan>[
      if (start > 0) TextSpan(text: line.substring(0, start)),
      if (end > start)
        TextSpan(
          text: line.substring(start, end),
          style: TextStyle(backgroundColor: c.accentSoft, color: c.textOnAccent),
        ),
      if (end < line.length) TextSpan(text: line.substring(end)),
    ];
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: NxMotion.fast,
          height: 24,
          padding: const EdgeInsets.only(left: 20, right: 8),
          color: _hover ? c.inputBackground : null,
          child: Row(
            children: [
              SizedBox(
                width: 32,
                child: Text(
                  '${hit.line}',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      fontFamily: 'FiraCode',
                      fontSize: 12,
                      color: c.textSecondary),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: TextStyle(
                        fontFamily: 'FiraCode',
                        fontSize: 12,
                        color: c.textPrimary),
                    children: spans,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
