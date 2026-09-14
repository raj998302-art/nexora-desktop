import 'dart:convert';
import 'dart:io';

import '../models/models.dart';

/// Real file-system operations. Every operation THROWS on failure so the UI
/// layer can surface real errors (audit fix #7: no swallowed failures).
class FsService {
  /// Language id from file extension — used by the highlighter & run mapping.
  static String languageOf(String path) {
    final ext = path.lastIndexOf('.') == -1
        ? ''
        : path.substring(path.lastIndexOf('.') + 1).toLowerCase();
    switch (ext) {
      case 'dart':
        return 'dart';
      case 'py':
        return 'python';
      case 'js':
      case 'jsx':
      case 'mjs':
      case 'cjs':
        return 'javascript';
      case 'ts':
      case 'tsx':
        return 'typescript';
      case 'json':
        return 'json';
      case 'yaml':
      case 'yml':
        return 'yaml';
      case 'md':
        return 'markdown';
      case 'html':
      case 'htm':
        return 'html';
      case 'css':
        return 'css';
      case 'c':
      case 'h':
        return 'c';
      case 'cpp':
      case 'cc':
      case 'hpp':
        return 'cpp';
      case 'rs':
        return 'rust';
      case 'go':
        return 'go';
      case 'java':
        return 'java';
      case 'sh':
      case 'bash':
        return 'shell';
      case 'toml':
        return 'toml';
      case 'xml':
        return 'xml';
      case 'sql':
        return 'sql';
      default:
        return 'plaintext';
    }
  }

  /// Build a lazily-expanded file tree for [rootPath], ignoring junk dirs.
  static FileNode buildTree(String rootPath) {
    final node = FileNode(
      name: rootPath.split(Platform.pathSeparator).last,
      path: rootPath,
      isDir: true,
      expanded: true,
    );
    node.children.addAll(_readDir(rootPath));
    return node;
  }

  static const _ignoredDirs = {
    '.git',
    '.dart_tool',
    '.idea',
    '.vscode',
    'build',
    'node_modules',
    '__pycache__',
    '.next',
    'target',
    'dist',
    '.gradle',
    '.venv',
    'venv',
    'ephemeral',
  };

  static List<FileNode> _readDir(String dirPath) {
    final dir = Directory(dirPath);
    final nodes = <FileNode>[];
    final List<FileSystemEntity> entries;
    try {
      entries = dir.listSync(followLinks: false).toList()
        ..sort((a, b) {
          final aDir = a is Directory;
          final bDir = b is Directory;
          if (aDir != bDir) return aDir ? -1 : 1;
          return a.path.compareTo(b.path);
        });
    } catch (e) {
      throw FsException('Cannot list "$dirPath": $e');
    }
    for (final e in entries) {
      final name = e.path.split(Platform.pathSeparator).last;
      if (name.startsWith('.') && name != '.github' && name != '.nexora') continue;
      if (e is Directory) {
        if (_ignoredDirs.contains(name)) continue;
        nodes.add(FileNode(name: name, path: e.path, isDir: true));
      } else if (e is File) {
        nodes.add(FileNode(name: name, path: e.path, isDir: false));
      }
    }
    return nodes;
  }

  /// Expand (or collapse) is handled by the provider; this returns children.
  static List<FileNode> childrenOf(FileNode node) => _readDir(node.path);

  static String readFile(String path) {
    try {
      final f = File(path);
      if (!f.existsSync()) throw FsException('File not found: $path');
      return f.readAsStringSync();
    } on FsException {
      rethrow;
    } catch (e) {
      // Binary or encoding issue — read bytes lossily.
      try {
        final bytes = File(path).readAsBytesSync();
        return utf8.decode(bytes, allowMalformed: true);
      } catch (e2) {
        throw FsException('Cannot read "$path": $e2');
      }
    }
  }

  static void writeFile(String path, String content) {
    try {
      File(path).writeAsStringSync(content);
    } catch (e) {
      throw FsException('Cannot write "$path": $e');
    }
  }

  static void createFile(String path, {String content = ''}) {
    if (File(path).existsSync()) throw FsException('Already exists: $path');
    try {
      File(path).writeAsStringSync(content);
    } catch (e) {
      throw FsException('Cannot create "$path": $e');
    }
  }

  static void createDir(String path) {
    if (Directory(path).existsSync()) throw FsException('Already exists: $path');
    try {
      Directory(path).createSync(recursive: false);
    } catch (e) {
      throw FsException('Cannot create "$path": $e');
    }
  }

  static void rename(String oldPath, String newPath) {
    try {
      if (Directory(oldPath).existsSync()) {
        Directory(oldPath).renameSync(newPath);
      } else {
        File(oldPath).renameSync(newPath);
      }
    } catch (e) {
      throw FsException('Cannot rename "$oldPath" -> "$newPath": $e');
    }
  }

  /// Delete a file or a whole directory tree. Throws on failure.
  static void delete(String path) {
    try {
      if (Directory(path).existsSync()) {
        Directory(path).deleteSync(recursive: true);
      } else if (File(path).existsSync()) {
        File(path).deleteSync();
      } else {
        throw FsException('Not found: $path');
      }
    } on FsException {
      rethrow;
    } catch (e) {
      throw FsException('Cannot delete "$path": $e');
    }
  }

  /// Recursive content search. Returns hits (max 500) across text files.
  static List<SearchHit> search(String root, String query,
      {bool caseSensitive = false, bool useRegex = false}) {
    final hits = <SearchHit>[];
    if (query.isEmpty) return hits;
    RegExp? regex;
    if (useRegex) {
      try {
        regex = RegExp(query, caseSensitive: caseSensitive);
      } catch (_) {
        return hits;
      }
    }
    final needle = caseSensitive ? query : query.toLowerCase();
    _searchDir(Directory(root), needle, regex, caseSensitive, hits);
    return hits;
  }

  static void _searchDir(Directory dir, String needle, RegExp? regex,
      bool caseSensitive, List<SearchHit> hits) {
    if (hits.length >= 500) return;
    final List<FileSystemEntity> entries;
    try {
      entries = dir.listSync(followLinks: false).toList();
    } catch (_) {
      return;
    }
    for (final e in entries) {
      if (hits.length >= 500) return;
      final name = e.path.split(Platform.pathSeparator).last;
      if (e is Directory) {
        if (_ignoredDirs.contains(name) || name.startsWith('.')) continue;
        _searchDir(e, needle, regex, caseSensitive, hits);
      } else if (e is File) {
        if (_isProbablyBinary(name)) continue;
        final lines = <String>[];
        try {
          lines.addAll(const LineSplitter().convert(
              utf8.decode(e.readAsBytesSync(), allowMalformed: true)));
        } catch (_) {
          continue;
        }
        for (var i = 0; i < lines.length; i++) {
          final hay = caseSensitive ? lines[i] : lines[i].toLowerCase();
          if (regex != null) {
            final m = regex.firstMatch(lines[i]);
            if (m != null) {
              hits.add(SearchHit(
                  path: e.path,
                  line: i + 1,
                  lineText: lines[i],
                  matchStart: m.start,
                  matchEnd: m.end));
              if (hits.length >= 500) return;
            }
          } else {
            final idx = hay.indexOf(needle);
            if (idx != -1) {
              hits.add(SearchHit(
                  path: e.path,
                  line: i + 1,
                  lineText: lines[i],
                  matchStart: idx,
                  matchEnd: idx + needle.length));
              if (hits.length >= 500) return;
            }
          }
        }
      }
    }
  }

  static bool _isProbablyBinary(String name) {
    const binaryExt = {
      'png', 'jpg', 'jpeg', 'gif', 'ico', 'pdf', 'zip', 'gz', 'tar', 'exe',
      'dll', 'so', 'dylib', 'bin', 'woff', 'woff2', 'ttf', 'otf', 'mp3',
      'mp4', 'avi', 'mov', 'class', 'o', 'a', 'lib', 'obj', 'pdb', 'wasm',
    };
    final dot = name.lastIndexOf('.');
    if (dot == -1) return false;
    return binaryExt.contains(name.substring(dot + 1).toLowerCase());
  }
}

class FsException implements Exception {
  final String message;
  FsException(this.message);
  @override
  String toString() => message;
}
