import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/app_colors.dart';

class AiChat extends StatelessWidget {
  const AiChat({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      decoration: const BoxDecoration(
        color: AppColors.editorBackground,
        border: Border(left: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          // Chat Header
          Container(
            height: 35,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(
              color: AppColors.activityBar,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(LucideIcons.sparkles, size: 14, color: AppColors.blueLight),
                    SizedBox(width: 8),
                    Text('Composer', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  ],
                ),
                Row(
                  children: const [
                    Icon(LucideIcons.history, size: 14, color: AppColors.textSecondary),
                    SizedBox(width: 8),
                    Icon(LucideIcons.maximize2, size: 14, color: AppColors.textSecondary),
                    SizedBox(width: 8),
                    Icon(LucideIcons.moreHorizontal, size: 14, color: AppColors.textSecondary),
                  ],
                ),
              ],
            ),
          ),
          
          // Messages
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildUserMessage('Rewrite the entire application UI natively in Flutter without WebViews.'),
                const SizedBox(height: 16),
                _buildAiMessage('I have completely rebuilt the UI in native Flutter! We are now using real Flutter Widgets instead of a webview wrapper. The architecture has been properly structured.'),
              ],
            ),
          ),
          
          // Input Box
          Container(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.panelBackground,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: TextField(
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Tell NEXORA what to build...',
                        hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: AppColors.borderLight)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(LucideIcons.zap, size: 14, color: AppColors.blueLight),
                            const SizedBox(width: 4),
                            const Text('Agent', style: TextStyle(color: AppColors.blueLight, fontSize: 12)),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_drop_down, size: 16, color: AppColors.textSecondary),
                            const SizedBox(width: 8),
                            const Icon(LucideIcons.atSign, size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 8),
                            const Icon(LucideIcons.brain, size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 8),
                            const Icon(LucideIcons.globe, size: 14, color: AppColors.textSecondary),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.accentBlue,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(LucideIcons.send, size: 12, color: Colors.white),
                        )
                      ],
                    ),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildUserMessage(String text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('You', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.panelBackground,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Text(text, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
        ),
      ],
    );
  }

  Widget _buildAiMessage(String text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(LucideIcons.sparkles, size: 14, color: AppColors.blueLight),
            SizedBox(width: 4),
            Text('NEXORA Agent', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.blueLight)),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.editorBackground,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Text(text, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
        ),
      ],
    );
  }
}
