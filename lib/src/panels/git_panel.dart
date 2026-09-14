import 'dart:io' show Platform, Process;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show HardwareKeyboard, KeyDownEvent, LogicalKeyboardKey;
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/git_provider.dart';
import '../providers/ui_provider.dart';
import '../providers/workspace_provider.dart';
import '../services/git_service.dart' show GitCommit;
import '../theme/app_colors.dart';
import '../widgets/nexora_ui.dart';

/// Git source control panel — the Web Prototype's GitPanel visuals on the
/// REAL GitProvider: refresh/fetch/pull/push, stage/unstage/discard/stage-all,
/// commit (⌘/Ctrl+Enter), AI-generated commit messages, staged/changes/
/// untracked sections, inline diff with line numbers, and history. All
/// provider calls are unchanged from the functional build.
class GitPanel extends StatefulWidget {
  const GitPanel({Key? key}) : super(key: key);

  @override
  State<GitPanel> createState() => _GitPanelState();
}

class _GitPanelState extends State<GitPanel> {
  final TextEditingController _commitMessage = TextEditingController();
  bool _stagedOpen = true;
  bool _changesOpen = true;
  bool _untrackedOpen = true;
  bool _historyOpen = true;
  String _dismissedMessage = '';

  @override
  void dispose() {
    _commitMessage.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------- helpers

  String _rel(String path, String? root) {
    if (root == null || root.isEmpty) return path;
    final prefix = root.endsWith(Platform.pathSeparator)
        ? root
        : '$root${Platform.pathSeparator}';
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
            child: Text('Discard', style: TextStyle(color: c.red400)),
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

  /// Section-header "commit staged" action: same commit flow, but with
  /// explicit feedback when the message box is still empty.
  void _commitStaged(GitProvider git, AppColors c) {
    if (_commitMessage.text.trim().isEmpty) {
      _snack('Enter a commit message first', c);
      return;
    }
    _commit(git);
  }

  Color _letterColorFor(GitFileStatus f, AppColors c) {
    if (f.untracked) return c.green400; // U
    if (!f.staged && f.label == 'D') return c.red400;
    return c.blue400; // staged + M/A/R
  }

  // --------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final git = context.watch<GitProvider>();
    final ws = context.watch<WorkspaceProvider>();
    final c = context.watch<UiProvider>().palette;
    final root = ws.rootPath;

    return Container(
      color: c.activityBar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const NexoraPanelHeader(title: 'Source Control'),
          Expanded(
            child: !ws.hasWorkspace
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text('Open a folder to see git information',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: c.textSecondary)),
                    ),
                  )
                : !git.status.repo
                    ? _buildNotRepo(root!, c)
                    : _buildRepoBody(git, root, c),
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
              style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: c.textSecondary)),
          const SizedBox(height: 12),
          NexoraPrimaryButton(
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

    final listChildren = <Widget>[
      _SectionHeader(
        label: 'STAGED CHANGES',
        count: staged.length,
        open: _stagedOpen,
        palette: c,
        onToggle: () => setState(() => _stagedOpen = !_stagedOpen),
        actions: [
          NexoraIconButton(
            icon: Icons.check,
            size: 14,
            tooltip: 'Commit Staged',
            onPressed: staged.isEmpty ? null : () => _commitStaged(git, c),
          ),
        ],
      ),
      if (_stagedOpen)
        ...staged.map((f) => _FileRow(
              file: f,
              root: root,
              palette: c,
              letterColor: _letterColorFor(f, c),
              onTap: () => git.selectFile(f.path, staged: true),
              actionIcon: Icons.remove,
              actionTooltip: 'Unstage',
              onAction: () => git.unstage(f.path),
            )),
      _SectionHeader(
        label: 'CHANGES',
        count: unstaged.length,
        open: _changesOpen,
        palette: c,
        onToggle: () => setState(() => _changesOpen = !_changesOpen),
        actions: [
          NexoraIconButton(
            icon: Icons.add,
            size: 14,
            tooltip: 'Stage All Changes',
            onPressed:
                unstaged.isEmpty ? null : () => git.stageAll(),
          ),
        ],
      ),
      if (_changesOpen)
        ...unstaged.map((f) => _FileRow(
              file: f,
              root: root,
              palette: c,
              letterColor: _letterColorFor(f, c),
              onTap: () => git.selectFile(f.path),
              actionIcon: Icons.add,
              actionTooltip: 'Stage',
              onAction: () => git.stage(f.path),
              secondIcon: Icons.restart_alt,
              secondTooltip: 'Discard changes',
              onSecond: () => _confirmDiscard(git, f.path),
            )),
      _SectionHeader(
        label: 'UNTRACKED',
        count: untracked.length,
        open: _untrackedOpen,
        palette: c,
        onToggle: () => setState(() => _untrackedOpen = !_untrackedOpen),
        actions: [
          NexoraIconButton(
            icon: Icons.add,
            size: 14,
            tooltip: 'Stage All Changes',
            onPressed: untracked.isEmpty ? null : () => git.stageAll(),
          ),
        ],
      ),
      if (_untrackedOpen)
        ...untracked.map((f) => _FileRow(
              file: f,
              root: root,
              palette: c,
              letterColor: _letterColorFor(f, c),
              onTap: () => git.selectFile(f.path),
              actionIcon: Icons.add,
              actionTooltip: 'Stage',
              onAction: () => git.stage(f.path),
            )),
      _SectionHeader(
        label: 'HISTORY',
        count: git.commits.length,
        open: _historyOpen,
        palette: c,
        onToggle: () => setState(() => _historyOpen = !_historyOpen),
      ),
      if (_historyOpen)
        ...git.commits.map((k) => _LogRow(commit: k, palette: c)),
    ];

    final diff = git.selectedDiff;
    return Column(
      children: [
        _buildCommitArea(git, c),
        _buildNetworkRow(git, c),
        if (git.lastMessage.isNotEmpty && git.lastMessage != _dismissedMessage)
          _buildMessage(git, c),
        Flexible(child: ListView(children: listChildren)),
        if (diff != null) Expanded(child: _buildDiff(git, diff, root, c)),
      ],
    );
  }

  // ---------------- commit area ----------------

  Widget _buildCommitArea(GitProvider git, AppColors c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Commit box (64px, focus border blue500) with the AI magic button
          // inside, bottom-right. ⌘/Ctrl+Enter commits.
          Focus(
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.enter &&
                  (HardwareKeyboard.instance.isControlPressed ||
                      HardwareKeyboard.instance.isMetaPressed)) {
                _commit(git);
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: Builder(builder: (ctx) {
              final focused = Focus.of(ctx).hasFocus;
              return SizedBox(
                height: 64,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AnimatedContainer(
                      duration: NxMotion.fast,
                      curve: NxMotion.curve,
                      decoration: BoxDecoration(
                        color: c.inputBackground,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: focused ? c.blue500 : c.borderLight),
                      ),
                      child: TextField(
                        controller: _commitMessage,
                        maxLines: null,
                        expands: true,
                        style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            color: c.textOnAccent),
                        cursorColor: c.blue400,
                        onSubmitted: (_) => _commit(git),
                        decoration: InputDecoration(
                          hintText: 'Message (⌘Enter to commit)',
                          hintStyle: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              color: c.textSecondary),
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.fromLTRB(10, 8, 34, 8),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: git.generatingMessage
                          ? SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.6,
                                color: c.blue400,
                              ),
                            )
                          : NexoraIconButton(
                              icon: Icons.auto_awesome,
                              size: 14,
                              color: c.blue400,
                              tooltip: 'Generate commit message with AI',
                              onPressed: () => _generateMessage(git),
                            ),
                    ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          NexoraPrimaryButton(
            onPressed: git.busy ? null : () => _commit(git),
            child: const Center(child: Text('Commit')),
          ),
        ],
      ),
    );
  }

  // ---------------- network row ----------------

  Widget _buildNetworkRow(GitProvider git, AppColors c) {
    final busy = git.busy || git.loading;
    final status = git.status;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: SizedBox(
        height: 26,
        child: Row(
          children: [
            Icon(Icons.merge_type, size: 12, color: c.textSecondary),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                status.branch,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: c.textPrimary),
              ),
            ),
            if (status.ahead > 0 || status.behind > 0) ...[
              Text(
                '↑${status.ahead} ↓${status.behind}',
                style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    color: c.textSecondary),
              ),
              const SizedBox(width: 8),
            ],
            if (busy)
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 1.6,
                  color: c.blue400,
                ),
              )
            else ...[
              NexoraIconButton(
                icon: Icons.refresh,
                size: 14,
                tooltip: 'Refresh',
                onPressed: () => git.refresh(),
              ),
              const SizedBox(width: 8),
              NexoraIconButton(
                icon: Icons.cloud_download,
                size: 14,
                tooltip: 'Fetch',
                onPressed: () => git.fetch(),
              ),
              const SizedBox(width: 8),
              NexoraIconButton(
                icon: Icons.download,
                size: 14,
                tooltip: 'Pull',
                onPressed: () => git.pull(),
              ),
              const SizedBox(width: 8),
              NexoraIconButton(
                icon: Icons.upload,
                size: 14,
                tooltip: 'Push',
                onPressed: () => git.push(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------- error / message strip ----------------

  Widget _buildMessage(GitProvider git, AppColors c) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      padding: const EdgeInsets.fromLTRB(10, 6, 2, 6),
      decoration: BoxDecoration(
        color: c.red500.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border(left: BorderSide(color: c.red400, width: 3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              git.lastMessage,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  height: 1.4,
                  color: c.red400),
            ),
          ),
          InkWell(
            onTap: () => setState(() => _dismissedMessage = git.lastMessage),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(Icons.close, size: 12, color: c.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- diff view ----------------

  Widget _buildDiff(GitProvider git, FileDiff diff, String? root, AppColors c) {
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 24,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: c.hoverBackground.withValues(alpha: 0.25),
              border: Border(bottom: BorderSide(color: c.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Diff — ${_rel(diff.path, root)} (+${diff.additions} −${diff.deletions})',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: c.textPrimary),
                  ),
                ),
                InkWell(
                  onTap: () => git.selectFile(''),
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child:
                        Icon(Icons.close, size: 12, color: c.textSecondary),
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
    );
  }
}

// ------------------------------------------------------------------ rows

/// Prototype section header: chevron + 11px semibold label + count badge
/// (hoverBackground2 pill, 10px white); hover fill inputBackground reveals
/// trailing actions.
class _SectionHeader extends StatefulWidget {
  final String label;
  final int count;
  final bool open;
  final AppColors palette;
  final VoidCallback onToggle;
  final List<Widget> actions;

  const _SectionHeader({
    required this.label,
    required this.count,
    required this.open,
    required this.palette,
    required this.onToggle,
    this.actions = const [],
  });

  @override
  State<_SectionHeader> createState() => _SectionHeaderState();
}

class _SectionHeaderState extends State<_SectionHeader> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.palette;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onToggle,
        child: AnimatedContainer(
          duration: NxMotion.fast,
          curve: NxMotion.curve,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: _hover ? c.inputBackground : null,
          child: Row(
            children: [
              Icon(
                widget.open ? Icons.expand_more : Icons.chevron_right,
                size: 14,
                color: c.textSecondary,
              ),
              const SizedBox(width: 2),
              Text(
                widget.label,
                style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: c.textPrimary),
              ),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: c.hoverBackground2,
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Text(
                  '${widget.count}',
                  style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      color: c.textOnAccent),
                ),
              ),
              const Spacer(),
              if (_hover && widget.actions.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: widget.actions,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Prototype git file row: pl 24 pr 8 py 4, name (13 #cccccc) + dir (11
/// #858585), status letter 11 bold (staged/M blue, U green, D red), hover
/// fill + hover-only actions (stage / unstage / discard).
class _FileRow extends StatefulWidget {
  final GitFileStatus file;
  final String? root;
  final AppColors palette;
  final Color letterColor;
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
    required this.palette,
    required this.letterColor,
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
    final slash = [
      rel.lastIndexOf('/'),
      rel.lastIndexOf(Platform.pathSeparator),
    ].reduce((a, b) => a > b ? a : b);
    final name = slash == -1 ? rel : rel.substring(slash + 1);
    final dir = slash == -1 ? '' : rel.substring(0, slash);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: NxMotion.fast,
          curve: NxMotion.curve,
          padding: const EdgeInsets.only(left: 24, right: 8, top: 4, bottom: 4),
          decoration: BoxDecoration(
            color: _hover ? c.inputBackground : null,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          color: c.textPrimary),
                    ),
                    if (dir.isNotEmpty)
                      Text(
                        dir,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            color: c.textSecondary),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                file.label,
                style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: widget.letterColor),
              ),
              const SizedBox(width: 4),
              IgnorePointer(
                ignoring: !_hover,
                child: AnimatedOpacity(
                  opacity: _hover ? 1.0 : 0.0,
                  duration: NxMotion.fast,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.secondIcon != null &&
                          widget.onSecond != null) ...[
                        NexoraIconButton(
                          icon: widget.secondIcon!,
                          size: 14,
                          tooltip: widget.secondTooltip ?? '',
                          onPressed: widget.onSecond,
                        ),
                        const SizedBox(width: 4),
                      ],
                      NexoraIconButton(
                        icon: widget.actionIcon,
                        size: 14,
                        tooltip: widget.actionTooltip,
                        onPressed: widget.onAction,
                      ),
                    ],
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

/// History row: short hash (FiraCode 12, blue400) + subject (13) + relative
/// time (11 #858585); hover fill inputBackground.
class _LogRow extends StatefulWidget {
  final GitCommit commit;
  final AppColors palette;

  const _LogRow({required this.commit, required this.palette});

  @override
  State<_LogRow> createState() => _LogRowState();
}

class _LogRowState extends State<_LogRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.palette;
    final commit = widget.commit;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: NxMotion.fast,
        curve: NxMotion.curve,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        color: _hover ? c.inputBackground : null,
        child: Row(
          children: [
            Text(
              commit.short,
              style: TextStyle(
                  fontFamily: 'FiraCode',
                  fontSize: 12,
                  color: c.blue400),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                commit.subject,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: c.textPrimary),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              commit.when,
              style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  color: c.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// One unified-diff line: 18px rows, FiraCode 12, 40/40 right-aligned line
/// numbers (11 #858585), 24px centered ± marker column; del bg diffDelBg
/// text red400, add bg diffAddBg text green400, hunk blue400, context
/// #858585.
class _DiffRow extends StatelessWidget {
  final DiffLine line;
  final AppColors palette;

  const _DiffRow({required this.line, required this.palette});

  @override
  Widget build(BuildContext context) {
    final c = palette;
    final Color bg;
    final Color fg;
    final String marker;
    switch (line.type) {
      case 'add':
        bg = c.diffAddBg;
        fg = c.green400;
        marker = '+';
        break;
      case 'del':
        bg = c.diffDelBg;
        fg = c.red400;
        marker = '−';
        break;
      case 'hunk':
        bg = Colors.transparent;
        fg = c.blue400;
        marker = '';
        break;
      default: // context
        bg = Colors.transparent;
        fg = c.textSecondary;
        marker = '';
    }
    final oldNo = line.oldLine == null ? '' : '${line.oldLine}';
    final newNo = line.newLine == null ? '' : '${line.newLine}';
    return Container(
      height: 18,
      color: bg,
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(oldNo,
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontFamily: 'FiraCode',
                    fontSize: 11,
                    color: c.textSecondary)),
          ),
          SizedBox(
            width: 40,
            child: Text(newNo,
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontFamily: 'FiraCode',
                    fontSize: 11,
                    color: c.textSecondary)),
          ),
          SizedBox(
            width: 24,
            child: Center(
              child: Text(marker,
                  style: TextStyle(
                      fontFamily: 'FiraCode', fontSize: 12, color: fg)),
            ),
          ),
          Expanded(
            child: Text(
              line.text,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.clip,
              style: TextStyle(
                  fontFamily: 'FiraCode', fontSize: 12, color: fg),
            ),
          ),
        ],
      ),
    );
  }
}
