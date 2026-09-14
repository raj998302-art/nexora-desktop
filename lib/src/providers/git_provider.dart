import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/ai_service.dart' show AiService;
import '../services/git_service.dart';

/// Git panel state: status, diffs, staging, commits, push/pull/fetch, log.
class GitProvider extends ChangeNotifier {
  GitService? _service;
  final AiService _ai;

  GitStatusResult status = GitStatusResult(branch: '', files: [], ahead: 0, behind: 0, repo: false);
  List<GitCommit> commits = [];
  List<FileDiff> workDiffs = [];
  List<FileDiff> stagedDiffs = [];

  bool loading = false;
  bool busy = false; // during commit/push/pull
  String lastMessage = '';
  String selectedPath;
  bool showStaged = false;

  GitProvider(this._ai, {this.selectedPath = ''});

  void bindWorkspace(String? rootPath) {
    _service = rootPath == null ? null : GitService(rootPath);
    refresh();
  }

  bool get isRepo => status.repo;

  // ------------------------------------------------------------------ load

  Future<void> refresh({bool fetchLog = true}) async {
    final svc = _service;
    if (svc == null) {
      status = GitStatusResult(branch: '', files: [], ahead: 0, behind: 0, repo: false);
      notifyListeners();
      return;
    }
    loading = true;
    notifyListeners();
    try {
      status = await svc.status();
      if (fetchLog && status.repo) {
        commits = await svc.log();
        workDiffs = await svc.diff();
        stagedDiffs = await svc.diff(cached: true);
      } else {
        commits = [];
        workDiffs = [];
        stagedDiffs = [];
      }
      lastMessage = '';
    } catch (e) {
      lastMessage = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void selectFile(String path, {bool staged = false}) {
    selectedPath = path;
    showStaged = staged;
    notifyListeners();
  }

  FileDiff? get selectedDiff {
    final list = showStaged ? stagedDiffs : workDiffs;
    for (final d in list) {
      if (d.path == selectedPath) return d;
    }
    return null;
  }

  // ------------------------------------------------------------------ ops

  Future<bool> stage(String path) async {
    final ok = await _guard(() => _service!.stage(path));
    await refresh();
    return ok;
  }

  Future<bool> stageAll() async {
    final ok = await _guard(() => _service!.stageAll());
    await refresh();
    return ok;
  }

  Future<bool> unstage(String path) async {
    final ok = await _guard(() => _service!.unstage(path));
    await refresh();
    return ok;
  }

  Future<bool> discard(String path) async {
    final ok = await _guard(() => _service!.discard(path));
    await refresh();
    return ok;
  }

  Future<bool> commit(String message) async {
    if (message.trim().isEmpty) return false;
    final ok = await _guard(() => _service!.commit(message));
    await refresh();
    return ok;
  }

  Future<bool> push() => _netOp((s) => s.push());
  Future<bool> pull() => _netOp((s) => s.pull());
  Future<bool> fetch() => _netOp((s) => s.fetch());

  Future<bool> _netOp(Future<String> Function(GitService s) op) async {
    final svc = _service;
    if (svc == null) return false;
    busy = true;
    notifyListeners();
    try {
      final out = await op(svc);
      lastMessage = out.isNotEmpty ? out : 'Done.';
      await refresh();
      return true;
    } catch (e) {
      lastMessage = e.toString();
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<bool> _guard(Future<void> Function() op) async {
    busy = true;
    notifyListeners();
    try {
      await op();
      return true;
    } catch (e) {
      lastMessage = e.toString();
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  // ------------------------------------------------------ AI commit message

  bool generatingMessage = false;

  /// Ask the AI to draft a commit message from the staged diff
  /// (falls back to full worktree diff when nothing is staged).
  Future<String> generateCommitMessage() async {
    if (generatingMessage) return '';
    generatingMessage = true;
    notifyListeners();
    var result = '';
    try {
      var diffText = stagedDiffs.isNotEmpty ? _diffsToText(stagedDiffs) : '';
      if (diffText.isEmpty) {
        final svc = _service;
        if (svc != null) {
          final files = status.files.map((f) => '${f.label} ${f.path}').join('\n');
          diffText = files;
        }
      }
      if (diffText.trim().isEmpty) {
        result = '';
      } else {
        final capped = diffText.length > 6000
            ? '${diffText.substring(0, 6000)}\n… (diff truncated)'
            : diffText;
        result = await _ai.chatOnce([
          ChatMessage(
              role: ChatRole.system,
              content:
                  'You write git commit messages. Reply with ONE concise conventional-commit '
                  'style line (max 72 chars, no quotes, no explanation), e.g. "feat: add settings screen".'),
          ChatMessage(
              role: ChatRole.user,
              content: 'Write a commit message for these changes:\n\n$capped'),
        ], maxTokens: 48);
        result = result.trim().split('\n').first.trim();
        if (result.length > 80) result = result.substring(0, 80);
      }
    } catch (e) {
      lastMessage = 'AI commit message failed: $e';
    } finally {
      generatingMessage = false;
      notifyListeners();
    }
    return result;
  }

  String _diffsToText(List<FileDiff> diffs) {
    final buf = StringBuffer();
    for (final d in diffs.take(10)) {
      buf.writeln('--- ${d.path} (+${d.additions} -${d.deletions})');
      for (final l in d.lines.where((l) => l.type != 'meta').take(60)) {
        buf.writeln(l.text);
      }
    }
    return buf.toString();
  }
}
