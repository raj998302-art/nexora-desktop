import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/app_colors.dart';

class TopBar extends StatelessWidget {
  const TopBar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (details) {
        windowManager.startDragging();
      },
      child: Container(
        height: 35,
        color: AppColors.background,
        child: Row(
          children: [
            // Mac-like traffic lights (mock)
            const SizedBox(width: 16),
            _buildTrafficLight(Colors.red),
            const SizedBox(width: 8),
            _buildTrafficLight(Colors.orange),
            const SizedBox(width: 8),
            _buildTrafficLight(Colors.green),
            const SizedBox(width: 24),
            
            // Menus
            _buildMenuText('File'),
            _buildMenuText('Edit'),
            _buildMenuText('Selection'),
            _buildMenuText('View'),
            _buildMenuText('Go'),
            _buildMenuText('Run'),
            _buildMenuText('Terminal'),
            
            const Spacer(),
            
            // Central Search Mock
            Container(
              width: 300,
              height: 24,
              decoration: BoxDecoration(
                color: AppColors.panelBackground,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(LucideIcons.search, size: 12, color: AppColors.textSecondary),
                  SizedBox(width: 8),
                  Text('NEXORA', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            
            const Spacer(),
            
            // Window Controls (Windows style)
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove, size: 16, color: AppColors.textSecondary),
                  onPressed: () => windowManager.minimize(),
                  splashRadius: 16,
                ),
                IconButton(
                  icon: const Icon(Icons.crop_square, size: 16, color: AppColors.textSecondary),
                  onPressed: () => windowManager.maximize(),
                  splashRadius: 16,
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 16, color: AppColors.textSecondary),
                  onPressed: () => windowManager.close(),
                  splashRadius: 16,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrafficLight(Color color) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildMenuText(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
      ),
    );
  }
}
