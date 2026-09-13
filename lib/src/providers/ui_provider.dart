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
