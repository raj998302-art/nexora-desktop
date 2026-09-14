import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/fs_service.dart';

/// Open editor tabs, content, dirty state, cursor + scroll position, saving,
/// and "run active file" (delegated to a registered callback so terminal
/// wiring stays decoupled).
class EditorProvider extends ChangeNotifier {
  final List<EditorTab> _tabs = [];
  int _activeIndex = -1;

  /// Registered by main wiring: given a file path, build & run the command
  /// in a fresh terminal session.
  void Function(String path)? onRunFile;

  List<EditorTab> get tabs => List.unmodifiable(_tabs);
  int get activeIndex => _activeIndex;
  EditorTab? get activeTab => (_activeIndex >= 0 && _activeIndex < _tabs.length)
      ? _tabs[_activeIndex]
      : null;
  int get openCount => _tabs.length;
  bool get anyDirty => _tabs.any((t) => t.dirty);

  // ------------------------------------------------------------------ open

  void openFile(String path, {bool forceFocus = true}) {
    final idx = _tabs.indexWhere((t) => t.path == path);
    if (idx != -1) {
      if (forceFocus) _activeIndex = idx;
      notifyListeners();
      return;
    }
    final content = FsService.readFile(path); // throws → caller shows error
    final name = path.split(Platform.pathSeparator).last;
    _tabs.add(EditorTab(
      path: path,
      name: name,
      content: content,
      language: FsService.languageOf(path),
    ));
    _activeIndex = _tabs.length - 1;
    notifyListeners();
  }

  void openUntitled() {
    var i = 1;
    var name = 'untitled-1.dart';
    while (_tabs.any((t) => t.name == name)) {
      i++;
      name = 'untitled-$i.dart';
    }
    _tabs.add(EditorTab(
      path: name,
      name: name,
      content: '',
      language: 'dart',
    ));
    _activeIndex = _tabs.length - 1;
    notifyListeners();
  }

  void setActive(int index) {
    if (index < 0 || index >= _tabs.length) return;
    _activeIndex = index;
    notifyListeners();
  }

  void setActiveByPath(String path) {
    final idx = _tabs.indexWhere((t) => t.path == path);
    if (idx != -1) setActive(idx);
  }

  // ------------------------------------------------------------------ close

  bool closeTab(int index) {
    if (index < 0 || index >= _tabs.length) return true;
    final tab = _tabs[index];
    if (tab.dirty) return false; // caller must confirm discard
    _closeAt(index);
    return true;
  }

  void discardAndClose(int index) => _closeAt(index);

  void _closeAt(int index) {
    _tabs.removeAt(index);
    if (_activeIndex >= _tabs.length) _activeIndex = _tabs.length - 1;
    if (_activeIndex < 0 && _tabs.isNotEmpty) _activeIndex = 0;
    notifyListeners();
  }

  /// Close every tab whose path is in [paths] OR lives inside a deleted
  /// folder path (paths include deleted dirs' files). Used by
  /// WorkspaceProvider.deleteNode (audit fix #6).
  void closeMany(List<String> paths) {
    if (paths.isEmpty) return;
    final set = paths.toSet();
    _tabs.removeWhere((t) => set.contains(t.path));
    if (_activeIndex >= _tabs.length) _activeIndex = _tabs.length - 1;
    if (_activeIndex < 0 && _tabs.isNotEmpty) _activeIndex = 0;
    notifyListeners();
  }

  // ---------------------------------------------------------------- content

  void updateContent(String content) {
    final tab = activeTab;
    if (tab == null || tab.content == content) return;
    tab.content = content;
    notifyListeners();
  }

  void updateCursor(int line, int col) {
    final tab = activeTab;
    if (tab == null) return;
    // Always notify — even for clean files — so the status bar Ln/Col stays
    // live (audit fix #8).
    if (tab.cursorLine == line && tab.cursorCol == col) return;
    tab.cursorLine = line;
    tab.cursorCol = col;
    notifyListeners();
  }

  void updateScrollY(int y) {
    final tab = activeTab;
    if (tab == null || tab.scrollOffsetY == y) return;
    tab.scrollOffsetY = y;
    // No notifyListeners: scroll shouldn't rebuild the whole tree.
  }

  // ------------------------------------------------------------------ save

  bool saveActive() {
    final tab = activeTab;
    if (tab == null) return false;
    if (tab.path.contains(Platform.pathSeparator) ||
        !tab.name.contains('.')) {
      // Real file on disk (has a directory component).
      try {
        FsService.writeFile(tab.path, tab.content);
        tab.savedContent = tab.content;
        notifyListeners();
        return true;
      } catch (e) {
        throw FsException('Save failed: $e');
      }
    }
    // Untitled buffer: caller (UI) should prompt for a path.
    return false;
  }

  int saveAll() {
    var saved = 0;
    for (final tab in _tabs) {
      if (!tab.dirty) continue;
      if (!tab.path.contains(Platform.pathSeparator)) continue; // untitled
      try {
        FsService.writeFile(tab.path, tab.content);
        tab.savedContent = tab.content;
        saved++;
      } catch (_) {
        // Keep going; a partial save is better than none. Errors surface on
        // the failing tab which remains dirty.
      }
    }
    notifyListeners();
    return saved;
  }

  /// Reload a tab's content from disk (e.g. after the AI agent wrote a file).
  void reloadTab(String path) {
    for (var i = 0; i < _tabs.length; i++) {
      if (_tabs[i].path != path) continue;
      try {
        final fresh = FsService.readFile(path);
        _tabs[i].content = fresh;
        _tabs[i].savedContent = fresh;
      } catch (_) {}
    }
    notifyListeners();
  }

  // ------------------------------------------------------------------- run

  void runActiveFile() {
    final tab = activeTab;
    if (tab == null) return;
    onRunFile?.call(tab.path);
  }

  // ----------------------------------------------------------- reveal lines

  /// Search results request "open file & jump to line N".
  final Map<String, int> _revealRequests = {};

  void requestRevealLine(String path, int line) {
    openFile(path);
    _revealRequests[path] = line;
    notifyListeners();
  }

  /// CodeEditor calls this to consume a pending reveal for the active tab.
  int? consumeReveal(String path) {
    final line = _revealRequests.remove(path);
    if (line != null) notifyListeners();
    return line;
  }
}
