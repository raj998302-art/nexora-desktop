import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import '../providers/ui_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/activity_bar.dart';
import '../widgets/top_bar.dart';
import 'home_dashboard.dart';
import 'editor_workspace.dart';

class MainLayout extends StatelessWidget {
  const MainLayout({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final uiState = context.watch<UiProvider>();

    return Scaffold(
      body: Column(
        children: [
          // Custom Window Title Bar
          const TopBar(),
          
          // Main Body
          Expanded(
            child: Row(
              children: [
                // Activity Bar (Leftmost narrow strip)
                const ActivityBar(),
                
                // Workspace Area
                Expanded(
                  child: uiState.view == ViewMode.home 
                      ? const HomeDashboard() 
                      : const EditorWorkspace(),
                ),
              ],
            ),
          ),
          
          // Status Bar
          Container(
            height: 22,
            color: AppColors.accentBlue,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(Icons.merge_type, size: 14, color: Colors.white),
                    SizedBox(width: 4),
                    Text('main*', style: TextStyle(fontSize: 12, color: Colors.white)),
                  ],
                ),
                Row(
                  children: const [
                    Text('Ln 1, Col 1', style: TextStyle(fontSize: 12, color: Colors.white)),
                    SizedBox(width: 16),
                    Text('UTF-8', style: TextStyle(fontSize: 12, color: Colors.white)),
                    SizedBox(width: 16),
                    Text('Flutter', style: TextStyle(fontSize: 12, color: Colors.white)),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
