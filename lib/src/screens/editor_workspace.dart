import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../editor/code_editor.dart';
import '../terminal/terminal_pane.dart';
import '../chat/ai_chat.dart';
import 'explorer_panel.dart';

class EditorWorkspace extends StatelessWidget {
  const EditorWorkspace({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Left Panel (Explorer/Search/Git/Extensions)
        const ExplorerPanel(),
        
        // Center (Code Editor + Terminal)
        Expanded(
          child: Column(
            children: const [
              Expanded(
                child: CodeEditor(),
              ),
              TerminalPane(),
            ],
          ),
        ),
        
        // Right Panel (AI Chat)
        const AiChat(),
      ],
    );
  }
}
