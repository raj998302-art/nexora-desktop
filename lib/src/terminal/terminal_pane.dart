import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/app_colors.dart';

class TerminalPane extends StatelessWidget {
  const TerminalPane({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 250,
      decoration: const BoxDecoration(
        color: AppColors.editorBackground,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Terminal Header
          Container(
            height: 35,
            color: AppColors.activityBar,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    _buildTab('PROBLEMS', false),
                    _buildTab('OUTPUT', false),
                    _buildTab('DEBUG CONSOLE', false),
                    _buildTab('TERMINAL', true),
                    _buildTab('PORTS', false),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.panelBackground,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Row(
                        children: const [
                          Icon(LucideIcons.terminalSquare, size: 12, color: AppColors.textPrimary),
                          SizedBox(width: 4),
                          Text('bash', style: TextStyle(color: AppColors.textPrimary, fontSize: 11)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(LucideIcons.plus, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    const Icon(LucideIcons.splitSquareHorizontal, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    const Icon(LucideIcons.trash2, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    const Icon(LucideIcons.x, size: 14, color: AppColors.textSecondary),
                  ],
                )
              ],
            ),
          ),
          // Terminal Output
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: const TextSpan(
                        style: TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.5),
                        children: [
                          TextSpan(text: 'user@nexora', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold)),
                          TextSpan(text: ':', style: TextStyle(color: Colors.white)),
                          TextSpan(text: '~/nexora_desktop', style: TextStyle(color: AppColors.blueLight, fontWeight: FontWeight.bold)),
                          TextSpan(text: '\$ ', style: TextStyle(color: Colors.white)),
                          TextSpan(text: 'flutter build windows --release\n', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                    const Text('Building Windows application...', style: TextStyle(color: AppColors.textSecondary, fontFamily: 'monospace', fontSize: 13, height: 1.5)),
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTab(String title, bool isActive) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: TextStyle(color: isActive ? Colors.white : AppColors.textSecondary, fontSize: 11, fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
          if (isActive) Container(height: 2, width: 40, color: AppColors.accentBlue, margin: const EdgeInsets.only(top: 4)),
        ],
      ),
    );
  }
}
