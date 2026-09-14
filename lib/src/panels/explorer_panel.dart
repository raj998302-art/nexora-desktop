import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/editor_provider.dart';
import '../providers/ui_provider.dart';
import '../providers/workspace_provider.dart';
import '../services/fs_service.dart';
import '../theme/app_colors.dart';
import '../widgets/nexora_ui.dart';

/// Explorer panel — the Web Prototype's Explorer.tsx visuals on top of the
/// REAL WorkspaceProvider tree: lazy expand/toggle, open-file on click (with
/// error SnackBars), active-tab highlight, CRUD dialogs with confirmation,
/// right-click context menus, and recursive collapse-all. All provider calls
/// are unchanged from the functional build.
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

  /// Collapse every expanded directory below the root (deepest first). Each
  /// collapse goes through WorkspaceProvider.collapseNode so the tree state
  /// stays owned by the provider (it notifies per node — fine).
  void _collapseAll(WorkspaceProvider ws) {
    final root = ws.root;
    if (root == null) return;
    void visit(FileNode dir) {
      for (final child in dir.children) {
        if (child.isDir) {
          visit(child);
          if (child.expanded) ws.collapseNode(child);
        }
      }
    }

    visit(root);
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
                  borderSide: BorderSide(color: c.blue500)),
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
            child: Text('OK', style: TextStyle(color: c.blue400)),
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
            child: Text('Delete', style: TextStyle(color: c.red400)),
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

  PopupMenuItem<String> _menuItem(String value, String label, AppColors c,
      {Color? color}) {
    return PopupMenuItem<String>(
      value: value,
      height: 30,
      child: Text(
        label,
        style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            color: color ?? c.textPrimary),
      ),
    );
  }

  /// Prototype-styled context menu (bg panelBackground, borderLight, radius 6,
  /// 30px items). The [rowContext] comes from the tree row itself so the
  /// route captures this panel's scoped popup theme (item hover #37373d).
  Future<void> _showContextMenu(WorkspaceProvider ws, FileNode node,
      Offset globalPosition, BuildContext rowContext) async {
    final c = context.read<UiProvider>().palette;
    final overlay =
        Overlay.of(rowContext).context.findRenderObject() as RenderBox;
    final action = await showMenu<String>(
      context: rowContext,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        overlay.size.width - globalPosition.dx,
        overlay.size.height - globalPosition.dy,
      ),
      color: c.panelBackground,
      elevation: 8,
      shadowColor: Colors.black,
      menuPadding: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: c.borderLight),
      ),
      items: [
        if (!node.isDir) _menuItem('open', 'Open', c),
        _menuItem('newfile', 'New File', c),
        _menuItem('newfolder', 'New Folder', c),
        _menuItem('rename', 'Rename…', c),
        _menuItem('delete', 'Delete', c, color: c.red400),
      ],
    );
    if (action == null || !mounted) return;
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
    final c = context.watch<UiProvider>().palette;
    final activePath = editor.activeTab?.path;

    // Scoped theme: the popup menu route captures it from the tree-row
    // contexts below this wrapper (hover #37373d, 13px Inter items, panel
    // background + borderLight + radius 6 + shadow).
    return Theme(
      data: Theme.of(context).copyWith(
        hoverColor: c.selectedBackground,
        popupMenuTheme: PopupMenuThemeData(
          color: c.panelBackground,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: BorderSide(color: c.borderLight),
          ),
          textStyle: TextStyle(
              fontFamily: 'Inter', fontSize: 13, color: c.textPrimary),
        ),
      ),
      child: Container(
        color: c.activityBar,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const NexoraPanelHeader(title: 'Explorer'),
            Expanded(
              child: !ws.hasWorkspace
                  ? _emptyState(c)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _subHeader(ws, c),
                        Expanded(
                          child: ws.root == null
                              ? const SizedBox.shrink()
                              : ListView(
                                  padding:
                                      const EdgeInsets.only(top: 2, bottom: 8),
                                  children: _buildNode(
                                      ws, ws.root!, activePath, c),
                                ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(AppColors c) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.folder_open_outlined, size: 28, color: c.textSecondary),
          const SizedBox(height: 10),
          Text(
            'Open a folder to begin',
            style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: c.textSecondary),
          ),
          const SizedBox(height: 8),
          const NexoraKbd('Ctrl+O'),
        ],
      ),
    );
  }

  /// Prototype Explorer sub-header: "NEXORA" (or the workspace root basename)
  /// 11px bold uppercase + action icons (gap 8, 14px #858585 → white 150ms).
  Widget _subHeader(WorkspaceProvider ws, AppColors c) {
    final rootName = ws.root?.name ?? '';
    final label = rootName.isEmpty ? 'NEXORA' : rootName.toUpperCase();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: c.activityBar,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: c.textPrimary,
              ),
            ),
          ),
          NexoraIconButton(
            icon: Icons.note_add,
            size: 14,
            tooltip: 'New File',
            onPressed: () => _createNewItem(ws, isDir: false),
          ),
          const SizedBox(width: 8),
          NexoraIconButton(
            icon: Icons.create_new_folder_outlined,
            size: 14,
            tooltip: 'New Folder',
            onPressed: () => _createNewItem(ws, isDir: true),
          ),
          const SizedBox(width: 8),
          NexoraIconButton(
            icon: Icons.refresh,
            size: 13,
            tooltip: 'Refresh',
            onPressed: () => _refresh(ws),
          ),
          const SizedBox(width: 8),
          NexoraIconButton(
            icon: Icons.content_copy,
            size: 14,
            tooltip: 'Collapse All',
            onPressed: () => _collapseAll(ws),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildNode(
      WorkspaceProvider ws, FileNode node, String? activePath, AppColors c) {
    final rows = <Widget>[
      _TreeRow(
        node: node,
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
            ? (details, rowContext) =>
                _showContextMenu(ws, node, details.globalPosition, rowContext)
            : null,
      ),
    ];
    if (node.isDir && node.expanded) {
      // Prototype nesting: children container with border-l + ml-24; the rows
      // inside keep their own px-16 padding.
      rows.add(
        Container(
          margin: const EdgeInsets.only(left: 24),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: c.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final child in node.children)
                ..._buildNode(ws, child, activePath, c),
            ],
          ),
        ),
      );
    }
    return rows;
  }
}

// ------------------------------------------------------------------ rows

/// Prototype file-tree row: px 16 py 4, 13px name, 150ms hover fill
/// (#2a2d2e) or active fill (#37373d), extension-colored 14px icon (active
/// file name takes the icon color).
class _TreeRow extends StatefulWidget {
  final FileNode node;
  final bool active;
  final AppColors palette;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onChevronTap;
  final void Function(TapUpDetails details, BuildContext rowContext)?
      onSecondaryTapUp;

  const _TreeRow({
    required this.node,
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

  @override
  Widget build(BuildContext context) {
    final c = widget.palette;
    final node = widget.node;
    final active = widget.active;
    final spec = _iconFor(node.name, c);
    final nameColor = active
        ? (node.isDir ? c.textPrimary : (spec.known ? spec.color : c.textOnAccent))
        : c.textPrimary;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onDoubleTap: widget.onDoubleTap,
        onSecondaryTapUp: widget.onSecondaryTapUp == null
            ? null
            : (details) => widget.onSecondaryTapUp!(details, context),
        child: AnimatedContainer(
          duration: NxMotion.fast,
          curve: NxMotion.curve,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          color: active
              ? c.selectedBackground
              : (_hover ? c.inputBackground : null),
          child: Row(
            children: [
              if (node.isDir) ...[
                SizedBox(
                  width: 18,
                  height: 18,
                  child: InkWell(
                    onTap: widget.onChevronTap,
                    child: Center(
                      child: Icon(
                        node.expanded
                            ? Icons.expand_more
                            : Icons.chevron_right,
                        size: 14,
                        color: c.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 2),
              ],
              Icon(
                node.isDir
                    ? (node.expanded
                        ? Icons.folder_open
                        : Icons.folder_outlined)
                    : spec.icon,
                size: 14,
                color: node.isDir ? c.warning : spec.color,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  node.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: nameColor,
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

// ------------------------------------------------------------- icon spec

class _IconSpec {
  final IconData icon;
  final Color color;
  final bool known; // extension had a prototype-specific mapping
  const _IconSpec(this.icon, this.color, this.known);
}

/// Prototype Explorer icon mapping (icon 14, colored by extension).
_IconSpec _iconFor(String name, AppColors c) {
  final dot = name.lastIndexOf('.');
  final ext = dot == -1 ? '' : name.substring(dot + 1).toLowerCase();
  switch (ext) {
    case 'dart':
    case 'ts':
    case 'tsx':
    case 'js':
    case 'jsx':
      return _IconSpec(Icons.code, c.blueLight, true);
    case 'json':
      return _IconSpec(Icons.data_object, c.iconJson, true);
    case 'css':
      return _IconSpec(Icons.code, c.iconCss, true);
    case 'md':
      return _IconSpec(Icons.description, c.iconMd, true);
    case 'svg':
    case 'png':
    case 'jpg':
    case 'jpeg':
      return _IconSpec(Icons.image_outlined, c.iconSvg, true);
    case 'py':
      return _IconSpec(Icons.code, c.success, true);
    default:
      return _IconSpec(Icons.description, c.textSecondary, false);
  }
}
