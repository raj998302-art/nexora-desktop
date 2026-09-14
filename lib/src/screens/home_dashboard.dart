// NEXORA — home dashboard, restyled to the Web Prototype (DESIGN_REF
// "Home dashboard"): hero column shifted up ~8%, sparkles wordmark, glowing
// composer card with mode / context / thinking / web chips, dropdowns that
// open UPWARD, a shortcut row and the real recent-workspaces grid.
//
// Preserved functionality: real folder opening (showOpenFolderDialog), real
// recents from WorkspaceProvider, send → ChatProvider.sendMessage with
// workspaceRoot, new chat, error SnackBars, controller disposal.
//
// NOTE on the dropdowns: the upward-opening menus are rendered through an
// OverlayPortal (full-screen dismiss barrier + a Positioned panel measured
// from the laid-out card). A plain Stack cannot receive hit-tests outside
// its own bounds, so the composer-anchored menu would not be clickable.
// Visual behavior (bottom: cardTop + 8, left at chip, w-192, 150ms
// fade+slide-up) matches the prototype exactly.

import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/chat_provider.dart';
import '../providers/editor_provider.dart';
import '../providers/git_provider.dart';
import '../providers/ui_provider.dart';
import '../providers/workspace_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/command_palette.dart';
import '../widgets/nexora_ui.dart';

/// Composer mode — local visual state (like the prototype chips).
enum _PromptMode { normal, agent, architect }

/// Thinking effort — local visual state.
enum _ThinkLevel { normal, high, max, ultra }

/// Which upward dropdown is open.
enum _OpenMenu { none, mode, thinking }

/// Prototype "white" text: white on the dark palette, dark ink on light.
Color _brightColor(AppColors c) =>
    c.brightness == Brightness.dark ? c.textOnAccent : c.textPrimary;

String _baseName(String path) {
  final parts =
      path.split(RegExp(r'[/\\]')).where((s) => s.isNotEmpty).toList();
  return parts.isEmpty ? path : parts.last;
}

String _relativeTime(DateTime opened) {
  final d = DateTime.now().difference(opened);
  if (d.inSeconds < 60) return 'Just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  if (d.inDays < 7) return '${d.inDays}d ago';
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${opened.day} ${months[opened.month - 1]}';
}

class _MenuOptionData {
  final IconData? icon;
  final String title;
  final String desc;
  const _MenuOptionData(this.title, this.desc, [this.icon]);
}

const List<_MenuOptionData> _modeOptions = [
  _MenuOptionData('Normal', 'Standard AI chat assistant',
      Icons.chat_bubble_outline),
  _MenuOptionData('Agent', 'Autonomous code execution', Icons.bolt),
  _MenuOptionData('Architect', 'Multi-file planning & review', Icons.check),
];

const List<_MenuOptionData> _thinkOptions = [
  _MenuOptionData('Normal', 'Standard reasoning'),
  _MenuOptionData('High', 'Extended chain of thought'),
  _MenuOptionData('Max', 'Deep problem solving'),
  _MenuOptionData('Ultra', 'Maximum compute limits'),
];

class HomeDashboard extends StatefulWidget {
  const HomeDashboard({super.key});

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  final TextEditingController _controller = TextEditingController();

  /// Own focus node for the composer so Enter sends (Shift+Enter = newline)
  /// without the multiline TextField swallowing the key.
  late final FocusNode _composerFocus = FocusNode(
    onKeyEvent: (node, event) {
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.enter &&
          !HardwareKeyboard.instance.isShiftPressed) {
        _send();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    },
  );

  // ---- Composer local visual state (prototype chips) ----
  _PromptMode _mode = _PromptMode.normal;
  _ThinkLevel _thinking = _ThinkLevel.normal;
  bool _web = false;
  bool _glow = false;
  bool _fieldFocused = false;

  // ---- Upward dropdown state (rendered in the app Overlay) ----
  _OpenMenu _menu = _OpenMenu.none;
  final OverlayPortalController _menuPortal = OverlayPortalController();
  final GlobalKey _cardKey = GlobalKey();
  final GlobalKey _modeChipKey = GlobalKey();
  final GlobalKey _thinkingChipKey = GlobalKey();
  double? _menuLeft;
  double? _menuBottom; // menu bottom edge, from the overlay bottom

  @override
  void initState() {
    super.initState();
    _composerFocus.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    final focused = _composerFocus.hasFocus;
    if (focused != _fieldFocused && mounted) {
      setState(() => _fieldFocused = focused);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _composerFocus
      ..removeListener(_onFocusChanged)
      ..dispose();
    super.dispose();
  }

  // ------------------------------------------------------------- actions

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final workspace = context.read<WorkspaceProvider>();
    final ui = context.read<UiProvider>();

    var root = workspace.rootPath;
    if (root == null || root.isEmpty) {
      // No workspace yet → pick a folder first, then send.
      final path = await showOpenFolderDialog(context);
      if (path == null || path.isEmpty) return;
      if (!mounted) return;
      try {
        await workspace.openFolder(path);
        context.read<GitProvider>().bindWorkspace(path);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Open folder failed: $e')));
        }
        return;
      }
      root = workspace.rootPath;
    }
    if (!mounted) return;
    _controller.clear();
    ui.setView(ViewMode.editor);
    if (!ui.rightPanelOpen) ui.toggleRightPanel();
    context.read<ChatProvider>().sendMessage(text, workspaceRoot: root);
  }

  Future<void> _openPath(String path) async {
    final workspace = context.read<WorkspaceProvider>();
    try {
      await workspace.openFolder(path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Open folder failed: $e')));
      }
      return;
    }
    if (!mounted) return;
    context.read<GitProvider>().bindWorkspace(path);
    context.read<UiProvider>().setView(ViewMode.editor);
  }

  // Shortcut-row actions.
  void _newProject() {
    final ui = context.read<UiProvider>();
    ui.setView(ViewMode.editor);
    context.read<EditorProvider>().openUntitled();
  }

  Future<void> _openWorkspace() => NxActions.openFolder(context);

  void _openTerminal() {
    final ui = context.read<UiProvider>();
    ui.setTerminalOpen(true);
    if (ui.view != ViewMode.editor) ui.setView(ViewMode.editor);
  }

  void _searchFiles() {
    context.read<UiProvider>().setLeftPanelMode(LeftPanelMode.search);
  }

  /// Context chip: attach the ACTIVE file to the next chat message
  /// (kept @-file behavior from the previous dashboard).
  void _attachContext() {
    final tab = context.read<EditorProvider>().activeTab;
    if (tab == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No file open')));
      return;
    }
    context.read<ChatProvider>().setContext(tab.content, tab.name);
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Context attached: ${tab.name}')));
  }

  // ----------------------------------------------------------- dropdowns

  void _toggleModeMenu() {
    _menu == _OpenMenu.mode ? _closeMenu() : _openMenu(_OpenMenu.mode);
  }

  void _toggleThinkingMenu() {
    _menu == _OpenMenu.thinking
        ? _closeMenu()
        : _openMenu(_OpenMenu.thinking);
  }

  /// Measure the card / chip position, then show the menu 8px above the
  /// card top (bottom-anchored in overlay coordinates), aligned with the
  /// chip (clamped so the 192px panel stays on screen).
  void _openMenu(_OpenMenu menu) {
    final screen = MediaQuery.of(context).size;
    final cardObj = _cardKey.currentContext?.findRenderObject();
    if (cardObj is RenderBox && cardObj.attached && cardObj.hasSize) {
      final cardTop = cardObj.localToGlobal(Offset.zero).dy;
      var bottom = screen.height - cardTop + 8;
      if (bottom < 8) bottom = 8;
      _menuBottom = bottom;

      var left = 16.0;
      final chipObj = (menu == _OpenMenu.thinking
              ? _thinkingChipKey
              : _modeChipKey)
          .currentContext
          ?.findRenderObject();
      if (chipObj is RenderBox && chipObj.attached) {
        left = chipObj.localToGlobal(Offset.zero).dx;
      }
      var maxLeft = screen.width - 200;
      if (maxLeft < 0) maxLeft = 0;
      if (left < 0) left = 0;
      if (left > maxLeft) left = maxLeft;
      _menuLeft = left;
    }
    setState(() => _menu = menu);
    _menuPortal.show();
  }

  void _closeMenu() {
    if (_menu == _OpenMenu.none) return;
    setState(() => _menu = _OpenMenu.none);
    _menuPortal.hide();
  }

  void _selectMenuOption(int index) {
    if (_menu == _OpenMenu.mode) {
      _mode = _PromptMode.values[index];
    } else if (_menu == _OpenMenu.thinking) {
      _thinking = _ThinkLevel.values[index];
    }
    _closeMenu();
  }

  /// Overlay child: full-screen dismiss barrier + the upward menu panel.
  Widget _menuOverlayChild(BuildContext ctx) {
    if (_menu == _OpenMenu.none || _menuLeft == null || _menuBottom == null) {
      return Positioned.fill(child: const SizedBox.shrink());
    }
    final c = ctx.watch<UiProvider>().palette;
    return Positioned.fill(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Modal dismiss barrier (outside click closes the menu).
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _closeMenu,
              child: const SizedBox.expand(),
            ),
          ),
          Positioned(
            left: _menuLeft,
            bottom: _menuBottom,
            width: 192,
            child: _menuPanel(c),
          ),
        ],
      ),
    );
  }

  Widget _menuPanel(AppColors c) {
    final isMode = _menu == _OpenMenu.mode;
    final options = isMode ? _modeOptions : _thinkOptions;
    final selected = isMode ? _mode.index : _thinking.index;
    final tint = isMode ? c.blue400 : c.purple400;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: NxMotion.fast,
      curve: NxMotion.curve,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, 5 * (1 - v)),
          child: child,
        ),
      ),
      child: Container(
        width: 192,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: c.panelBackground,
          border: Border.all(color: c.borderLight),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < options.length; i++)
              _MenuOptionRow(
                option: options[i],
                active: i == selected,
                tint: tint,
                indentDesc: !isMode,
                onTap: () => _selectMenuOption(i),
              ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------- layout

  @override
  Widget build(BuildContext context) {
    final c = context.watch<UiProvider>().palette;
    final recents = context.watch<WorkspaceProvider>().recents.take(6).toList();

    return Container(
      color: c.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (ctx, cons) {
                // Prototype mt-[-10vh] ≈ shift the hero up by 8%.
                final topPad = cons.maxHeight * 0.08;
                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(24, topPad, 24, 24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                        minHeight:
                            math.max(0.0, cons.maxHeight - topPad - 24.0)),
                    child: Center(
                      child: ConstrainedBox(
                        constraints:
                            const BoxConstraints(maxWidth: 672),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _logo(c),
                            const SizedBox(height: 40),
                            _composer(c),
                            const SizedBox(height: 32),
                            _shortcuts(c),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          _recentsSection(c, recents),
        ],
      ),
    );
  }

  Widget _logo(AppColors c) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Opacity(
          opacity: 0.9,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.auto_awesome, size: 32, color: c.blue400),
              const SizedBox(width: 12),
              Text(
                'NEXORA',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 30,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                  color: _brightColor(c),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'AI-native coding environment',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontFamily: 'Inter', fontSize: 13, color: c.textSecondary),
        ),
      ],
    );
  }

  // ------------------------------------------------------------- composer

  Widget _composer(AppColors c) {
    return OverlayPortal(
      controller: _menuPortal,
      overlayChildBuilder: _menuOverlayChild,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // GLOW layer — prototype: gradient blur halo at -inset-0.5,
          // opacity .3 → .6 on hover (500ms).
          Positioned(
            left: -2,
            top: -2,
            right: -2,
            bottom: -2,
            child: IgnorePointer(
              child: AnimatedOpacity(
                duration: NxMotion.slow,
                opacity: _glow ? 0.6 : 0.3,
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          c.blue500.withValues(alpha: 0.2),
                          c.purple400.withValues(alpha: 0.2),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // CARD
          MouseRegion(
            onEnter: (_) => setState(() => _glow = true),
            onExit: (_) => setState(() => _glow = false),
            child: AnimatedContainer(
              key: _cardKey,
              duration: NxMotion.fast,
              decoration: BoxDecoration(
                color: c.panelBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: _fieldFocused ? c.borderFocused : c.borderLight),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 96,
                    child: TextField(
                      controller: _controller,
                      focusNode: _composerFocus,
                      autofocus: true,
                      maxLines: 3,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        height: 1.35,
                        color: _brightColor(c),
                      ),
                      cursorColor: c.blue400,
                      decoration: InputDecoration(
                        hintText: _mode == _PromptMode.agent
                            ? 'Tell NEXORA what to build... (⌘K)'
                            : 'Ask a question...',
                        hintStyle: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            color: c.textSecondary),
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _modeChip(c),
                              Container(
                                  width: 1, height: 16, color: c.borderLight),
                              _contextChip(c),
                              _thinkingChip(c),
                              _webChip(c),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        NexoraKbd('⌘ Enter'),
                        const SizedBox(width: 8),
                        _SendButton(onTap: _send),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeChip(AppColors c) {
    final tinted = _mode != _PromptMode.normal;
    final icon = switch (_mode) {
      _PromptMode.normal => Icons.chat_bubble_outline,
      _PromptMode.agent => Icons.bolt,
      _PromptMode.architect => Icons.check,
    };
    final label = switch (_mode) {
      _PromptMode.normal => 'Normal',
      _PromptMode.agent => 'Agent',
      _PromptMode.architect => 'Architect',
    };
    return _ChipButton(
      key: _modeChipKey,
      onTap: _toggleModeMenu,
      icon: icon,
      label: label,
      trailing: Icon(Icons.expand_more,
          size: 12, color: tinted ? c.blue400 : c.textSecondary),
      bg: tinted
          ? c.blue500.withValues(alpha: 0.1)
          : c.hoverBackground2.withValues(alpha: 0.5),
      border: tinted ? c.blue500.withValues(alpha: 0.3) : null,
      fg: tinted ? c.blue400 : c.textPrimary,
    );
  }

  Widget _contextChip(AppColors c) {
    return _ChipButton(
      onTap: _attachContext,
      icon: Icons.alternate_email,
      label: 'Context',
      bg: Colors.transparent,
      hoverBg: c.hoverBackground,
      fg: c.textSecondary,
      fgHover: c.textPrimary,
    );
  }

  Widget _thinkingChip(AppColors c) {
    final active = _thinking != _ThinkLevel.normal;
    return _ChipButton(
      key: _thinkingChipKey,
      onTap: _toggleThinkingMenu,
      icon: Icons.psychology,
      label: 'Thinking',
      bg: active ? c.purple400.withValues(alpha: 0.1) : Colors.transparent,
      hoverBg:
          active ? c.purple400.withValues(alpha: 0.1) : c.hoverBackground,
      border: active ? c.purple400.withValues(alpha: 0.3) : null,
      fg: active ? c.purple400 : c.textSecondary,
      fgHover: active ? c.purple400 : c.textPrimary,
    );
  }

  Widget _webChip(AppColors c) {
    final active = _web;
    return _ChipButton(
      onTap: () => setState(() => _web = !_web),
      icon: Icons.public,
      label: 'Web',
      bg: active ? c.green400.withValues(alpha: 0.1) : Colors.transparent,
      hoverBg:
          active ? c.green400.withValues(alpha: 0.1) : c.hoverBackground,
      border: active ? c.green400.withValues(alpha: 0.3) : null,
      fg: active ? c.green400 : c.textSecondary,
      fgHover: active ? c.green400 : c.textPrimary,
    );
  }

  // ------------------------------------------------------------ shortcuts

  Widget _shortcuts(AppColors c) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 24,
      runSpacing: 8,
      children: [
        _ActionShortcut(
            icon: Icons.note_add,
            label: 'New Project',
            kbd: '⌘ N',
            onTap: _newProject),
        _ActionShortcut(
            icon: Icons.folder_open,
            label: 'Open Workspace',
            kbd: '⌘ O',
            onTap: _openWorkspace),
        _ActionShortcut(
            icon: Icons.terminal,
            label: 'Terminal',
            kbd: '⌘ J',
            onTap: _openTerminal),
        _ActionShortcut(
            icon: Icons.search,
            label: 'Search Files',
            kbd: '⇧ ⌘ F',
            onTap: _searchFiles),
      ],
    );
  }

  // -------------------------------------------------------------- recents

  Widget _recentsSection(AppColors c, List<RecentFolder> recents) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 576),
          child: _HoverReveal(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'RECENT WORKSPACES',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                          color: c.textSecondary,
                        ),
                      ),
                    ),
                    _GhostTextButton(
                      label: 'New chat',
                      onTap: () =>
                          context.read<ChatProvider>().newSession(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (recents.isEmpty)
                  _emptyRecents(c)
                else
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    mainAxisExtent: 64,
                    children: [
                      for (final r in recents)
                        _RecentItem(
                          name: _baseName(r.path),
                          time: _relativeTime(r.openedAt),
                          path: r.path,
                          onTap: () => _openPath(r.path),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyRecents(AppColors c) {
    return Row(
      children: [
        Expanded(
          child: _PlaceholderCell(
            icon: Icons.folder_open,
            onTap: _openWorkspace,
            child: Text(
              'Open your first workspace',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: c.textSecondary),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _PlaceholderCell(
            icon: Icons.folder_open,
            onTap: _openWorkspace,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Press',
                    style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: c.textSecondary)),
                const SizedBox(width: 6),
                const NexoraKbd('⌘ O'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Composer chip — prototype rounded-6 px-10 py-6 pill with hover transitions.
// ---------------------------------------------------------------------------

class _ChipButton extends StatefulWidget {
  final VoidCallback? onTap;
  final IconData? icon;
  final String label;
  final Widget? trailing;
  final Color bg;
  final Color? hoverBg;
  final Color? border;
  final Color fg;
  final Color? fgHover;

  const _ChipButton({
    super.key,
    this.onTap,
    this.icon,
    required this.label,
    this.trailing,
    required this.bg,
    this.hoverBg,
    this.border,
    required this.fg,
    this.fgHover,
  });

  @override
  State<_ChipButton> createState() => _ChipButtonState();
}

class _ChipButtonState extends State<_ChipButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final fg = _hover && widget.fgHover != null ? widget.fgHover! : widget.fg;
    return MouseRegion(
      cursor:
          widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: NxMotion.fast,
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _hover && widget.hoverBg != null ? widget.hoverBg : widget.bg,
            border:
                widget.border != null ? Border.all(color: widget.border!) : null,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 14, color: fg),
                const SizedBox(width: 6),
              ],
              AnimatedDefaultTextStyle(
                duration: NxMotion.fast,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: fg,
                ),
                child: Text(widget.label),
              ),
              if (widget.trailing != null) ...[
                const SizedBox(width: 4),
                widget.trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Send button — 32×32 blue-600 → blue-500 on hover, sparkles icon.
// ---------------------------------------------------------------------------

class _SendButton extends StatefulWidget {
  final VoidCallback onTap;
  const _SendButton({required this.onTap});

  @override
  State<_SendButton> createState() => _SendButtonState();
}

class _SendButtonState extends State<_SendButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<UiProvider>().palette;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: NxMotion.fast,
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _hover ? c.blue500 : c.blue600,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(Icons.auto_awesome, size: 16, color: c.textOnAccent),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dropdown option row — title 14 medium + desc 10, active tint, hover #37373d.
// ---------------------------------------------------------------------------

class _MenuOptionRow extends StatefulWidget {
  final _MenuOptionData option;
  final bool active;
  final Color tint;
  final bool indentDesc;
  final VoidCallback onTap;

  const _MenuOptionRow({
    required this.option,
    required this.active,
    required this.tint,
    required this.indentDesc,
    required this.onTap,
  });

  @override
  State<_MenuOptionRow> createState() => _MenuOptionRowState();
}

class _MenuOptionRowState extends State<_MenuOptionRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<UiProvider>().palette;
    final tint = widget.tint;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: NxMotion.fast,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: widget.active
                ? tint.withValues(alpha: 0.1)
                : (_hover ? c.selectedBackground : Colors.transparent),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              if (widget.option.icon != null) ...[
                Icon(widget.option.icon,
                    size: 14,
                    color: widget.active ? tint : c.textSecondary),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedDefaultTextStyle(
                      duration: NxMotion.fast,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: widget.active ? tint : c.textPrimary,
                      ),
                      child: Text(widget.option.title),
                    ),
                    const SizedBox(height: 2),
                    widget.indentDesc
                        ? Padding(
                            padding: const EdgeInsets.only(left: 24),
                            child: Text(widget.option.desc,
                                style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 10,
                                    color: c.textSecondary)),
                          )
                        : Text(widget.option.desc,
                            style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 10,
                                color: c.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shortcut row item — icon 16 + label 14 (hover → white) + kbd chip.
// ---------------------------------------------------------------------------

class _ActionShortcut extends StatefulWidget {
  final IconData icon;
  final String label;
  final String kbd;
  final VoidCallback onTap;

  const _ActionShortcut({
    required this.icon,
    required this.label,
    required this.kbd,
    required this.onTap,
  });

  @override
  State<_ActionShortcut> createState() => _ActionShortcutState();
}

class _ActionShortcutState extends State<_ActionShortcut> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<UiProvider>().palette;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.icon, size: 16, color: c.textSecondary),
            const SizedBox(width: 8),
            AnimatedDefaultTextStyle(
              duration: NxMotion.fast,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: _hover ? _brightColor(c) : c.textSecondary,
              ),
              child: Text(widget.label),
            ),
            const SizedBox(width: 8),
            NexoraKbd(widget.kbd),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Recent workspace card — p-12 rounded-8, transparent → hover border+fill.
// ---------------------------------------------------------------------------

class _RecentItem extends StatefulWidget {
  final String name;
  final String time;
  final String path;
  final VoidCallback onTap;

  const _RecentItem({
    required this.name,
    required this.time,
    required this.path,
    required this.onTap,
  });

  @override
  State<_RecentItem> createState() => _RecentItemState();
}

class _RecentItemState extends State<_RecentItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<UiProvider>().palette;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: NxMotion.fast,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _hover ? c.panelBackground : Colors.transparent,
            border: Border.all(
                color: _hover ? c.borderLight : Colors.transparent),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _brightColor(c),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.time,
                    style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: c.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                widget.path,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: c.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty-state placeholder cell (same 64px footprint as a recent card).
// ---------------------------------------------------------------------------

class _PlaceholderCell extends StatefulWidget {
  final IconData icon;
  final Widget child;
  final VoidCallback onTap;

  const _PlaceholderCell({
    required this.icon,
    required this.child,
    required this.onTap,
  });

  @override
  State<_PlaceholderCell> createState() => _PlaceholderCellState();
}

class _PlaceholderCellState extends State<_PlaceholderCell> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<UiProvider>().palette;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: NxMotion.fast,
          height: 64,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _hover ? c.panelBackground : Colors.transparent,
            border: Border.all(
                color: _hover ? c.borderLight : c.borderLight),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, size: 16, color: c.textSecondary),
                const SizedBox(width: 8),
                Flexible(child: widget.child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Whole recents section: opacity .7 → 1 on hover (prototype group hover).
// ---------------------------------------------------------------------------

class _HoverReveal extends StatefulWidget {
  final Widget child;
  const _HoverReveal({required this.child});

  @override
  State<_HoverReveal> createState() => _HoverRevealState();
}

class _HoverRevealState extends State<_HoverReveal> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedOpacity(
        duration: NxMotion.fast,
        opacity: _hover ? 1.0 : 0.7,
        child: widget.child,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Small ghost text button ("New chat") — #858585 → white on hover.
// ---------------------------------------------------------------------------

class _GhostTextButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _GhostTextButton({required this.label, required this.onTap});

  @override
  State<_GhostTextButton> createState() => _GhostTextButtonState();
}

class _GhostTextButtonState extends State<_GhostTextButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<UiProvider>().palette;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: AnimatedDefaultTextStyle(
            duration: NxMotion.fast,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              color: _hover ? _brightColor(c) : c.textSecondary,
            ),
            child: Text(widget.label),
          ),
        ),
      ),
    );
  }
}
