import 'dart:io' show Platform, Process;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/git_provider.dart';
import '../providers/ui_provider.dart';
import '../providers/workspace_provider.dart';
import '../theme/app_colors.dart';

/// Git source control panel: branch header, staged/unstaged/untracked
/// lists, inline diff review, and the commit box (with AI-generated
/// messages).
class GitPanel extends StatefulWidget {
  const GitPanel({Key? key}) : super(key: key);

  @override
  State<GitPanel> createState() => _GitPanelState();
}

class _GitPanelState extends State<GitPanel> {
  final TextEditingController _commitMessage = TextEditingController();
  bool _stagedOpen = true;
  bool _changesOpen = true;
  String _dismissedMessage = '';

  @override
  void dispose() {
    _commitMessage.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------- helpers

  String _rel(String path, String? root) {
    if (root == null || root.isEmpty) return path;
    final prefix =
        root.endsWith(Platform.pathSeparator) ? root : '$root${Platform.pathSeparator}';
    if (path.startsWith(prefix)) return path.substring(prefix.length);
    return path;
  }

  void _snack(String message, AppColors c) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(milliseconds: 2200),
        backgroundColor: c.panelBackground,
        content:
            Text(message, style: TextStyle(color: c.textPrimary, fontSize: 12)),
      ),
    );
  }

  Future<void> _initRepo(String root) async {
    final c = context.read<UiProvider>().palette;
    try {
      final r = await Process.run('git', ['init'], workingDirectory: root);
      if (r.exitCode != 0) {
        _snack('git init failed: ${r.stderr}', c);
      }
    } catch (e) {
      _snack('git init failed: $e', c);
      return;
    }
    if (!mounted) return;
    await context.read<GitProvider>().refresh();
  }

  Future<void> _confirmDiscard(GitProvider git, String path) async {
    final c = context.read<UiProvider>().palette;
    final name = path.split(Platform.pathSeparator).last;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.panelBackground,
        title: Text('Discard changes?',
            style: TextStyle(color: c.textPrimary, fontSize: 15)),
        content: Text('Discard changes in $name? This cannot be undone.',
            style: TextStyle(color: c.textSecondary, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: TextStyle(color: c.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Discard', style: TextStyle(color: c.error)),
          ),
        ],
      ),
    );
    if (ok == true) await git.discard(path);
  }

  Future<void> _generateMessage(GitProvider git) async {
    final msg = await git.generateCommitMessage();
    if (!mounted) return;
    if (msg.isNotEmpty) {
      setState(() => _commitMessage.text = msg);
    }
  }

  Future<void> _commit(GitProvider git) async {
    final c = context.read<UiProvider>().palette;
    final msg = _commitMessage.text;
    if (msg.trim().isEmpty) return;
    final hasStaged = git.status.files.any((f) => f.staged);
    if (!hasStaged) {
      _snack('Stage changes first (click +)', c);
      return;
    }
    final ok = await git.commit(msg);
    if (!mounted) return;
    if (ok) {
      setState(() => _commitMessage.clear());
    }
  }

  // --------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final git = context.watch<GitProvider>();
    final ws = context.watch<WorkspaceProvider>();
    final c = context.read<UiProvider>().palette;
    final root = ws.rootPath;

    return Container(
      color: c.panelBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(git, c),
          if (git.lastMessage.isNotEmpty && git.lastMessage != _dismissedMessage)
            _buildMessage(git, c),
          Expanded(
            child: !ws.hasWorkspace
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text('Open a folder to see git information',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: c.textSecondary, fontSize: 12)),
                    ),
                  )
                : !git.status.repo
                    ? _buildNotRepo(root!, c)
                    : _buildRepoBody(git, root, c),
          ),
          if (ws.hasWorkspace && git.status.repo) _buildCommitArea(git, c),
        ],
      ),
    );
  }

  // ---------------- header ----------------

  Widget _buildHeader(GitProvider git, AppColors c) {
    final status = git.status;
    final busy = git.busy || git.loading;
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          Icon(Icons.merge_type, size: 14, color: c.textSecondary),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              status.repo && status.branch.isNotEmpty
                  ? status.branch
                  : 'GIT',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (status.ahead > 0 || status.behind > 0) ...[
            Text(
              '↑${status.ahead} ↓${status.behind}',
              style: TextStyle(color: c.textSecondary, fontSize: 11),
            ),
            const SizedBox(width: 6),
          ],
          if (busy)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.6,
                  color: c.accent,
                ),
              ),
            ),
          _HeaderIcon(
              icon: Icons.refresh, tooltip: 'Refresh', palette: c, onTap: () => git.refresh()),
          _HeaderIcon(
              icon: Icons.cloud_download,
              tooltip: 'Fetch',
              palette: c,
              onTap: () => git.fetch()),
          _HeaderIcon(
              icon: Icons.download, tooltip: 'Pull', palette: c, onTap: () => git.pull()),
          _HeaderIcon(
              icon: Icons.upload, tooltip: 'Push', palette: c, onTap: () => git.push()),
        ],
      ),
    );
  }

  Widget _buildMessage(GitProvider git, AppColors c) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      padding: const EdgeInsets.fromLTRB(8, 6, 2, 6),
      decoration: BoxDecoration(
        color: c.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.error, width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              git.lastMessage,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: c.error, fontSize: 11, height: 1.4),
            ),
          ),
          InkWell(
            onTap: () => setState(() => _dismissedMessage = git.lastMessage),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child:
                  Icon(Icons.close, size: 12, color: c.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- not-a-repo ----------------

  Widget _buildNotRepo(String root, AppColors c) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.account_tree, size: 32, color: c.textSecondary),
          const SizedBox(height: 10),
          Text('Not a git repository',
              style: TextStyle(color: c.textSecondary, fontSize: 12)),
          const SizedBox(height: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: c.accent,
              foregroundColor: c.textOnAccent,
              textStyle: const TextStyle(fontSize: 12),
            ),
            onPressed: () => _initRepo(root),
            child: const Text('Initialize Repository'),
          ),
        ],
      ),
    );
  }

  // ---------------- repo body ----------------

  Widget _buildRepoBody(GitProvider git, String? root, AppColors c) {
    final staged =
        git.status.files.where((f) => f.staged).toList(growable: false);
    final unstaged = git.status.files
        .where((f) => !f.staged && !f.untracked)
        .toList(growable: false);
    final untracked =
        git.status.files.where((f) => f.untracked).toList(growable: false);

    final fileRows = <Widget>[
      _buildSectionHeader(
        'Staged Changes (${staged.length})',
        _stagedOpen,
        c,
        () => setState(() => _stagedOpen = !_stagedOpen),
      ),
      if (_stagedOpen)
        ...staged.map((f) => _FileRow(
              file: f,
              root: root,
              letterColor: c.success,
              palette: c,
              onTap: () => git.selectFile(f.path, staged: true),
              actionIcon: Icons.remove,
              actionTooltip: 'Unstage',
              onAction: () => git.unstage(f.path),
            )),
      _buildSectionHeader(
        'Changes (${unstaged.length + untracked.length})',
        _changesOpen,
        c,
        () => setState(() => _changesOpen = !_changesOpen),
      ),
      if (_changesOpen) ...[
        ...unstaged.map((f) => _FileRow(
              file: f,
              root: root,
              letterColor: c.warning,
              palette: c,
              onTap: () => git.selectFile(f.path),
              actionIcon: Icons.add,
              actionTooltip: 'Stage',
              onAction: () => git.stage(f.path),
              secondIcon: Icons.restart_alt,
              secondTooltip: 'Discard changes',
              onSecond: () => _confirmDiscard(git, f.path),
            )),
        ...untracked.map((f) => _FileRow(
              file: f,
              root: root,
              letterColor: c.textSecondary,
              palette: c,
              onTap: () => git.selectFile(f.path),
              actionIcon: Icons.add,
              actionTooltip: 'Stage',
              onAction: () => git.stage(f.path),
            )),
      ],
    ];

    final diff = git.selectedDiff;
    return Column(
      children: [
        Flexible(
          child: fileRows.isEmpty
              ? Center(
                  child: Text('No changes',
                      style: TextStyle(color: c.textSecondary, fontSize: 12)))
              : ListView(children: fileRows),
        ),
        if (diff != null)
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: c.border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 24,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    color: c.activityBar,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Diff — ${_rel(diff.path, root)} (+${diff.additions} −${diff.deletions})',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: c.textPrimary, fontSize: 11),
                          ),
                        ),
                        InkWell(
                          onTap: () => git.selectFile(''),
                          child: Padding(
                            padding: const EdgeInsets.all(3),
                            child: Icon(Icons.close,
                                size: 12, color: c.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.only(bottom: 4),
                      itemCount: diff.lines.length,
                      itemBuilder: (context, i) {
                        final line = diff.lines[i];
                        if (line.type == 'meta') return const SizedBox.shrink();
                        return _DiffRow(line: line, palette: c);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSectionHeader(
      String label, bool open, AppColors c, VoidCallback onToggle) {
    return InkWell(
      onTap: onToggle,
      child: Container(
        height: 24,
        padding: const EdgeInsets.only(left: 8),
        child: Row(
          children: [
            Icon(
              open ? Icons.expand_more : Icons.chevron_right,
              size: 14,
              color: c.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- commit area ----------------

  Widget _buildCommitArea(GitProvider git, AppColors c) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      decoration: BoxDecoration(
        color: c.panelBackground,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _commitMessage,
            maxLines: 2,
            minLines: 1,
            style: TextStyle(color: c.textPrimary, fontSize: 12),
            onSubmitted: (_) => _commit(git),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Commit message',
              hintStyle: TextStyle(color: c.textSecondary, fontSize: 12),
              filled: true,
              fillColor: c.activityBar,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
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
              SizedBox(
                width: 30,
                height: 28,
                child: git.generatingMessage
                    ? Center(
                        child: SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.6,
                            color: c.accent,
                          ),
                        ),
                      )
                    : IconButton(
                        tooltip: 'Generate commit message with AI',
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        icon: Icon(Icons.auto_awesome,
                            size: 15, color: c.textSecondary),
                        onPressed: () => _generateMessage(git),
                      ),
              ),
              const Spacer(),
              SizedBox(
                height: 28,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.accent,
                    foregroundColor: c.textOnAccent,
                    textStyle: const TextStyle(fontSize: 11),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  onPressed:
                      git.busy ? null : () => _commit(git),
                  child: const Text('Commit'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ rows

class _FileRow extends StatefulWidget {
  final GitFileStatus file;
  final String? root;
  final Color letterColor;
  final AppColors palette;
  final VoidCallback onTap;
  final IconData actionIcon;
  final String actionTooltip;
  final VoidCallback onAction;
  final IconData? secondIcon;
  final String? secondTooltip;
  final VoidCallback? onSecond;

  const _FileRow({
    required this.file,
    required this.root,
    required this.letterColor,
    required this.palette,
    required this.onTap,
    required this.actionIcon,
    required this.actionTooltip,
    required this.onAction,
    this.secondIcon,
    this.secondTooltip,
    this.onSecond,
  });

  @override
  State<_FileRow> createState() => _FileRowState();
}

class _FileRowState extends State<_FileRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.palette;
    final file = widget.file;
    // Reuse the panel-level rel computation (kept local for independence).
    var rel = file.path;
    final root = widget.root;
    if (root != null && root.isNotEmpty) {
      final prefix = root.endsWith(Platform.pathSeparator)
          ? root
          : '$root${Platform.pathSeparator}';
      if (rel.startsWith(prefix)) rel = rel.substring(prefix.length);
    }
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          height: 26,
          padding: const EdgeInsets.only(left: 8, right: 4),
          color: _hover ? c.borderLight.withValues(alpha: 0.15) : null,
          child: Row(
            children: [
              Container(
                width: 14,
                height: 14,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: widget.letterColor.withValues(alpha: 0.15),
                ),
                child: Text(
                  file.label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: widget.letterColor,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  rel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: c.textPrimary, fontSize: 12),
                ),
              ),
              if (widget.secondIcon != null && widget.onSecond != null)
                _RowIcon(
                  icon: widget.secondIcon!,
                  tooltip: widget.secondTooltip ?? '',
                  palette: c,
                  onTap: widget.onSecond!,
                ),
              _RowIcon(
                icon: widget.actionIcon,
                tooltip: widget.actionTooltip,
                palette: c,
                onTap: widget.onAction,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RowIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final AppColors palette;
  final VoidCallback onTap;

  const _RowIcon({
    required this.icon,
    required this.tooltip,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 14, color: palette.textSecondary),
        ),
      ),
    );
  }
}

class _DiffRow extends StatelessWidget {
  final DiffLine line;
  final AppColors palette;

  const _DiffRow({required this.line, required this.palette});

  @override
  Widget build(BuildContext context) {
    final c = palette;
    final Color bg;
    final Color fg;
    final String prefix;
    switch (line.type) {
      case 'add':
        bg = c.diffAddBg;
        fg = c.success;
        prefix = '+';
        break;
      case 'del':
        bg = c.diffDelBg;
        fg = c.error;
        prefix = '−';
        break;
      case 'hunk':
        bg = Colors.transparent;
        fg = c.blueLight;
        prefix = '@';
        break;
      default: // context
        bg = Colors.transparent;
        fg = c.textSecondary;
        prefix = ' ';
    }
    final oldNo = line.oldLine == null ? '' : '${line.oldLine}';
    final newNo = line.newLine == null ? '' : '${line.newLine}';
    return Container(
      height: 16,
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Text(oldNo,
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: c.textSecondary)),
          ),
          SizedBox(
            width: 34,
            child: Text(newNo,
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: c.textSecondary)),
          ),
          Expanded(
            child: Text(
              '$prefix${line.text}',
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.clip,
              style: TextStyle(
                  fontFamily: 'monospace', fontSize: 12, color: fg),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final AppColors palette;
  final VoidCallback onTap;

  const _HeaderIcon({
    required this.icon,
    required this.tooltip,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
      padding: const EdgeInsets.all(3),
      icon: Icon(icon, size: 14, color: palette.textSecondary),
      onPressed: onTap,
    );
  }
}
