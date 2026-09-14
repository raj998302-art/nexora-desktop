// NEXORA — activity bar (Web Prototype ActivityBar.tsx): the 48px icon rail
// on the far left. Top group: Home / divider / Explorer / Search / Source
// Control (with change badge) / Extensions. Bottom group: GitHub / User
// (profile popup) / Settings. Active state: white icon + 2px blue-500 left
// inset bar; inactive #858585 with a 150ms hover-to-white color transition.
//
// The profile popup is a root-Overlay entry (Stack overlay): a full-window
// tap barrier closes it, the 256px panel animates opacity + x -10→0 in
// 150ms, positioned left 56 / 40px above the status bar like the prototype.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/git_provider.dart';
import '../providers/ui_provider.dart';
import '../theme/app_colors.dart';
import 'command_palette.dart';
import 'nexora_ui.dart';

/// Prototype `text-white` on the dark rail: pure white in dark mode, the
/// palette's readable dark text in light mode (audit #5 — never invisible).
Color _brightText(AppColors c) =>
    c.brightness == Brightness.dark ? c.textOnAccent : c.textPrimary;

class ActivityBar extends StatefulWidget {
  const ActivityBar({super.key});

  @override
  State<ActivityBar> createState() => _ActivityBarState();
}

class _ActivityBarState extends State<ActivityBar> {
  OverlayEntry? _profileEntry;
  bool _profileVisible = false;
  bool _profileClosing = false;

  @override
  void dispose() {
    _profileEntry?.remove();
    _profileEntry = null;
    super.dispose();
  }

  void _toggleProfile() {
    if (_profileEntry != null) {
      _closeProfile();
    } else {
      _openProfile();
    }
  }

  void _openProfile() {
    _profileClosing = false;
    _profileVisible = false;
    setState(() {});
    _profileEntry = OverlayEntry(
      builder: (_) => _ProfilePopup(
        visible: _profileVisible,
        onDismiss: _closeProfile,
        onSettings: () {
          _closeProfile();
          context.read<UiProvider>().setView(ViewMode.settings);
        },
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(_profileEntry!);
    // Implicit animations start AT their first target, so build the entry
    // hidden and flip to visible after the first frame to play the 150ms
    // opacity + x -10→0 entrance.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _profileEntry == null || _profileClosing) return;
      setState(() => _profileVisible = true);
      _profileEntry!.markNeedsBuild();
    });
  }

  void _closeProfile() {
    if (_profileEntry == null || _profileClosing) return;
    _profileClosing = true;
    _profileVisible = false;
    setState(() {});
    // Re-run the entry's builder so the exit animation (opacity + x -10)
    // plays before the entry is removed.
    _profileEntry!.markNeedsBuild();
    Future.delayed(NxMotion.fast, () {
      _profileEntry?.remove();
      _profileEntry = null;
      _profileClosing = false;
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final ui = context.watch<UiProvider>();
    final c = ui.palette;
    final git = context.watch<GitProvider>();

    final inEditor = ui.view == ViewMode.editor;
    final panelOpen = inEditor && ui.sidebarOpen;
    final activeMode = panelOpen ? ui.leftPanelMode : null;

    return Container(
      width: 48,
      decoration: BoxDecoration(
        color: c.activityBar,
        border: Border(right: BorderSide(color: c.border)),
      ),
      child: Column(
        children: [
          // ---- Top group (py 12, 16px gaps) --------------------------------
          // Scrollable so a very short window clips instead of overflowing;
          // when it fits, the layout is identical to the prototype.
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 12),
                child: Column(
                  children: [
                    _ActivityCell(
                      icon: Icons.home_outlined,
                      tooltip: 'Home Dashboard',
                      active: ui.view == ViewMode.home,
                      onTap: () =>
                          context.read<UiProvider>().setView(ViewMode.home),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: 32,
                      height: 1,
                      child: ColoredBox(color: c.border),
                    ),
                    const SizedBox(height: 20),
                    _ActivityCell(
                      icon: Icons.folder_open,
                      tooltip: 'Explorer (⇧⌘E)',
                      active: activeMode == LeftPanelMode.explorer,
                      onTap: () => NxActions.showLeftPanel(
                          context, LeftPanelMode.explorer),
                    ),
                    const SizedBox(height: 16),
                    _ActivityCell(
                      icon: Icons.search,
                      tooltip: 'Search (⇧⌘F)',
                      active: activeMode == LeftPanelMode.search,
                      onTap: () =>
                          NxActions.showLeftPanel(context, LeftPanelMode.search),
                    ),
                    const SizedBox(height: 16),
                    _ActivityCell(
                      icon: Icons.account_tree,
                      tooltip: 'Source Control (⌃⇧G)',
                      active: activeMode == LeftPanelMode.git,
                      badge: git.isRepo && git.status.files.isNotEmpty,
                      onTap: () =>
                          NxActions.showLeftPanel(context, LeftPanelMode.git),
                    ),
                    const SizedBox(height: 16),
                    _ActivityCell(
                      icon: Icons.inventory_2_outlined,
                      tooltip: 'Extensions (⇧⌘X)',
                      active: activeMode == LeftPanelMode.extensions,
                      onTap: () => NxActions.showLeftPanel(
                          context, LeftPanelMode.extensions),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // ---- Bottom group (justify-between pushes it down) ---------------
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              children: [
                _ActivityCell(
                  icon: Icons.code,
                  tooltip: 'Connect GitHub',
                  active: false,
                  onTap: () {},
                ),
                const SizedBox(height: 16),
                _ActivityCell(
                  icon: Icons.person_outline,
                  tooltip: 'Accounts',
                  active: _profileVisible,
                  onTap: _toggleProfile,
                ),
                const SizedBox(height: 16),
                _ActivityCell(
                  icon: Icons.settings_outlined,
                  tooltip: 'Settings (⌘,)',
                  active: ui.view == ViewMode.settings,
                  onTap: () =>
                      context.read<UiProvider>().setView(ViewMode.settings),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// One 48×44 icon cell: centered 22px icon, 2px blue-500 left indicator when
// active, optional green change badge, 150ms icon color transition.
// ---------------------------------------------------------------------------

class _ActivityCell extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final bool active;
  final VoidCallback onTap;
  final bool badge;

  const _ActivityCell({
    required this.icon,
    required this.tooltip,
    required this.active,
    required this.onTap,
    this.badge = false,
  });

  @override
  State<_ActivityCell> createState() => _ActivityCellState();
}

class _ActivityCellState extends State<_ActivityCell> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<UiProvider>().palette;
    final color = widget.active || _hover ? _brightText(c) : c.textSecondary;

    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (event) => setState(() => _hover = true),
        onExit: (event) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: SizedBox(
            width: 48,
            height: 44,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // 2px blue-500 left inset bar (absolute left-0 top-0 bottom-0).
                if (widget.active)
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: 2,
                        child: ColoredBox(color: c.blue500),
                      ),
                    ),
                  ),
                Center(
                  child: TweenAnimationBuilder<Color?>(
                    tween: ColorTween(end: color),
                    duration: NxMotion.fast,
                    curve: NxMotion.curve,
                    builder: (context, value, child) =>
                        Icon(widget.icon, size: 22, color: value),
                  ),
                ),
                if (widget.badge)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: c.green400,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Profile popup (root overlay): full-window tap barrier + 256px panel at
// left 56 / 40px above the status bar. AnimatePresence: opacity + x -10→0,
// 150ms (AnimatedSlide is fractional: -10px of the 256px panel width).
// ---------------------------------------------------------------------------

class _ProfilePopup extends StatelessWidget {
  final bool visible;
  final VoidCallback onDismiss;
  final VoidCallback onSettings;

  const _ProfilePopup({
    required this.visible,
    required this.onDismiss,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Outside-tap barrier.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onDismiss,
            child: const SizedBox.expand(),
          ),
        ),
        Positioned(
          left: 56,
          // 40px above the activity bar bottom == 40 + 24 (status bar).
          bottom: 64,
          child: AnimatedSlide(
            duration: NxMotion.fast,
            curve: NxMotion.curve,
            offset: visible ? Offset.zero : const Offset(-10 / 256, 0),
            child: AnimatedOpacity(
              duration: NxMotion.fast,
              opacity: visible ? 1.0 : 0.0,
              child: _ProfilePanel(onSettings: onSettings),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfilePanel extends StatelessWidget {
  final VoidCallback onSettings;
  const _ProfilePanel({required this.onSettings});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<UiProvider>().palette;
    return Container(
      width: 256,
      decoration: BoxDecoration(
        color: c.background,
        border: Border.all(color: c.borderLight),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header.
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration:
                BoxDecoration(border: Border(bottom: BorderSide(color: c.border))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'user@nexora.ai',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pro Plan Active',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: c.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _ProfileRow(icon: Icons.credit_card, label: 'Manage Subscription'),
          _ProfileRow(icon: Icons.power, label: 'Integrations & Keys'),
          _ProfileRow(
              icon: Icons.settings_outlined,
              label: 'Settings',
              onTap: onSettings),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: SizedBox(height: 1, child: ColoredBox(color: c.border)),
          ),
          _ProfileRow(icon: Icons.logout, label: 'Sign Out', red: true),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// One popup row: px-16 py-8, 14px, 14px icon, hover bg #2a2d2e (mock rows
// in the prototype — only Settings performs an action).
// ---------------------------------------------------------------------------

class _ProfileRow extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool red;

  const _ProfileRow({
    required this.icon,
    required this.label,
    this.onTap,
    this.red = false,
  });

  @override
  State<_ProfileRow> createState() => _ProfileRowState();
}

class _ProfileRowState extends State<_ProfileRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<UiProvider>().palette;
    final fg = widget.red ? c.red400 : c.textPrimary;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: NxMotion.fast,
          curve: NxMotion.curve,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: _hover ? c.inputBackground : Colors.transparent,
          child: Row(
            children: [
              Icon(widget.icon, size: 14, color: fg),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: _hover && widget.red
                        ? const Color(0xFFFCA5A5)
                        : fg,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
