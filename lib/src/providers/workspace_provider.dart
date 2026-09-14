import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/fs_service.dart';
import '../services/settings_service.dart';

/// Workspace root + file tree + CRUD operations + recent folders.
/// Deleting a node closes ALL editor tabs under that path (audit fix #6).
class WorkspaceProvider extends ChangeNotifier {
  String? _rootPath;
  FileNode? _root;
  final List<RecentFolder> _recents = [];

  String? get rootPath => _rootPath;
  FileNode? get root => _root;
  List<RecentFolder> get recents => List.unmodifiable(_recents);

  /// Called by EditorProvider via a registered closure to avoid a circular
  /// import: (paths to close) -> void.
  void Function(List<String> paths)? closeTabsByPrefix;

  WorkspaceProvider() {
    _recents.addAll(SettingsService.loadRecents());
  }

  bool get hasWorkspace => _rootPath != null;

  Future<void> openFolder(String path) async {
    if (!Directory(path).existsSync()) {
      throw FsException('Folder not found: $path');
    }
    _rootPath = path;
    _root = FsService.buildTree(path);
    // Recents
    _recents.removeWhere((r) => r.path == path);
    _recents.insert(0, RecentFolder(path: path, openedAt: DateTime.now()));
    while (_recents.length > 10) {
      _recents.removeLast();
    }
    SettingsService.saveRecents(_recents);
    notifyListeners();
  }

  Future<void> refresh() async {
    if (_rootPath == null) return;
    _root = FsService.buildTree(_rootPath!);
    notifyListeners();
  }

  /// Re-read children of an expanded dir node in place.
  void expandNode(FileNode node) {
    if (!node.isDir) return;
    if (node.children.isEmpty) {
      node.children.addAll(FsService.childrenOf(node));
    }
    node.expanded = true;
    notifyListeners();
  }

  void collapseNode(FileNode node) {
    node.expanded = false;
    notifyListeners();
  }

  void toggleNode(FileNode node) {
    node.expanded ? collapseNode(node) : expandNode(node);
  }

  // ------------------------------------------------------------------- CRUD

  Future<void> createFile(String parentDir, String name) async {
    final path = _join(parentDir, name);
    FsService.createFile(path);
    await refresh();
  }

  Future<void> createDir(String parentDir, String name) async {
    final path = _join(parentDir, name);
    FsService.createDir(path);
    await refresh();
  }

  Future<void> rename(String oldPath, String newName) async {
    final parent = oldPath.substring(0, oldPath.lastIndexOf(Platform.pathSeparator));
    final newPath = _join(parent, newName);
    FsService.rename(oldPath, newPath);
    await refresh();
  }

  /// Delete a file or folder. BEFORE deleting, computes every descendant path
  /// and asks the editor to close ALL matching tabs (audit fix #6).
  Future<void> deleteNode(String path) async {
    final doomed = <String>[];
    if (Directory(path).existsSync()) {
      try {
        doomed.addAll(Directory(path)
            .listSync(recursive: true, followLinks: false)
            .whereType<File>()
            .map((f) => f.path));
      } catch (_) {/* unreadable dir tree — still try direct delete */}
    }
    doomed.add(path);
    closeTabsByPrefix?.call(doomed);
    FsService.delete(path); // throws on failure → UI shows real error (audit fix #7)
    await refresh();
  }

  String _join(String dir, String name) =>
      '$dir${Platform.pathSeparator}$name';

  // ------------------------------------------------------------- tree utils

  FileNode? findByPath(String path) {
    if (_root == null) return null;
    return _findByPath(_root!, path);
  }

  FileNode? _findByPath(FileNode node, String path) {
    if (node.path == path) return node;
    for (final c in node.children) {
      final found = _findByPath(c, path);
      if (found != null) return found;
    }
    return null;
  }
}
