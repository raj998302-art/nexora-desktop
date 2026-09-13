#!/bin/bash
set -e

cd /root/nexora_desktop/lib/src

mkdir -p app screens widgets theme models providers services state navigation editor terminal agents chat git extensions plugins settings

# Theme
cat << 'THEME' > theme/app_colors.dart
import 'package:flutter/material.dart';
class AppColors {
  static const Color background = Color(0xFF1E1E1E);
  static const Color activityBar = Color(0xFF181818);
  static const Color panelBackground = Color(0xFF252526);
  static const Color border = Color(0xFF2B2B2B);
  static const Color borderLight = Color(0xFF3C3C3C);
  static const Color textPrimary = Color(0xFFCCCCCC);
  static const Color textSecondary = Color(0xFF858585);
  static const Color accentBlue = Color(0xFF007ACC);
  static const Color blueLight = Color(0xFF519ABA);
  static const Color editorBackground = Color(0xFF1E1E1E);
  static const Color success = Color(0xFF4EC9B0);
  static const Color warning = Color(0xFFCE9178);
  static const Color error = Color(0xFFF14C4C);
}
THEME

# Providers
cat << 'PROV' > providers/ui_provider.dart
import 'package:flutter/material.dart';

enum ViewMode { home, editor, settings, extensions, plugins, agents }
enum LeftPanelMode { explorer, search, git, extensions }
enum AiMode { normal, agent, architect }

class UiProvider extends ChangeNotifier {
  ViewMode _view = ViewMode.home;
  LeftPanelMode _leftPanelMode = LeftPanelMode.explorer;
  AiMode _aiMode = AiMode.agent;
  bool _sidebarOpen = true;
  bool _rightPanelOpen = true;

  ViewMode get view => _view;
  LeftPanelMode get leftPanelMode => _leftPanelMode;
  AiMode get aiMode => _aiMode;
  bool get sidebarOpen => _sidebarOpen;
  bool get rightPanelOpen => _rightPanelOpen;

  void setView(ViewMode newView) { _view = newView; notifyListeners(); }
  void setLeftPanelMode(LeftPanelMode mode) { _leftPanelMode = mode; notifyListeners(); }
  void setAiMode(AiMode mode) { _aiMode = mode; notifyListeners(); }
  void toggleSidebar() { _sidebarOpen = !_sidebarOpen; notifyListeners(); }
  void toggleRightPanel() { _rightPanelOpen = !_rightPanelOpen; notifyListeners(); }
}
PROV

