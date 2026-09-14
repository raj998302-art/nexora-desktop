import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../chat/ai_chat.dart';
import '../editor/code_editor.dart';
import '../panels/explorer_panel.dart';
import '../panels/git_panel.dart';
import '../panels/search_panel.dart';
import '../providers/ui_provider.dart';
import '../terminal/terminal_pane.dart';

/// Editor screen: [left panel | editor + terminal | AI chat] with REAL working
/// drag dividers wired to UiProvider sizes (audit fix #4: previously the right
/// divider did nothing and AiChat had a fixed width).
class EditorWorkspace extends StatelessWidget {
  const EditorWorkspace({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ui = context.watch<UiProvider>();
    final c = ui.palette;

    return LayoutBuilder(builder: (context, constraints) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---------------- Left panel ----------------
          if (ui.sidebarOpen) ...[
            SizedBox(
              width: ui.leftPanelWidth,
              child: _leftPanel(ui),
            ),
            _VDivider(
              color: c.borderLight,
              onDrag: (dx) => ui.setLeftPanelWidth(ui.leftPanelWidth + dx),
            ),
          ],

          // ---------------- Center: editor + terminal ----------------
          Expanded(
            child: Column(
              children: [
                const Expanded(child: CodeEditor()),
                if (ui.terminalOpen) ...[
                  _HDivider(
                    color: c.borderLight,
                    onDrag: (dy) => ui.setTerminalHeight(ui.terminalHeight - dy),
                  ),
                  SizedBox(
                    height: ui.terminalHeight,
                    child: const TerminalPane(),
                  ),
                ],
              ],
            ),
          ),

          // ---------------- Right: AI chat ----------------
          if (ui.rightPanelOpen) ...[
            _VDivider(
              color: c.borderLight,
              onDrag: (dx) => ui.setRightPanelWidth(ui.rightPanelWidth - dx),
            ),
            SizedBox(
              width: ui.rightPanelWidth,
              child: const AiChat(),
            ),
          ],
        ],
      );
    });
  }

  Widget _leftPanel(UiProvider ui) {
    switch (ui.leftPanelMode) {
      case LeftPanelMode.explorer:
        return const ExplorerPanel();
      case LeftPanelMode.search:
        return const SearchPanel();
      case LeftPanelMode.git:
        return const GitPanel();
    }
  }
}

/// Vertical splitter the user can drag. Calls [onDrag] with the horizontal
/// delta so the owner can resize its neighbor.
class _VDivider extends StatelessWidget {
  final Color color;
  final void Function(double dx) onDrag;

  const _VDivider({required this.color, required this.onDrag});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: (d) => onDrag(d.delta.dx),
      onDoubleTap: () {},
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeLeftRight,
        child: Container(width: 4, color: color),
      ),
    );
  }
}

/// Horizontal splitter (terminal resize).
class _HDivider extends StatelessWidget {
  final Color color;
  final void Function(double dy) onDrag;

  const _HDivider({required this.color, required this.onDrag});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: (d) => onDrag(d.delta.dy),
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeUpDown,
        child: Container(height: 4, color: color),
      ),
    );
  }
}
