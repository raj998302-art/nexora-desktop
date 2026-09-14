// NEXORA — activity bar: the 48px icon rail on the far left (home, explorer,
// search, source control, spacer, AI chat, terminal, settings) with a 2px
// accent indicator on the active item and a change badge on the git icon.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/git_provider.dart';
import '../providers/ui_provider.dart';
import 'command_palette.dart';

class ActivityBar extends StatelessWidget {
  const ActivityBar({super.key});

  @override
  Widget build(BuildContext context) {
    final ui = context.watch<UiProvider>();
    final c = ui.palette;
    final git = context.watch<GitProvider>();

    final inEditor = ui.view == ViewMode.editor;
    final panelOpen = inEditor && ui.sidebarOpen;
    final explorerActive =
        panelOpen && ui.leftPanelMode == LeftPanelMode.explorer;
    final searchActive = panelOpen && ui.leftPanelMode == LeftPanelMode.search;
    final gitActive = panelOpen && ui.leftPanelMode == LeftPanelMode.git;

    return Container(
      width: 48,
      decoration: BoxDecoration(
        color: c.activityBar,
        border: Border(right: BorderSide(color: c.border)),
      ),
      child: Column(
        children: [
          _ActivityIcon(
            icon: Icons.cottage,
            tooltip: 'Home',
            active: ui.view == ViewMode.home,
            onTap: () => context.read<UiProvider>().setView(ViewMode.home),
          ),
          _ActivityIcon(
            icon: Icons.folder_open,
            tooltip: 'Explorer',
            active: explorerActive,
            onTap: () {
              if (explorerActive) {
                context.read<UiProvider>().toggleSidebar();
              } else {
                NxActions.showLeftPanel(context, LeftPanelMode.explorer);
              }
            },
          ),
          _ActivityIcon(
            icon: Icons.search,
            tooltip: 'Search',
            active: searchActive,
            onTap: () {
              if (searchActive) {
                context.read<UiProvider>().toggleSidebar();
              } else {
                NxActions.showLeftPanel(context, LeftPanelMode.search);
              }
            },
          ),
          _ActivityIcon(
            icon: Icons.account_tree,
            tooltip: 'Source Control',
            active: gitActive,
            badge: git.isRepo && git.status.files.isNotEmpty,
            onTap: () {
              if (gitActive) {
                context.read<UiProvider>().toggleSidebar();
              } else {
                NxActions.showLeftPanel(context, LeftPanelMode.git);
              }
            },
          ),
          const Spacer(),
          _ActivityIcon(
            icon: Icons.forum,
            tooltip: 'AI Chat',
            active: inEditor && ui.rightPanelOpen,
            onTap: () => NxActions.toggleChatPanel(context),
          ),
          _ActivityIcon(
            icon: Icons.terminal,
            tooltip: 'Terminal',
            active: inEditor && ui.terminalOpen,
            onTap: () => NxActions.toggleTerminalPanel(context),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Container(width: 26, height: 1, color: c.borderLight),
          ),
          _ActivityIcon(
            icon: Icons.settings,
            tooltip: 'Settings',
            active: ui.view == ViewMode.settings,
            onTap: () =>
                context.read<UiProvider>().setView(ViewMode.settings),
          ),
        ],
      ),
    );
  }
}

class _ActivityIcon extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final bool active;
  final VoidCallback onTap;
  final bool badge;

  const _ActivityIcon({
    required this.icon,
    required this.tooltip,
    required this.active,
    required this.onTap,
    this.badge = false,
  });

  @override
  State<_ActivityIcon> createState() => _ActivityIconState();
}

class _ActivityIconState extends State<_ActivityIcon> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = context.read<UiProvider>().palette;
    final color = widget.active || _hover ? c.textPrimary : c.textSecondary;
    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: Stack(
        children: [
          // 2px accent indicator on the left edge when active.
          if (widget.active)
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: 2,
                  child: Container(color: c.accent),
                ),
              ),
            ),
          MouseRegion(
            onEnter: (event) => setState(() => _hover = true),
            onExit: (event) => setState(() => _hover = false),
            child: InkWell(
              onTap: widget.onTap,
              hoverColor: c.panelBackground.withValues(alpha: 0.5),
              child: SizedBox(
                width: 48,
                height: 48,
                child: Icon(widget.icon, size: 20, color: color),
              ),
            ),
          ),
          if (widget.badge)
            Positioned(
              top: 9,
              right: 9,
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: c.accent,
                  shape: BoxShape.circle,
                  border: Border.all(color: c.activityBar, width: 1),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
