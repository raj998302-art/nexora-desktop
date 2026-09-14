import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/editor_provider.dart';
import '../providers/ui_provider.dart';
import '../providers/workspace_provider.dart';
import '../services/fs_service.dart';
import '../theme/app_colors.dart';

/// Workspace-wide content search: plain or regex, case toggle, grouped
/// results, click-to-reveal in the editor.
class SearchPanel extends StatefulWidget {
  const SearchPanel({Key? key}) : super(key: key);

  @override
  State<SearchPanel> createState() => _SearchPanelState();
}

class _SearchPanelState extends State<SearchPanel> {
  final TextEditingController _query = TextEditingController();
  bool _caseSensitive = false;
  bool _useRegex = false;
  bool _searching = false;
  bool _searched = false;
  final Map<String, List<SearchHit>> _groups = {};

  @override
  void initState() {
    super.initState();
    // Rebuild on query edits so the search button's enabled state follows.
    _query.addListener(_onQueryChanged);
  }

  void _onQueryChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _query.removeListener(_onQueryChanged);
    _query.dispose();
    super.dispose();
  }

  String _relPath(String root, String path) {
    final prefix =
        root.endsWith(Platform.pathSeparator) ? root : '$root${Platform.pathSeparator}';
    if (path.startsWith(prefix)) return path.substring(prefix.length);
    return path;
  }

  Future<void> _runSearch() async {
    final ws = context.read<WorkspaceProvider>();
    final root = ws.rootPath;
    final q = _query.text.trim();
    if (root == null || q.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => _searching = true);
    List<SearchHit> hits = [];
    try {
      // Run off the current build phase; results land after the frame.
      await Future(() {
        hits = FsService.search(root, q,
            caseSensitive: _caseSensitive, useRegex: _useRegex);
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

  @override
  Widget build(BuildContext context) {
    final ws = context.watch<WorkspaceProvider>();
    final c = context.read<UiProvider>().palette;

    return Container(
      color: c.panelBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: c.border)),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'SEARCH',
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
          // Query + options
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            child: Column(
              children: [
                TextField(
                  controller: _query,
                  autofocus: true,
                  style: TextStyle(color: c.textPrimary, fontSize: 12),
                  onSubmitted: (_) => _runSearch(),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                    hintText: 'Search (regex?)',
                    hintStyle: TextStyle(color: c.textSecondary, fontSize: 12),
                    filled: true,
                    fillColor: c.activityBar,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide(color: c.borderLight),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide(color: c.accent),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _ToggleChip(
                      label: 'Aa',
                      tooltip: 'Match case',
                      active: _caseSensitive,
                      palette: c,
                      onChanged: () =>
                          setState(() => _caseSensitive = !_caseSensitive),
                    ),
                    const SizedBox(width: 4),
                    _ToggleChip(
                      label: '.*',
                      tooltip: 'Use regular expression',
                      active: _useRegex,
                      palette: c,
                      onChanged: () =>
                          setState(() => _useRegex = !_useRegex),
                    ),
                    const Spacer(),
                    if (_searching)
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: c.accent,
                        ),
                      )
                    else
                      IconButton(
                        tooltip: 'Search (Enter)',
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          Icons.search,
                          size: 15,
                          color: _query.text.trim().isEmpty
                              ? c.textSecondary.withValues(alpha: 0.4)
                              : c.textSecondary,
                        ),
                        onPressed: _query.text.trim().isEmpty ? null : _runSearch,
                      ),
                  ],
                ),
              ],
            ),
          ),
          // Results
          Expanded(
            child: !ws.hasWorkspace
                ? Center(
                    child: Text('Open a folder to search',
                        style:
                            TextStyle(color: c.textSecondary, fontSize: 12)),
                  )
                : _groups.isEmpty
                    ? Center(
                        child: Text(
                          _searched ? 'No results' : 'Type a query and press Enter',
                          style:
                              TextStyle(color: c.textSecondary, fontSize: 12),
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
        padding: const EdgeInsets.symmetric(horizontal: 10),
        color: c.activityBar.withValues(alpha: 0.5),
        child: Row(
          children: [
            Icon(Icons.description_outlined, size: 12, color: c.textSecondary),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                _relPath(root, path),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: c.textSecondary, fontSize: 11),
              ),
            ),
            const SizedBox(width: 6),
            Text('+${hits.length}',
                style: TextStyle(color: c.textSecondary, fontSize: 10)),
          ],
        ),
      ));
      out.addAll(hits.map((hit) => _HitRow(
            hit: hit,
            palette: c,
            onTap: () =>
                context.read<EditorProvider>().requestRevealLine(hit.path, hit.line),
          )));
    }
    if (_groups.length > 50) {
      out.add(Padding(
        padding: const EdgeInsets.all(8),
        child: Text('… ${_groups.length - 50} more files not shown',
            style: TextStyle(color: c.textSecondary, fontSize: 11)),
      ));
    }
    return out;
  }
}

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
          style: TextStyle(
            backgroundColor: c.accentSoft,
            color: c.textPrimary,
          ),
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
        child: Container(
          height: 24,
          padding: const EdgeInsets.only(left: 12, right: 8),
          color: _hover ? c.accentSoft.withValues(alpha: 0.35) : null,
          child: Row(
            children: [
              SizedBox(
                width: 36,
                child: Text(
                  '${hit.line}',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: c.textSecondary),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: c.textPrimary,
                    ),
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

class _ToggleChip extends StatelessWidget {
  final String label;
  final String tooltip;
  final bool active;
  final AppColors palette;
  final VoidCallback onChanged;

  const _ToggleChip({
    required this.label,
    required this.tooltip,
    required this.active,
    required this.palette,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = palette;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onChanged,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: active ? c.accent : c.borderLight,
            ),
            color: active ? c.accentSoft.withValues(alpha: 0.5) : Colors.transparent,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: active ? c.accent : c.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
