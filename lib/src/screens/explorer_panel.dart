import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class ExplorerPanel extends StatelessWidget {
  const ExplorerPanel({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      decoration: const BoxDecoration(
        color: AppColors.activityBar,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('EXPLORER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                Row(
                  children: const [
                    Icon(Icons.star, size: 14, color: AppColors.textSecondary),
                    SizedBox(width: 8),
                    Icon(Icons.star, size: 14, color: AppColors.textSecondary),
                    SizedBox(width: 8),
                    Icon(Icons.star, size: 14, color: AppColors.textSecondary),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildFolder('lib', true, [
                  _buildFolder('src', true, [
                    _buildFolder('screens', false, []),
                    _buildFolder('widgets', false, []),
                    _buildFile('main_layout.dart', false),
                  ]),
                  _buildFile('main.dart', true),
                ]),
                _buildFolder('windows', false, []),
                _buildFile('pubspec.yaml', false),
                _buildFile('README.md', false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFolder(String name, bool isOpen, List<Widget> children) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Icon(isOpen ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Icon(isOpen ? Icons.folder_open : Icons.folder, size: 16, color: Colors.amber[300]),
              const SizedBox(width: 8),
              Text(name, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
            ],
          ),
        ),
        if (isOpen)
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Column(
              children: children,
            ),
          )
      ],
    );
  }

  Widget _buildFile(String name, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 4),
      color: isActive ? AppColors.panelBackground : Colors.transparent,
      child: Row(
        children: [
          Icon(name.endsWith('.dart') ? Icons.code : Icons.description, size: 16, color: AppColors.blueLight),
          const SizedBox(width: 8),
          Text(name, style: TextStyle(color: isActive ? AppColors.blueLight : AppColors.textPrimary, fontSize: 13)),
        ],
      ),
    );
  }
}
