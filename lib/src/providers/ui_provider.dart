import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum ViewMode { home, editor, settings }
enum LeftPanelMode { explorer, search, git, extensions }

/// Global UI state: which view is active, panel toggles + sizes (drag dividers
/// work), theme, and the agent-runner floating panel (prototype TopBar
/// "Agent" button).
///
/// Default sizes mirror the Web Prototype exactly:
/// left panel 256px (w-64), AI chat 350px (w-[350px]), terminal 256px (h-64).
class UiProvider extends ChangeNotifier {
  ViewMode _view = ViewMode.home;
  LeftPanelMode _leftPanelMode = LeftPanelMode.explorer;
  bool _sidebarOpen = true;
  bool _rightPanelOpen = true;
  bool _terminalOpen = false;

  double _leftPanelWidth = 256;
  double _rightPanelWidth = 350;
  double _terminalHeight = 256;

  ThemeMode _themeMode = ThemeMode.dark;

  /// Floating "Background Task / Agent Running" panel (prototype AgentRunner).
  bool _agentRunning = false;

  ViewMode get view => _view;
  LeftPanelMode get leftPanelMode => _leftPanelMode;
  bool get sidebarOpen => _sidebarOpen;
  bool get rightPanelOpen => _rightPanelOpen;
  bool get terminalOpen => _terminalOpen;
  double get leftPanelWidth => _leftPanelWidth;
  double get rightPanelWidth => _rightPanelWidth;
  double get terminalHeight => _terminalHeight;
  ThemeMode get themeMode => _themeMode;
  bool get agentRunning => _agentRunning;

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

  void setAgentRunning(bool running) {
    if (_agentRunning == running) return;
    _agentRunning = running;
    notifyListeners();
  }

  void toggleAgentRunning() {
    _agentRunning = !_agentRunning;
    notifyListeners();
  }

  // ---- Resizable panels (clamped so the editor can never disappear) ----

  void setLeftPanelWidth(double w) {
    _leftPanelWidth = w.clamp(160, 480);
    notifyListeners();
  }

  void setRightPanelWidth(double w) {
    _rightPanelWidth = w.clamp(260, 640);
    notifyListeners();
  }

  void setTerminalHeight(double h) {
    _terminalHeight = h.clamp(80, 700);
    notifyListeners();
  }
}
