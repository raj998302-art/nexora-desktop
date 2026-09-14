import 'dart:convert';
import 'dart:io';

import '../models/models.dart';

/// Thin wrapper around the `git` CLI. All commands run inside [rootPath].
class GitService {
  final String rootPath;
  GitService(this.rootPath);

  bool get isRepo =>
      Directory('$rootPath${Platform.pathSeparator}.git').existsSync();

  /// Initialize a new repository in [rootPath] (`git init`).
  Future<void> init() async {
    final r = await _run(['init']);
    if (r.exitCode != 0) throw GitException(r.stderr.trim());
  }

  /// Run a git command and return (exitCode, stdout, stderr).
  Future<GitResult> _run(List<String> args, {Duration? timeout}) async {
    final proc = await Process.start(
      'git',
      args,
      workingDirectory: rootPath,
      runInShell: false,
    );
    final stdoutBuf = StringBuffer();
    final stderrBuf = StringBuffer();
    proc.stdout.transform(utf8.decoder).listen(stdoutBuf.write);
    proc.stderr.transform(utf8.decoder).listen(stderrBuf.write);
    final code = await proc.exitCode.timeout(
      timeout ?? const Duration(seconds: 60),
      onTimeout: () {
        proc.kill();
        return -1;
      },
    );
    return GitResult(code, stdoutBuf.toString(), stderrBuf.toString());
  }

  // ------------------------------------------------------------------ status

  Future<GitStatusResult> status() async {
    if (!isRepo) return GitStatusResult.notRepo();
    final r = await _run(['status', '--porcelain=v1', '-b']);
    final files = <GitFileStatus>[];
    var branch = '';
    var ahead = 0, behind = 0;
    if (r.exitCode == 0) {
      for (final raw in const LineSplitter().convert(r.stdout)) {
        if (raw.startsWith('##')) {
          branch = _parseBranch(raw);
          final m = RegExp(r'\[ahead (\d+)(?:, behind (\d+))?\]').firstMatch(raw);
          if (m != null) {
            ahead = int.tryParse(m.group(1) ?? '0') ?? 0;
            behind = int.tryParse(m.group(2) ?? '0') ?? 0;
          }
          continue;
        }
        if (raw.length < 4) continue;
        final index = raw[0];
        final work = raw[1];
        final path = raw.substring(3).trim();
        files.add(GitFileStatus(
          path: _stripRename(path),
          indexStatus: index,
          workStatus: work,
          untracked: index == '?',
        ));
      }
    }
    return GitStatusResult(branch: branch, files: files, ahead: ahead, behind: behind);
  }

  static String _parseBranch(String raw) {
    // "## main...origin/main" or "## No commits yet on main"
    final s = raw.replaceFirst('##', '').trim();
    if (s.startsWith('No commits yet on ')) {
      return s.replaceFirst('No commits yet on ', '').split(' ').first;
    }
    return s.split('...').first.split(' ').first;
  }

  static String _stripRename(String path) {
    // "old -> new" — take new.
    if (path.contains(' -> ')) return path.split(' -> ').last;
    return path;
  }

  // -------------------------------------------------------------------- diff

  Future<List<FileDiff>> diff({bool cached = false}) async {
    if (!isRepo) return [];
    final args = ['diff'];
    if (cached) args.add('--cached');
    args.addAll(['-U3', '--no-color']);
    final r = await _run(args);
    if (r.exitCode != 0) return [];
    return parseUnifiedDiff(r.stdout);
  }

  /// Unified-diff parser producing per-file [FileDiff]s.
  static List<FileDiff> parseUnifiedDiff(String diffText) {
    final files = <FileDiff>[];
    final lines = diffText.split('\n');
    FileDiff? current;
    int oldLine = 0, newLine = 0;
    for (var i = 0; i < lines.length; i++) {
      final l = lines[i];
      if (l.startsWith('diff --git')) {
        final m = RegExp(r'diff --git a/(.+) b/(.+)').firstMatch(l);
        current = FileDiff(
            path: m?.group(2) ?? '(unknown)', lines: []);
        files.add(current);
        continue;
      }
      if (current == null) continue;
      if (l.startsWith('index ') || l.startsWith('--- ') || l.startsWith('+++ ') ||
          l.startsWith('new file') || l.startsWith('deleted file') ||
          l.startsWith('Binary files')) {
        current.lines.add(DiffLine('meta', l));
        continue;
      }
      final hunk = RegExp(r'@@ -\d+(?:,\d+)? \+(\d+)(?:,\d+)? @@').firstMatch(l);
      if (hunk != null) {
        final oldStart =
            RegExp(r'@@ -(\d+)').firstMatch(l);
        oldLine = int.tryParse(oldStart?.group(1) ?? '0') ?? 0;
        newLine = int.tryParse(hunk.group(1) ?? '0') ?? 0;
        current.lines.add(DiffLine('hunk', l));
        continue;
      }
      if (l.startsWith('+')) {
        current.lines.add(DiffLine('add', l.substring(1), newLine: newLine++));
      } else if (l.startsWith('-')) {
        current.lines
            .add(DiffLine('del', l.substring(1), oldLine: oldLine++));
      } else if (l.startsWith(' ')) {
        current.lines.add(DiffLine('context', l.substring(1),
            oldLine: oldLine++, newLine: newLine++));
      }
    }
    return files;
  }

  // ------------------------------------------------------------ stage/unstage

  Future<void> stage(String path) async {
    final r = await _run(['add', '--', path]);
    if (r.exitCode != 0) throw GitException(r.stderr.trim());
  }

  Future<void> stageAll() async {
    final r = await _run(['add', '-A']);
    if (r.exitCode != 0) throw GitException(r.stderr.trim());
  }

  Future<void> unstage(String path) async {
    final r = await _run(['reset', 'HEAD', '--', path]);
    if (r.exitCode != 0) {
      // Repo without HEAD (no commits yet): unstage = rm from index.
      final r2 = await _run(['rm', '--cached', '--', path]);
      if (r2.exitCode != 0) throw GitException(r.stderr.trim());
    }
  }

  Future<void> discard(String path) async {
    final r = await _run(['checkout', '--', path]);
    if (r.exitCode != 0) {
      final r2 = await _run(['restore', '--', path]);
      if (r2.exitCode != 0) throw GitException(r.stderr.trim());
    }
  }

  // ------------------------------------------------------------------- commit

  Future<String> commit(String message) async {
    final r = await _run(['commit', '-m', message]);
    if (r.exitCode != 0) throw GitException(r.stderr.trim().isNotEmpty ? r.stderr.trim() : 'commit failed');
    return r.stdout;
  }

  Future<String> commitAll(String message) async {
    await stageAll();
    return commit(message);
  }

  // ----------------------------------------------------------- push/pull/fetch

  Future<String> push() async {
    final r = await _run(['push'], timeout: const Duration(minutes: 3));
    if (r.exitCode != 0) {
      throw GitException((r.stderr + r.stdout).trim());
    }
    return (r.stdout + r.stderr).trim();
  }

  Future<String> pull() async {
    final r = await _run(['pull', '--no-edit'], timeout: const Duration(minutes: 3));
    if (r.exitCode != 0) {
      throw GitException((r.stderr + r.stdout).trim());
    }
    return (r.stdout + r.stderr).trim();
  }

  Future<String> fetch() async {
    final r = await _run(['fetch', '--all'], timeout: const Duration(minutes: 2));
    if (r.exitCode != 0) {
      throw GitException((r.stderr + r.stdout).trim());
    }
    return (r.stdout + r.stderr).trim();
  }

  // ---------------------------------------------------------------------- log

  Future<List<GitCommit>> log({int limit = 30}) async {
    if (!isRepo) return [];
    final r = await _run(['log', '--pretty=format:%H%x09%h%x09%s%x09%an%x09%ar', '-n', '$limit']);
    if (r.exitCode != 0) return [];
    return const LineSplitter()
        .convert(r.stdout)
        .map((line) {
          final parts = line.split('\t');
          return GitCommit(
            hash: parts.length > 0 ? parts[0] : '',
            short: parts.length > 1 ? parts[1] : '',
            subject: parts.length > 2 ? parts[2] : '',
            author: parts.length > 3 ? parts[3] : '',
            when: parts.length > 4 ? parts[4] : '',
          );
        })
        .toList();
  }

  Future<List<String>> branches() async {
    if (!isRepo) return [];
    final r = await _run(['branch', '--format=%(refname:short)']);
    if (r.exitCode != 0) return [];
    return const LineSplitter().convert(r.stdout).map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
  }

  Future<void> checkout(String branch) async {
    final r = await _run(['checkout', branch]);
    if (r.exitCode != 0) throw GitException(r.stderr.trim());
  }

  Future<bool> hasStagedChanges() async {
    final s = await status();
    return s.files.any((f) => f.staged);
  }
}

class GitResult {
  final int exitCode;
  final String stdout;
  final String stderr;
  GitResult(this.exitCode, this.stdout, this.stderr);
}

class GitStatusResult {
  final String branch;
  final List<GitFileStatus> files;
  final int ahead;
  final int behind;
  final bool repo;
  GitStatusResult({required this.branch, required this.files, required this.ahead, required this.behind, this.repo = true});
  factory GitStatusResult.notRepo() =>
      GitStatusResult(branch: '', files: [], ahead: 0, behind: 0, repo: false);
}

class GitCommit {
  final String hash;
  final String short;
  final String subject;
  final String author;
  final String when;
  GitCommit({required this.hash, required this.short, required this.subject, required this.author, required this.when});
}

class GitException implements Exception {
  final String message;
  GitException(this.message);
  @override
  String toString() => message;
}
