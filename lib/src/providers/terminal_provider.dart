import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// A live shell session backed by a real OS process
/// (cmd.exe / powershell on Windows, bash elsewhere).
class TerminalSession {
  final String id;
  final String title;
  final String cwd;
  Process? process;
  final List<TermLine> lines = [];
  final StringBuffer _stdinBuffer = StringBuffer();

  TerminalSession({required this.id, required this.title, required this.cwd});

  void write(String data) {
    _stdinBuffer.write(data);
    final s = _stdinBuffer.toString();
    if (s.endsWith('\n')) {
      process?.stdin.write(s);
      _stdinBuffer.clear();
    }
  }

  void writeln(String line) {
    process?.stdin.write('$line\n');
  }

  void kill() {
    try {
      process?.kill();
    } catch (_) {}
  }
}

class TermLine {
  final String text;
  final bool isStderr;
  TermLine(this.text, {this.isStderr = false});
}

/// Owns terminal sessions. Each session spawns a real shell process whose
/// stdout/stderr stream into the UI; input lines are written to stdin.
class TerminalProvider extends ChangeNotifier {
  final List<TerminalSession> _sessions = [];
  int _activeIndex = -1;
  int _counter = 0;

  List<TerminalSession> get sessions => List.unmodifiable(_sessions);
  int get activeIndex => _activeIndex;
  TerminalSession? get active =>
      (_activeIndex >= 0 && _activeIndex < _sessions.length)
          ? _sessions[_activeIndex]
          : null;

  static String get _shell => Platform.isWindows ? 'cmd.exe' : 'bash';

  static String _shellTitle() => Platform.isWindows ? 'cmd' : 'bash';

  TerminalSession createSession({String? cwd, String? initialCommand}) {
    final s = TerminalSession(
      id: 't${DateTime.now().millisecondsSinceEpoch}_${_counter++}',
      title: '${_shellTitle()} ${_counter + 1}',
      cwd: cwd ?? Directory.current.path,
    );
    _sessions.insert(0, s);
    _activeIndex = 0;
    _spawn(s, initialCommand: initialCommand);
    notifyListeners();
    return s;
  }

  Future<void> _spawn(TerminalSession s, {String? initialCommand}) async {
    try {
      final proc = await Process.start(
        _shell,
        Platform.isWindows ? <String>[] : <String>[],
        workingDirectory: Directory(s.cwd).existsSync() ? s.cwd : null,
        runInShell: false,
      );
      s.process = proc;
      if (Platform.isWindows) {
        // Silence cmd's banner and enable simple prompt behavior.
      }
      proc.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        s.lines.add(TermLine(line));
        _trim(s);
        notifyListeners();
      }, onDone: _onExit(s));
      proc.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        s.lines.add(TermLine(line, isStderr: true));
        _trim(s);
        notifyListeners();
      }, onDone: _onExit(s));
      proc.exitCode.then((code) {
        s.lines.add(TermLine(
            '[process exited with code $code]', isStderr: code != 0));
        notifyListeners();
      });
      if (initialCommand != null && initialCommand.isNotEmpty) {
        s.writeln(initialCommand);
      }
    } catch (e) {
      s.lines.add(TermLine('Failed to start $_shell: $e', isStderr: true));
      notifyListeners();
    }
  }

  void Function() _onExit(TerminalSession s) => () {};

  void _trim(TerminalSession s) {
    if (s.lines.length > 4000) {
      s.lines.removeRange(0, s.lines.length - 4000);
    }
  }

  void setActive(int index) {
    if (index < 0 || index >= _sessions.length) return;
    _activeIndex = index;
    notifyListeners();
  }

  void closeSession(int index) {
    if (index < 0 || index >= _sessions.length) return;
    _sessions[index].kill();
    _sessions.removeAt(index);
    if (_activeIndex >= _sessions.length) _activeIndex = _sessions.length - 1;
    notifyListeners();
  }

  void sendInput(String line) {
    final s = active;
    if (s == null) return;
    s.lines.add(TermLine('\$ $line'));
    s.writeln(line);
    notifyListeners();
  }

  void killAll() {
    for (final s in _sessions) {
      s.kill();
    }
  }

  /// Map a source file to a run command for the embedded shell.
  static String? runCommandFor(String path) {
    final ext = path.lastIndexOf('.') == -1
        ? ''
        : path.substring(path.lastIndexOf('.') + 1).toLowerCase();
    switch (ext) {
      case 'dart':
        return 'dart run "$path"';
      case 'py':
        return 'python "$path"';
      case 'js':
        return 'node "$path"';
      case 'ts':
        return 'npx tsx "$path"';
      case 'go':
        return 'go run "$path"';
      case 'rs':
        return 'rustc "$path" -o /tmp/nexora_run && /tmp/nexora_run';
      case 'sh':
        return 'bash "$path"';
      case 'c':
        return Platform.isWindows
            ? 'cl "$path"'
            : 'gcc "$path" -o /tmp/nexora_run && /tmp/nexora_run';
      case 'cpp':
        return Platform.isWindows
            ? 'cl "$path"'
            : 'g++ "$path" -o /tmp/nexora_run && /tmp/nexora_run';
      case 'java':
        return 'java "$path"';
      case 'html':
        return Platform.isWindows
            ? 'start "" "$path"'
            : 'xdg-open "$path"';
      case 'md':
        return null;
      default:
        return null;
    }
  }

  @override
  void dispose() {
    killAll();
    super.dispose();
  }
}
