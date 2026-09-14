import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/editor_provider.dart';
import '../providers/ui_provider.dart';
import '../providers/workspace_provider.dart';
import '../services/fs_service.dart';
import '../theme/app_colors.dart';

/// Workspace file tree: open/toggle nodes, create/rename/delete with dialogs
/// and context menus, real error surfacing on every FS failure.
class ExplorerPanel extends StatefulWidget {
  const ExplorerPanel({Key? key}) : super(key: key);

  @override
  State<ExplorerPanel> createState() => _ExplorerPanelState();
}

class _ExplorerPanelState extends State<ExplorerPanel> {
  String? _selectedPath; // last clicked node (file or dir)

  // ------------------------------------------------------------- helpers

  void _errorSnack(Object e) {
    final c = context.read<UiProvider>().palette;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: c.error,
        content: Text('$e',
            style: TextStyle(color: c.textOnAccent, fontSize: 12)),
      ),
    );
  }

  /// Parent directory that new items should be created in: the selected dir,
  /// the selected file's parent, or the workspace root.
  String _creationRoot(WorkspaceProvider ws) {
    final sel = _selectedPath;
    if (sel != null) {
      final node = ws.findByPath(sel);
      if (node != null && node.isDir) return node.path;
      final idx = sel.lastIndexOf(Platform.pathSeparator);
      if (idx > 0) return sel.substring(0, idx);
    }
    return ws.rootPath!;
  }

  Future<void> _refresh(WorkspaceProvider ws) async {
    try {
      await ws.refresh();
    } catch (e) {
      _errorSnack(e);
    }
  }

  // -------------------------------------------------------------- dialogs

  Future<String?> _promptName(String title, String label, {String? initial}) {
    final c = context.read<UiProvider>().palette;
    final controller = TextEditingController(text: initial ?? '');
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.panelBackground,
        title: Text(title, style: TextStyle(color: c.textPrimary, fontSize: 15)),
        content: SizedBox(
          width: 320,
          child: TextField(
            controller: controller,
            autofocus: true,
            style: TextStyle(color: c.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: label,
              hintStyle: TextStyle(color: c.textSecondary, fontSize: 12),
              enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: c.borderLight)),
              focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: c.accent)),
            ),
            onSubmitted: (v) => Navigator.of(ctx).pop(v),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: TextStyle(color: c.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: Text('OK', style: TextStyle(color: c.accent)),
          ),
        ],
      ),
    );
  }

  Future<void> _createNewItem(WorkspaceProvider ws, {required bool isDir}) {
    final root = _creationRoot(ws);
    return _promptName(isDir ? 'New Folder' : 'New File',
            isDir ? 'Folder name' : 'File name (e.g. utils.dart)')
        .then((name) async {
      if (name == null || name.trim().isEmpty) return;
      final clean = name.trim();
      try {
        if (isDir) {
          await ws.createDir(root, clean);
        } else {
          await ws.createFile(root, clean);
          try {
            final sep = Platform.pathSeparator;
            context
                .read<EditorProvider>()
                .openFile('$root$sep$clean');
          } catch (_) {/* opening the fresh file is best-effort */}
        }
      } catch (e) {
        _errorSnack(e); // real error, e.g. "Already exists"
      }
    });
  }

  Future<void> _renameNode(WorkspaceProvider ws, FileNode node) async {
    final name = await _promptName('Rename', 'New name', initial: node.name);
    if (name == null || name.trim().isEmpty || name.trim() == node.name) return;
    try {
      await ws.rename(node.path, name.trim());
      setState(() {
        if (_selectedPath == node.path) {
          final idx = node.path.lastIndexOf(Platform.pathSeparator);
          _selectedPath = idx > 0
              ? '${node.path.substring(0, idx)}${Platform.pathSeparator}${name.trim()}'
              : name.trim();
        }
      });
    } catch (e) {
      _errorSnack(e);
    }
  }

  Future<void> _deleteNode(WorkspaceProvider ws, FileNode node) async {
    final c = context.read<UiProvider>().palette;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.panelBackground,
        title:
            Text('Delete?', style: TextStyle(color: c.textPrimary, fontSize: 15)),
        content: Text(
          'Delete ${node.name}? This cannot be undone.',
          style: TextStyle(color: c.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: TextStyle(color: c.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Delete', style: TextStyle(color: c.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      // deleteNode closes ALL descendant tabs first (audit fix #6) and
      // throws on failure so the real error reaches the user (audit fix #7).
      await ws.deleteNode(node.path);
    } catch (e) {
      _errorSnack(e);
    }
  }

  // -------------------------------------------------------- context menu

  Future<void> _showContextMenu(
      WorkspaceProvider ws, FileNode node, Offset globalPosition) async {
    final c = context.read<UiProvider>().palette;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        overlay.size.width - globalPosition.dx,
        overlay.size.height - globalPosition.dy,
      ),
      color: c.panelBackground,
      items: [
        if (!node.isDir)
          PopupMenuItem(
            value: 'open',
            height: 34,
            child: Text('Open',
                style: TextStyle(color: c.textPrimary, fontSize: 13)),
          ),
        PopupMenuItem(
            value: 'newfile',
            height: 34,
            child: Text('New File',
                style: TextStyle(color: c.textPrimary, fontSize: 13))),
        PopupMenuItem(
            value: 'newfolder',
            height: 34,
            child: Text('New Folder',
                style: TextStyle(color: c.textPrimary, fontSize: 13))),
        PopupMenuItem(
            value: 'rename',
            height: 34,
            child: Text('Rename…',
                style: TextStyle(color: c.textPrimary, fontSize: 13))),
        PopupMenuItem(
            value: 'delete',
            height: 34,
            child: Text('Delete',
                style: TextStyle(color: c.error, fontSize: 13))),
      ],
    );
    if (action == null) return;
    switch (action) {
      case 'open':
        _openFile(node);
        break;
      case 'newfile':
        setState(() => _selectedPath = node.path);
        await _createNewItem(ws, isDir: false);
        break;
      case 'newfolder':
        setState(() => _selectedPath = node.path);
        await _createNewItem(ws, isDir: true);
        break;
      case 'rename':
        await _renameNode(ws, node);
        break;
      case 'delete':
        await _deleteNode(ws, node);
        break;
    }
  }

  void _openFile(FileNode node) {
    try {
      context.read<EditorProvider>().openFile(node.path);
    } on FsException catch (e) {
      _errorSnack(e);
    }
  }

  // --------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final ws = context.watch<WorkspaceProvider>();
    final editor = context.watch<EditorProvider>();
    final c = context.read<UiProvider>().palette;
    final activePath = editor.activeTab?.path;

    return Container(
      decoration: BoxDecoration(
        color: c.activityBar,
        border: Border(right: BorderSide(color: c.border)),
      ),
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
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'EXPLORER',
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                _HeaderIcon(
                  icon: Icons.post_add,
                  tooltip: 'New File',
                  palette: c,
                  onTap: ws.hasWorkspace
                      ? () => _createNewItem(ws, isDir: false)
                      : null,
                ),
                _HeaderIcon(
                  icon: Icons.create_new_folder,
                  tooltip: 'New Folder',
                  palette: c,
                  onTap: ws.hasWorkspace
                      ? () => _createNewItem(ws, isDir: true)
                      : null,
                ),
                _HeaderIcon(
                  icon: Icons.refresh,
                  tooltip: 'Refresh',
                  palette: c,
                  onTap: ws.hasWorkspace ? () => _refresh(ws) : null,
                ),
              ],
            ),
          ),
          Expanded(
            child: !ws.hasWorkspace
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Open a folder to begin',
                            style: TextStyle(
                                color: c.textSecondary, fontSize: 12)),
                        const SizedBox(height: 6),
                        Text('Ctrl+O opens a recent folder',
                            style: TextStyle(
                                color: c.textSecondary, fontSize: 11)),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.only(top: 2),
                    children: ws.root == null
                        ? const <Widget>[]
                        : _buildNode(ws, ws.root!, 0, activePath),
                  ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildNode(
      WorkspaceProvider ws, FileNode node, int level, String? activePath) {
    final c = context.read<UiProvider>().palette;
    final rows = <Widget>[
      _TreeRow(
        node: node,
        level: level,
        active: activePath == node.path,
        palette: c,
        onTap: () {
          setState(() => _selectedPath = node.path);
          if (!node.isDir) _openFile(node);
        },
        onDoubleTap: node.isDir
            ? () {
                setState(() => _selectedPath = node.path);
                ws.toggleNode(node);
              }
            : null,
        onChevronTap: node.isDir
            ? () {
                setState(() => _selectedPath = node.path);
                ws.toggleNode(node);
              }
            : null,
        onSecondaryTapUp: ws.hasWorkspace
            ? (details) =>
                _showContextMenu(ws, node, details.globalPosition)
            : null,
      ),
    ];
    if (node.isDir && node.expanded) {
      for (final child in node.children) {
        rows.addAll(_buildNode(ws, child, level + 1, activePath));
      }
    }
    return rows;
  }
}

class _TreeRow extends StatefulWidget {
  final FileNode node;
  final int level;
  final bool active;
  final AppColors palette;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onChevronTap;
  final void Function(TapUpDetails details)? onSecondaryTapUp;

  const _TreeRow({
    required this.node,
    required this.level,
    required this.active,
    required this.palette,
    required this.onTap,
    this.onDoubleTap,
    this.onChevronTap,
    this.onSecondaryTapUp,
  });

  @override
  State<_TreeRow> createState() => _TreeRowState();
}

class _TreeRowState extends State<_TreeRow> {
  bool _hover = false;

  IconData _fileIcon(String name) {
    final dot = name.lastIndexOf('.');
    final ext = dot == -1 ? '' : name.substring(dot + 1).toLowerCase();
    switch (ext) {
      case 'dart':
      case 'py':
      case 'js':
      case 'ts':
      case 'c':
      case 'cpp':
      case 'rs':
      case 'go':
      case 'java':
      case 'sh':
        return Icons.code;
      case 'md':
      case 'txt':
        return Icons.description;
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'gif':
      case 'svg':
      case 'webp':
      case 'ico':
        return Icons.image;
      case 'json':
      case 'yaml':
      case 'yml':
      case 'toml':
      case 'xml':
      case 'ini':
      case 'cfg':
        return Icons.settings;
      default:
        return Icons.description;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.palette;
    final node = widget.node;
    final active = widget.active;
    final hovered = _hover && !active;

    Color rowBg;
    if (active) {
      rowBg = c.panelBackground;
    } else if (hovered) {
      rowBg = c.borderLight.withValues(alpha: 0.18);
    } else {
      rowBg = const Color(0x00000000);
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onDoubleTap: widget.onDoubleTap,
        onSecondaryTapUp: widget.onSecondaryTapUp,
        child: Container(
          height: 26,
          padding: EdgeInsets.only(left: 8.0 + widget.level * 12.0, right: 6),
          decoration: BoxDecoration(
            color: rowBg,
            border: Border(
              left: BorderSide(
                width: 2,
                color: active ? c.accent : const Color(0x00000000),
              ),
            ),
          ),
          child: Row(
            children: [
              if (node.isDir)
                SizedBox(
                  width: 16,
                  child: InkWell(
                    onTap: widget.onChevronTap,
                    child: Icon(
                      node.expanded ? Icons.expand_more : Icons.chevron_right,
                      size: 16,
                      color: c.textSecondary,
                    ),
                  ),
                )
              else
                const SizedBox(width: 16),
              const SizedBox(width: 2),
              Icon(
                node.isDir ? Icons.folder : _fileIcon(node.name),
                size: node.isDir ? 16 : 15,
                color: node.isDir ? c.warning : c.blueLight,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  node.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: active
                        ? c.blueLight
                        : (node.isDir ? c.textPrimary : c.textPrimary),
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

class _HeaderIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final AppColors palette;
  final VoidCallback? onTap;

  const _HeaderIcon({
    required this.icon,
    required this.tooltip,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
      padding: const EdgeInsets.all(4),
      icon: Icon(
        icon,
        size: 14,
        color: enabled ? palette.textSecondary : palette.textSecondary.withValues(alpha: 0.4),
      ),
      onPressed: onTap,
    );
  }
}
