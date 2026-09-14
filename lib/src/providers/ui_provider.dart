import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum ViewMode { home, editor, settings }
enum LeftPanelMode { explorer, search, git }

/// Global UI state: which view is active, panel toggles + SIZES (drag dividers
/// actually work — audit fix #4), and theme.
class UiProvider extends ChangeNotifier {
  ViewMode _view = ViewMode.home;
  LeftPanelMode _leftPanelMode = LeftPanelMode.explorer;
  bool _sidebarOpen = true;
  bool _rightPanelOpen = true;
  bool _terminalOpen = false;

  double _leftPanelWidth = 250;
  double _rightPanelWidth = 320;
  double _terminalHeight = 240;

  ThemeMode _themeMode = ThemeMode.dark;

  ViewMode get view => _view;
  LeftPanelMode get leftPanelMode => _leftPanelMode;
  bool get sidebarOpen => _sidebarOpen;
  bool get rightPanelOpen => _rightPanelOpen;
  bool get terminalOpen => _terminalOpen;
  double get leftPanelWidth => _leftPanelWidth;
  double get rightPanelWidth => _rightPanelWidth;
  double get terminalHeight => _terminalHeight;
  ThemeMode get themeMode => _themeMode;

  AppColors get palette =>
      _themeMode == ThemeMode.light ? AppColors.light : AppColors.dark;

  void setView(ViewMode newView) {
    _view = newView;
    notifyListeners();
  }

  void setLeftPanelMode(LeftPanelMode mode) {
    _leftPanelMode = mode;
    _sidebarOpen = true;
    if (_view == ViewMode.home) _view = ViewMode.editor;
    notifyListeners();
  }

  void toggleSidebar() {
    _sidebarOpen = !_sidebarOpen;
    notifyListeners();
  }

  void toggleRightPanel() {
    _rightPanelOpen = !_rightPanelOpen;
    notifyListeners();
  }

  void toggleTerminal() {
    _terminalOpen = !_terminalOpen;
    notifyListeners();
  }

  void setTerminalOpen(bool open) {
    if (_terminalOpen != open) {
      _terminalOpen = open;
      notifyListeners();
    }
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }

  // ---- Resizable panels (clamped so the editor can never disappear) ----

  void setLeftPanelWidth(double w) {
    _leftPanelWidth = w.clamp(160, 480);
    notifyListeners();
  }

  void setRightPanelWidth(double w) {
    _rightPanelWidth = w.clamp(240, 640);
    notifyListeners();
  }

  void setTerminalHeight(double h) {
    _terminalHeight = h.clamp(80, 700);
    notifyListeners();
  }
}
