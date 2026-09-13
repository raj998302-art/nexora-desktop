import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class CodeEditor extends StatelessWidget {
  const CodeEditor({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Tabs
        Container(
          height: 35,
          color: AppColors.activityBar,
          child: Row(
            children: [
              _buildTab('main.dart', true),
              _buildTab('pubspec.yaml', false),
            ],
          ),
        ),
        // Breadcrumbs
        Container(
          height: 24,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: const BoxDecoration(
            color: AppColors.editorBackground,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: const [
              Text('lib', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              Icon(Icons.chevron_right, size: 14, color: AppColors.textSecondary),
              Text('main.dart', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
        ),
        // Editor content
        Expanded(
          child: Container(
            color: AppColors.editorBackground,
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Line numbers
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(20, (index) => Text('\${index + 1}', style: const TextStyle(color: AppColors.textSecondary, fontFamily: 'monospace', fontSize: 13, height: 1.5))),
                ),
                const SizedBox(width: 16),
                // Code
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('import \'package:flutter/material.dart\';', style: TextStyle(color: AppColors.blueLight, fontFamily: 'monospace', fontSize: 13, height: 1.5)),
                        SizedBox(height: 20),
                        Text('void main() {', style: TextStyle(color: AppColors.textPrimary, fontFamily: 'monospace', fontSize: 13, height: 1.5)),
                        Text('  runApp(const MyApp());', style: TextStyle(color: AppColors.textPrimary, fontFamily: 'monospace', fontSize: 13, height: 1.5)),
                        Text('}', style: TextStyle(color: AppColors.textPrimary, fontFamily: 'monospace', fontSize: 13, height: 1.5)),
                      ],
                    ),
                  ),
                ),
                // Minimap Mock
                Container(
                  width: 50,
                  decoration: const BoxDecoration(
                    border: Border(left: BorderSide(color: AppColors.borderLight)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(height: 2, width: 30, color: AppColors.blueLight.withOpacity(0.5), margin: const EdgeInsets.only(bottom: 4, left: 4)),
                      Container(height: 2, width: 20, color: AppColors.textPrimary.withOpacity(0.5), margin: const EdgeInsets.only(bottom: 4, left: 4)),
                      Container(height: 2, width: 40, color: AppColors.textPrimary.withOpacity(0.5), margin: const EdgeInsets.only(bottom: 4, left: 8)),
                      Container(height: 2, width: 10, color: AppColors.textPrimary.withOpacity(0.5), margin: const EdgeInsets.only(bottom: 4, left: 4)),
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTab(String title, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isActive ? AppColors.editorBackground : Colors.transparent,
        border: Border(
          top: BorderSide(color: isActive ? AppColors.accentBlue : Colors.transparent, width: 2),
          right: const BorderSide(color: AppColors.border),
        ),
      ),
      child: Row(
        children: [
          Icon(title.endsWith('.dart') ? Icons.code : Icons.settings, size: 14, color: AppColors.blueLight),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(color: isActive ? AppColors.blueLight : AppColors.textSecondary, fontSize: 12)),
          const SizedBox(width: 8),
          const Icon(Icons.close, size: 14, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}
