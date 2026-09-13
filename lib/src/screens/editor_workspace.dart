import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class EditorWorkspace extends StatelessWidget {
  const EditorWorkspace({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Left Panel Mock
        Container(
          width: 250,
          decoration: const BoxDecoration(
            color: AppColors.activityBar,
            border: Border(right: BorderSide(color: AppColors.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Padding(
                padding: EdgeInsets.all(12.0),
                child: Text('EXPLORER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              ),
              Expanded(
                child: Center(child: Text('File Tree...', style: TextStyle(color: AppColors.textSecondary))),
              ),
            ],
          ),
        ),
        
        // Editor + Terminal
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: Container(
                  color: AppColors.editorBackground,
                  child: const Center(
                    child: Text('// Flutter Code Editor Area', style: TextStyle(color: AppColors.blueLight, fontFamily: 'monospace')),
                  ),
                ),
              ),
              // Terminal Mock
              Container(
                height: 200,
                decoration: const BoxDecoration(
                  color: AppColors.editorBackground,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      color: AppColors.activityBar,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: const [
                          Text('TERMINAL', style: TextStyle(fontSize: 11, color: AppColors.textPrimary)),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text('user@nexora:~\$ flutter run', style: TextStyle(color: AppColors.textPrimary, fontFamily: 'monospace')),
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
        
        // Right Panel (AI Chat)
        Container(
          width: 300,
          decoration: const BoxDecoration(
            color: AppColors.editorBackground,
            border: Border(left: BorderSide(color: AppColors.border)),
          ),
          child: const Center(child: Text('AI Chat Composer', style: TextStyle(color: AppColors.textSecondary))),
        )
      ],
    );
  }
}
