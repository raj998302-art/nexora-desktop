import 'package:flutter/material.dart';
import 'package:provider/provider.dart';


import '../providers/ui_provider.dart';
import '../theme/app_colors.dart';

class ActivityBar extends StatelessWidget {
  const ActivityBar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final uiState = context.watch<UiProvider>();

    return Container(
      width: 48,
      color: AppColors.activityBar,
      child: Column(
        children: [
          const SizedBox(height: 12),
          _ActivityIcon(
            icon: Icons.star,
            isActive: uiState.view == ViewMode.home,
            onTap: () => uiState.setView(ViewMode.home),
          ),
          const SizedBox(height: 8),
          Container(height: 1, width: 32, color: AppColors.border),
          const SizedBox(height: 8),
          
          _ActivityIcon(
            icon: Icons.star,
            isActive: uiState.leftPanelMode == LeftPanelMode.explorer && uiState.view != ViewMode.home,
            onTap: () {
              uiState.setLeftPanelMode(LeftPanelMode.explorer);
              if (uiState.view != ViewMode.editor) uiState.setView(ViewMode.editor);
            },
          ),
          _ActivityIcon(
            icon: Icons.star,
            isActive: uiState.leftPanelMode == LeftPanelMode.search && uiState.view != ViewMode.home,
            onTap: () {
              uiState.setLeftPanelMode(LeftPanelMode.search);
              if (uiState.view != ViewMode.editor) uiState.setView(ViewMode.editor);
            },
          ),
          _ActivityIcon(
            icon: Icons.star,
            isActive: uiState.leftPanelMode == LeftPanelMode.git && uiState.view != ViewMode.home,
            onTap: () {
              uiState.setLeftPanelMode(LeftPanelMode.git);
              if (uiState.view != ViewMode.editor) uiState.setView(ViewMode.editor);
            },
          ),
          
          const Spacer(),
          
          _ActivityIcon(
            icon: Icons.star,
            isActive: false,
            onTap: () {},
          ),
          _ActivityIcon(
            icon: Icons.star,
            isActive: uiState.view == ViewMode.settings,
            onTap: () => uiState.setView(ViewMode.settings),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _ActivityIcon extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _ActivityIcon({
    Key? key,
    required this.icon,
    required this.isActive,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 48,
        width: 48,
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: isActive ? AppColors.accentBlue : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Icon(
          icon,
          size: 24,
          color: isActive ? Colors.white : AppColors.textSecondary,
        ),
      ),
    );
  }
}
