// NEXORA — AI chat panel (Web Prototype port): agent conversation with
// session history, streamed markdown-ish replies (fenced code blocks),
// pending-context bar and agent file-edit proposals with inline diff review.
//
// Visual spec (prototype AiChat.tsx): header "Composer" with model chip /
// history / maximize / more actions; message bubbles (You / NEXORA Agent);
// composer card with mode / thinking / web / @-context controls and a
// send/stop action button. Header menus drop DOWN from the header, composer
// menus open UP above the composer — both are anchored popovers
// (CompositedTransformTarget leader → OverlayEntry follower, 150ms
// fade+slide, TapRegion dismissal).
//
// The parent workspace sizes this panel; the widget only fills what it is
// given (audit fix #4/#5: no fixed width, no hardcoded colors — everything
// comes from the UiProvider palette).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/chat_provider.dart';
import '../providers/editor_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/ui_provider.dart';
import '../providers/workspace_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/nexora_ui.dart';
import 'diff_review_dialog.dart';

/// The NEXORA Agent chat panel. Fills its parent box.
class AiChat extends StatefulWidget {
  const AiChat({super.key});

  @override
  State<AiChat> createState() => _AiChatState();
}

/// Visual-only composer modes (prototype Mode chip). They change the hint
/// text and chip styling only — sending always goes through the real
/// [ChatProvider.sendMessage].
enum _ChatMode { normal, agent, architect }

/// Which anchored popover menu is currently open.
enum _MenuId { model, history, mode, thinking }

class _AiChatState extends State<AiChat> {
  late final ChatProvider _chat;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final FocusNode _fieldFocus = FocusNode();
  String? _lastSessionId;

  // Local visual state (prototype composer chips — mock, affects styling /
  // hint text only).
  _ChatMode _mode = _ChatMode.agent;
  String? _thinking; // null = off, else 'Normal' | 'High' | 'Max' | 'Ultra'
  bool _web = false;
  bool _composerFocused = false;

  // Anchored popover menus (model / history in the header, mode / thinking
  // above the composer). The leader links attach to the anchor widgets; the
  // open panel renders in the app Overlay via a CompositedTransformFollower.
  final Object _tapGroup = Object();
  final LayerLink _modelLink = LayerLink();
  final LayerLink _historyLink = LayerLink();
  final LayerLink _modeLink = LayerLink();
  final LayerLink _thinkingLink = LayerLink();
  _MenuId? _openMenu;
  OverlayEntry? _menuEntry;

  @override
  void initState() {
    super.initState();
    // Providers live for the whole app lifetime (root MultiProvider), so
    // holding the reference is safe and allows clean listen/dispose.
    _chat = context.read<ChatProvider>();
    _chat.addListener(_onChatChanged);
    _lastSessionId = _chat.currentSessionId;
    _fieldFocus.addListener(_onFieldFocus);
    // Open the panel at the bottom of the conversation history.
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
  }

  @override
  void dispose() {
    _chat.removeListener(_onChatChanged);
    _fieldFocus.removeListener(_onFieldFocus);
    _fieldFocus.dispose();
    _controller.dispose();
    _scroll.dispose();
    _menuEntry?.remove();
    _menuEntry = null;
    super.dispose();
  }

  // ------------------------------------------------------------ auto-scroll

  /// Runs on every provider notification (new message, stream delta, session
  /// switch). Scroll metrics are read BEFORE the new content is laid out, so
  /// "was near bottom" is measured against the pre-update extent.
  void _onChatChanged() {
    final sessionSwitched = _lastSessionId != _chat.currentSessionId;
    _lastSessionId = _chat.currentSessionId;
    final wasNearBottom = !_scroll.hasClients ||
        (_scroll.position.maxScrollExtent - _scroll.position.pixels) < 80;
    if (!sessionSwitched && !wasNearBottom) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
  }

  void _jumpToBottom() {
    if (!mounted || !_scroll.hasClients) return;
    _scroll.jumpTo(_scroll.position.maxScrollExtent);
  }

  // ---------------------------------------------------------------- actions

  void _send() {
    final text = _controller.text;
    if (text.trim().isEmpty || _chat.isStreaming) return;
    final workspace = context.read<WorkspaceProvider>();
    if (!workspace.hasWorkspace) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Open a folder first (Ctrl+O)'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    _chat.sendMessage(text, workspaceRoot: workspace.rootPath);
    _controller.clear();
    _fieldFocus.requestFocus();
  }

  void _attachActiveFile() {
    final tab = context.read<EditorProvider>().activeTab;
    if (tab == null) return;
    _chat.setContext(tab.content, '${tab.name} (whole file)');
  }

  /// Plain Enter sends the message; Shift+Enter inserts a newline.
  ///
  /// The engine gives the framework the raw key event first and only turns
  /// it into text input if the event is left unhandled, so consuming the
  /// Enter keydown here prevents the newline while returning
  /// [KeyEventResult.ignored] for Shift+Enter lets the field insert one.
  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    final isEnter = event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter;
    final pressed = event is KeyDownEvent || event is KeyRepeatEvent;
    if (isEnter && pressed && !HardwareKeyboard.instance.isShiftPressed) {
      _send();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _onFieldFocus() {
    if (!mounted) return;
    setState(() => _composerFocused = _fieldFocus.hasFocus);
  }

  // ------------------------------------------------------- popover menus

  void _toggleMenu(_MenuId id) {
    if (_openMenu == id) {
      _closeMenus();
      return;
    }
    _closeMenus();
    final overlay = Overlay.of(context);
    setState(() => _openMenu = id);
    final entry =
        OverlayEntry(builder: (context) => _buildMenuOverlay(context, id));
    _menuEntry = entry;
    overlay.insert(entry);
  }

  void _closeMenus() {
    _menuEntry?.remove();
    _menuEntry = null;
    if (mounted && _openMenu != null) {
      setState(() => _openMenu = null);
    }
  }

  Widget _buildMenuOverlay(BuildContext context, _MenuId id) {
    final c = context.watch<UiProvider>().palette;
    final Widget follower;
    switch (id) {
      case _MenuId.model:
        follower = CompositedTransformFollower(
          link: _modelLink,
          targetAnchor: Alignment.bottomRight,
          followerAnchor: Alignment.topRight,
          offset: const Offset(0, 6),
          child: _menuFollower(
              opensDown: true, child: _modelMenuPanel(context, c)),
        );
        break;
      case _MenuId.history:
        follower = CompositedTransformFollower(
          link: _historyLink,
          targetAnchor: Alignment.bottomRight,
          followerAnchor: Alignment.topRight,
          offset: const Offset(0, 6),
          child: _menuFollower(
              opensDown: true, child: _historyMenuPanel(context, c)),
        );
        break;
      case _MenuId.mode:
        follower = CompositedTransformFollower(
          link: _modeLink,
          targetAnchor: Alignment.topLeft,
          followerAnchor: Alignment.bottomLeft,
          offset: const Offset(0, -8),
          child: _menuFollower(opensDown: false, child: _modeMenuPanel(c)),
        );
        break;
      case _MenuId.thinking:
        follower = CompositedTransformFollower(
          link: _thinkingLink,
          targetAnchor: Alignment.topLeft,
          followerAnchor: Alignment.bottomLeft,
          offset: const Offset(0, -8),
          child: _menuFollower(opensDown: false, child: _thinkingMenuPanel(c)),
        );
        break;
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [const SizedBox.expand(), follower],
    );
  }

  /// Wraps a menu panel with tap-outside dismissal and the 150ms
  /// fade+slide entrance (prototype dropdown motion).
  Widget _menuFollower({required bool opensDown, required Widget child}) {
    return TapRegion(
      groupId: _tapGroup,
      onTapOutside: (_) => _closeMenus(),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        builder: (context, t, child) => Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (opensDown ? -5 : 5) * (1 - t)),
            child: child,
          ),
        ),
        child: child,
      ),
    );
  }

  /// Prototype dropdown shell: `bg #252526 border #3c3c3c rounded-lg(8)
  /// shadow-xl p-4`.
  Widget _menuShell(AppColors c,
      {required double width, required Widget child}) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.panelBackground,
        border: Border.all(color: c.borderLight),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }

  /// Model picker — REAL selection: updates SettingsProvider.aiModel. The
  /// watch uses the overlay-entry context so the list stays live while the
  /// menu is open.
  Widget _modelMenuPanel(BuildContext context, AppColors c) {
    final settings = context.watch<SettingsProvider>();
    final models = settings.availableModels;
    return _menuShell(
      c,
      width: 240,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 280),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final model in models)
                _MenuRow(
                  onTap: () {
                    settings.update((s) => s.aiModel = model);
                    _closeMenus();
                  },
                  title: model,
                  titleFamily: 'FiraCode',
                  selected: model == settings.settings.aiModel,
                  trailing: model == settings.settings.aiModel
                      ? Icon(Icons.check, size: 12, color: c.blue400)
                      : null,
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Chat history — session switch / new / delete (ChatProvider, real;
  /// watched through the overlay-entry context so it stays live).
  Widget _historyMenuPanel(BuildContext context, AppColors c) {
    final chat = context.watch<ChatProvider>();
    return _menuShell(
      c,
      width: 264,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 340),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final session in chat.sessions.take(10))
                _MenuRow(
                  onTap: () {
                    _closeMenus();
                    if (session.id != chat.currentSessionId) {
                      chat.switchSession(session.id);
                    }
                  },
                  title: session.title,
                  titleSize: 13,
                  selected: session.id == chat.currentSessionId,
                  trailing: Text(
                    '${session.messages.length} msgs',
                    style: TextStyle(fontSize: 11, color: c.textSecondary),
                  ),
                ),
              Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                color: c.borderLight,
              ),
              _MenuRow(
                onTap: () {
                  _closeMenus();
                  chat.newSession();
                },
                title: 'New chat',
                icon: Icons.add,
              ),
              _MenuRow(
                onTap: () {
                  _closeMenus();
                  chat.deleteSession(chat.currentSessionId);
                },
                title: 'Delete current chat',
                icon: Icons.delete_outline,
                danger: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modeMenuPanel(AppColors c) {
    return _menuShell(
      c,
      width: 160,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MenuRow(
            icon: Icons.chat_bubble_outline,
            title: 'Normal',
            desc: 'Ask questions',
            selected: _mode == _ChatMode.normal,
            onTap: () => _selectMode(_ChatMode.normal),
          ),
          _MenuRow(
            icon: Icons.bolt,
            title: 'Agent',
            desc: 'Execute tasks',
            selected: _mode == _ChatMode.agent,
            onTap: () => _selectMode(_ChatMode.agent),
          ),
          _MenuRow(
            icon: Icons.check,
            title: 'Architect',
            desc: 'Design systems',
            selected: _mode == _ChatMode.architect,
            onTap: () => _selectMode(_ChatMode.architect),
          ),
        ],
      ),
    );
  }

  Widget _thinkingMenuPanel(AppColors c) {
    Widget level(String label, String desc) => _MenuRow(
          icon: Icons.psychology,
          title: label,
          desc: desc,
          tint: c.purple400,
          selected: _thinking == label,
          onTap: () => _selectThinking(label),
        );
    return _menuShell(
      c,
      width: 192,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MenuRow(
            icon: Icons.block,
            title: 'Off',
            desc: 'No extra reasoning',
            tint: c.purple400,
            selected: _thinking == null,
            onTap: () => _selectThinking(null),
          ),
          level('Normal', 'Balanced reasoning'),
          level('High', 'Deeper analysis'),
          level('Max', 'Thorough reasoning'),
          level('Ultra', 'Maximum effort'),
        ],
      ),
    );
  }

  void _selectMode(_ChatMode mode) {
    setState(() => _mode = mode);
    _closeMenus();
  }

  void _selectThinking(String? level) {
    setState(() => _thinking = level);
    _closeMenus();
  }

  // ----------------------------------------------------------------- layout

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final c = context.watch<UiProvider>().palette;
    final editor = context.watch<EditorProvider>();
    final settings = context.watch<SettingsProvider>();

    return Container(
      color: c.activityBar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(c, chat, settings),
          if (chat.streamingError.isNotEmpty) _buildErrorBanner(c, chat),
          Expanded(
            child: Container(
              color: c.editorBackground,
              child: chat.messages.isEmpty
                  ? _buildEmptyState(c)
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(16),
                      itemCount: chat.messages.length,
                      itemBuilder: (context, index) {
                        final isLast = index == chat.messages.length - 1;
                        return Padding(
                          padding: EdgeInsets.only(bottom: isLast ? 0 : 24),
                          child:
                              _buildMessage(chat, chat.messages[index], index, c),
                        );
                      },
                    ),
            ),
          ),
          if (chat.pendingContextLabel != null) _buildContextBar(c, chat),
          _buildComposer(c, chat, editor),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- header

  Widget _buildHeader(
      AppColors c, ChatProvider chat, SettingsProvider settings) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.activityBar,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome, size: 16, color: c.blue400),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Composer',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: c.textPrimary,
              ),
            ),
          ),
          const Spacer(),
          const SizedBox(width: 8),
          _buildModelChip(c, settings),
          const SizedBox(width: 12),
          _buildHistoryButton(),
          const SizedBox(width: 12),
          NexoraIconButton(
            onPressed: _noop,
            icon: Icons.open_in_full,
            size: 14,
            tooltip: 'Maximize',
          ),
          const SizedBox(width: 12),
          NexoraIconButton(
            onPressed: _noop,
            icon: Icons.more_horiz,
            size: 14,
            tooltip: 'More',
          ),
        ],
      ),
    );
  }

  static void _noop() {}

  /// Model chip: shows the live [AppSettings.aiModel]; clicking opens the
  /// REAL model picker (SettingsProvider.availableModels) when the list is
  /// non-empty, otherwise it is a passive display chip.
  Widget _buildModelChip(AppColors c, SettingsProvider settings) {
    final interactive = settings.availableModels.isNotEmpty;
    Widget chip = _ChipButton(
      onTap: interactive ? () => _toggleMenu(_MenuId.model) : null,
      bg: c.inputBackground,
      border: c.borderLight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 90),
            child: Text(
              settings.settings.aiModel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: c.textPrimary),
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.expand_more, size: 12, color: c.textSecondary),
        ],
      ),
    );
    return CompositedTransformTarget(
      link: _modelLink,
      child: TapRegion(groupId: _tapGroup, child: chip),
    );
  }

  Widget _buildHistoryButton() {
    return CompositedTransformTarget(
      link: _historyLink,
      child: TapRegion(
        groupId: _tapGroup,
        child: NexoraIconButton(
          onPressed: () => _toggleMenu(_MenuId.history),
          icon: Icons.history,
          size: 14,
          tooltip: 'Chat history',
        ),
      ),
    );
  }

  // ------------------------------------------------------------ error banner

  Widget _buildErrorBanner(AppColors c, ChatProvider chat) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: c.red500.withValues(alpha: 0.1),
        border: Border(left: BorderSide(color: c.red400, width: 3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 14, color: c.red400),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              chat.streamingError,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: c.red400, height: 1.4),
            ),
          ),
          const SizedBox(width: 6),
          // Rendered for visual closure only — the provider has no clear
          // API; the banner is overwritten on the next send.
          Icon(Icons.close, size: 14, color: c.red400),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- empty state

  Widget _buildEmptyState(AppColors c) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, size: 28, color: c.textSecondary),
          const SizedBox(height: 12),
          Text(
            'Ask anything about your code',
            style: TextStyle(fontSize: 12, color: c.textSecondary),
          ),
          const SizedBox(height: 6),
          Text(
            'Ctrl+L attaches the editor selection',
            style: TextStyle(fontSize: 10, color: c.textSecondary),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- messages

  Widget _buildMessage(
      ChatProvider chat, ChatMessage message, int index, AppColors c) {
    final isLast = index == chat.messages.length - 1;
    if (message.role == ChatRole.user) {
      return _buildUserMessage(message, c);
    }
    return _buildAssistantMessage(chat, message, isLast, c);
  }

  Widget _buildUserMessage(ChatMessage message, AppColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'You',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: c.textPrimary,
              ),
            ),
            if (message.attachedContext != null) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: c.background,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: c.borderLight),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.attach_file, size: 10, color: c.blue400),
                    const SizedBox(width: 4),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 140),
                      child: Text(
                        message.attachedContext!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10, color: c.blue400),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: c.inputBackground,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: c.borderLight),
          ),
          child: SelectableText(
            message.content,
            style: TextStyle(
                fontSize: 14, color: c.textPrimary, height: 1.45),
          ),
        ),
      ],
    );
  }

  Widget _buildAssistantMessage(
      ChatProvider chat, ChatMessage message, bool isLast, AppColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.auto_awesome, size: 14, color: c.blue400),
            const SizedBox(width: 6),
            Text(
              'NEXORA Agent',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: c.blue400,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: c.editorBackground,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: c.borderLight),
          ),
          child: _buildAssistantBody(chat, message, isLast, c),
        ),
        for (final edit in message.edits)
          _buildEditCard(chat, message, edit, c),
      ],
    );
  }

  /// Splits the reply on ``` fences into alternating text / code segments.
  /// An unterminated trailing fence (mid-stream) renders as a growing code
  /// block; the blinking cursor is appended while the reply streams.
  Widget _buildAssistantBody(
      ChatProvider chat, ChatMessage message, bool isLast, AppColors c) {
    final streaming = chat.isStreaming && isLast;
    final children = <Widget>[];
    final parts = message.content.split('```');
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].trim().isEmpty) continue;
      if (i.isOdd) {
        children.add(_buildCodeBlock(parts[i], c));
      } else {
        children.add(SelectableText(
          parts[i],
          style:
              TextStyle(fontSize: 14, color: c.textPrimary, height: 1.45),
        ));
      }
    }
    if (streaming) {
      children.add(Padding(
        padding: const EdgeInsets.only(top: 2),
        child: _Blink(color: c.blue400),
      ));
    }
    if (children.isEmpty) {
      return streaming ? _Blink(color: c.blue400) : const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < children.length; i++)
          i == 0
              ? children[i]
              : Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: children[i],
                ),
      ],
    );
  }

  Widget _buildCodeBlock(String raw, AppColors c) {
    var body = raw;
    var label = '';
    final newline = raw.indexOf('\n');
    if (newline != -1) {
      final first = raw.substring(0, newline).trim();
      if (_isLanguageTag(first)) {
        label = _tagLabel(first);
        body = raw.substring(newline + 1);
      }
    }
    while (body.endsWith('\n')) {
      body = body.substring(0, body.length - 1);
    }
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label.isNotEmpty) ...[
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color: c.textSecondary,
                fontFamily: 'FiraCode',
              ),
            ),
            const SizedBox(height: 4),
          ],
          SelectableText(
            body,
            style: TextStyle(
              fontSize: 12,
              color: c.textPrimary,
              fontFamily: 'FiraCode',
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  /// `dart`, `c++`, `c#`, `sh`, … and agent fences like
  /// `nexora-write path="lib/main.dart"`.
  static bool _isLanguageTag(String tag) {
    if (tag.isEmpty || tag.length > 64) return false;
    if (tag.startsWith('nexora-write')) return true;
    return RegExp(r'^[A-Za-z0-9+#\-_.]{1,32}$').hasMatch(tag);
  }

  /// Compact label for the fence header row.
  static String _tagLabel(String tag) {
    if (tag.startsWith('nexora-write')) {
      final match = RegExp(r'path="([^"]+)"').firstMatch(tag);
      final path = match?.group(1);
      return path == null ? 'nexora-write' : 'nexora-write · $path';
    }
    return tag;
  }

  // ------------------------------------------------------- pending file edits

  Widget _buildEditCard(
      ChatProvider chat, ChatMessage message, PendingEdit edit, AppColors c) {
    final workspace = context.read<WorkspaceProvider>();
    final decided = edit.accepted || edit.rejected;
    final borderColor = edit.accepted
        ? c.green400.withValues(alpha: 0.5)
        : edit.rejected
            ? c.textSecondary.withValues(alpha: 0.4)
            : c.borderLight;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.description, size: 13, color: c.blueLight),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  edit.path,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: c.textPrimary,
                    fontFamily: 'FiraCode',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _editStatusChip(edit, c),
            ],
          ),
          if (!decided) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                NexoraGhostButton(
                  onPressed: () async {
                    await showDiffReviewDialog(
                      context,
                      message: message,
                      edit: edit,
                      workspaceRoot: workspace.rootPath,
                    );
                  },
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: const Text('Review diff'),
                ),
                NexoraGhostButton(
                  onPressed: () => chat.rejectEdit(message, edit),
                  foreground: c.red400,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: const Text('Reject'),
                ),
                NexoraPrimaryButton(
                  onPressed: () => chat.acceptEdit(message, edit,
                      workspaceRoot: workspace.rootPath),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  child: const Text('Apply'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _editStatusChip(PendingEdit edit, AppColors c) {
    if (edit.accepted) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check, size: 12, color: c.green400),
          const SizedBox(width: 4),
          Text('Applied', style: TextStyle(fontSize: 10, color: c.green400)),
        ],
      );
    }
    if (edit.rejected) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.block, size: 12, color: c.textSecondary),
          const SizedBox(width: 4),
          Text('Rejected',
              style: TextStyle(fontSize: 10, color: c.textSecondary)),
        ],
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: c.yellow400.withValues(alpha: 0.5)),
      ),
      child: Text('Review', style: TextStyle(fontSize: 10, color: c.yellow400)),
    );
  }

  // ------------------------------------------------------------ context bar

  Widget _buildContextBar(AppColors c, ChatProvider chat) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.inputBackground,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.borderLight),
      ),
      child: Row(
        children: [
          Icon(Icons.attach_file, size: 12, color: c.blue400),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              chat.pendingContextLabel ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: c.textPrimary),
            ),
          ),
          const SizedBox(width: 6),
          Tooltip(
            message: 'Remove attachment',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: chat.clearContext,
              child: Icon(Icons.close, size: 12, color: c.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- composer

  Widget _buildComposer(AppColors c, ChatProvider chat, EditorProvider editor) {
    final activeTab = editor.activeTab;
    final String hint;
    switch (_mode) {
      case _ChatMode.agent:
        hint = 'Tell NEXORA what to build or execute...';
        break;
      case _ChatMode.normal:
        hint = 'Ask a question...';
        break;
      case _ChatMode.architect:
        hint = 'Describe the system to design...';
        break;
    }
    return Container(
      padding: const EdgeInsets.all(16),
      child: AnimatedContainer(
        duration: NxMotion.fast,
        curve: NxMotion.curve,
        decoration: BoxDecoration(
          color: c.inputBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: _composerFocused ? c.borderFocused : c.borderLight),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Focus(
              onKeyEvent: _handleKey,
              child: TextField(
                controller: _controller,
                focusNode: _fieldFocus,
                minLines: 4,
                maxLines: 5,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                cursorColor: c.blue400,
                style: TextStyle(
                    fontSize: 13, color: c.textPrimary, height: 1.45),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: TextStyle(fontSize: 13, color: c.textSecondary),
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.fromLTRB(12, 16, 12, 8),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                      color: c.borderLight.withValues(alpha: 0.5)),
                ),
              ),
              child: Row(
                children: [
                  // Left chip cluster wraps instead of overflowing when the
                  // panel is narrow.
                  Flexible(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _buildModeChip(c),
                        _ToolbarIconButton(
                          icon: Icons.alternate_email,
                          tooltip: 'Attach active file',
                          onTap: activeTab == null ? null : _attachActiveFile,
                        ),
                        _buildThinkingChip(c),
                        _ToolbarIconButton(
                          icon: Icons.public,
                          tooltip: 'Search the web',
                          active: _web,
                          onTap: () => setState(() => _web = !_web),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (chat.isStreaming)
                    _SquareIconButton(
                      bg: c.red500,
                      hoverBg: c.red400,
                      icon: Icons.stop,
                      tooltip: 'Stop generating',
                      onTap: chat.stop,
                    )
                  else
                    _SquareIconButton(
                      bg: c.blue600,
                      hoverBg: c.blue500,
                      icon: Icons.send,
                      tooltip: 'Send message',
                      onTap: _send,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeChip(AppColors c) {
    final tinted = _mode != _ChatMode.normal;
    final color = tinted ? c.blue400 : c.textSecondary;
    final icon = switch (_mode) {
      _ChatMode.normal => Icons.chat_bubble_outline,
      _ChatMode.agent => Icons.bolt,
      _ChatMode.architect => Icons.check,
    };
    Widget chip = _ChipButton(
      onTap: () => _toggleMenu(_MenuId.mode),
      bg: tinted ? c.blue500.withValues(alpha: 0.1) : null,
      border: tinted ? c.blue500.withValues(alpha: 0.3) : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            _mode.name[0].toUpperCase() + _mode.name.substring(1),
            style: TextStyle(fontSize: 11, color: color),
          ),
          const SizedBox(width: 4),
          Icon(Icons.expand_more, size: 10, color: color),
        ],
      ),
    );
    return CompositedTransformTarget(
      link: _modeLink,
      child: TapRegion(groupId: _tapGroup, child: chip),
    );
  }

  Widget _buildThinkingChip(AppColors c) {
    final active = _thinking != null;
    final color = active ? c.purple400 : c.textSecondary;
    Widget chip = _ChipButton(
      onTap: () => _toggleMenu(_MenuId.thinking),
      bg: active ? c.purple400.withValues(alpha: 0.1) : null,
      border: active ? c.purple400.withValues(alpha: 0.3) : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.psychology, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            active ? _thinking! : 'Thinking',
            style: TextStyle(fontSize: 11, color: color),
          ),
          const SizedBox(width: 4),
          Icon(Icons.expand_more, size: 10, color: color),
        ],
      ),
    );
    return CompositedTransformTarget(
      link: _thinkingLink,
      child: TapRegion(groupId: _tapGroup, child: chip),
    );
  }
}

// ---------------------------------------------------------------------------
// Small prototype-styled primitives private to this file.
// ---------------------------------------------------------------------------

/// Tinted or plain composer chip — prototype Mode/Thinking chips
/// (`bg-blue-500/10 border-blue-500/30 text-blue-400` when tinted, plain
/// `#858585 hover:bg-[#333]` otherwise).
class _ChipButton extends StatefulWidget {
  const _ChipButton({
    required this.onTap,
    required this.child,
    this.bg,
    this.border,
  });

  final VoidCallback? onTap;
  final Widget child;
  final Color? bg;
  final Color? border;

  @override
  State<_ChipButton> createState() => _ChipButtonState();
}

class _ChipButtonState extends State<_ChipButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<UiProvider>().palette;
    final enabled = widget.onTap != null;
    final tinted = widget.bg != null;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: NxMotion.fast,
          curve: NxMotion.curve,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: tinted
                ? widget.bg
                : (_hover && enabled ? c.hoverBackground : null),
            border: widget.border != null
                ? Border.all(color: widget.border!)
                : null,
            borderRadius: BorderRadius.circular(4),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Compact icon button for the composer toolbar (@ attach, web toggle) —
/// `#858585 hover white`, optional active green tint (web).
class _ToolbarIconButton extends StatefulWidget {
  const _ToolbarIconButton({
    required this.icon,
    this.onTap,
    this.tooltip,
    this.active = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final bool active;

  @override
  State<_ToolbarIconButton> createState() => _ToolbarIconButtonState();
}

class _ToolbarIconButtonState extends State<_ToolbarIconButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<UiProvider>().palette;
    final enabled = widget.onTap != null;
    final iconColor = widget.active
        ? c.green400
        : enabled
            ? (_hover ? c.textOnAccent : c.textSecondary)
            : c.textSecondary.withValues(alpha: 0.4);
    final button = MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: NxMotion.fast,
          curve: NxMotion.curve,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: widget.active
                ? c.green400.withValues(alpha: 0.2)
                : (_hover && enabled ? c.hoverBackground : null),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(widget.icon, size: 14, color: iconColor),
        ),
      ),
    );
    if (widget.tooltip == null || widget.tooltip!.isEmpty) return button;
    return Tooltip(
      message: widget.tooltip!,
      waitDuration: const Duration(milliseconds: 300),
      child: button,
    );
  }
}

/// 32×32 send/stop action button — prototype `p-6 bg-blue-600 hover:
/// bg-blue-500 rounded-md(6) icon-14 white` (red variant while streaming).
class _SquareIconButton extends StatefulWidget {
  const _SquareIconButton({
    required this.bg,
    required this.hoverBg,
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final Color bg;
  final Color hoverBg;
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  State<_SquareIconButton> createState() => _SquareIconButtonState();
}

class _SquareIconButtonState extends State<_SquareIconButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<UiProvider>().palette;
    final button = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: NxMotion.fast,
          curve: NxMotion.curve,
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _hover ? widget.hoverBg : widget.bg,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(widget.icon, size: 14, color: c.textOnAccent),
        ),
      ),
    );
    if (widget.tooltip == null || widget.tooltip!.isEmpty) return button;
    return Tooltip(
      message: widget.tooltip!,
      waitDuration: const Duration(milliseconds: 300),
      child: button,
    );
  }
}

/// Menu row inside a popover panel — prototype dropdown option: title 12
/// medium (+ optional desc 10 `#858585`), active = tint fill + tint text,
/// hover `#37373d`; optional trailing widget (msg count / check mark).
class _MenuRow extends StatefulWidget {
  const _MenuRow({
    required this.onTap,
    required this.title,
    this.desc,
    this.icon,
    this.trailing,
    this.selected = false,
    this.danger = false,
    this.tint,
    this.titleSize = 12,
    this.titleFamily,
  });

  final VoidCallback onTap;
  final String title;
  final String? desc;
  final IconData? icon;
  final Widget? trailing;
  final bool selected;
  final bool danger;
  final Color? tint;
  final double titleSize;
  final String? titleFamily;

  @override
  State<_MenuRow> createState() => _MenuRowState();
}

class _MenuRowState extends State<_MenuRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<UiProvider>().palette;
    final tint = widget.tint ?? c.blue400;
    final titleColor = widget.selected
        ? tint
        : widget.danger
            ? c.red400
            : c.textPrimary;
    final iconColor = widget.selected
        ? tint
        : widget.danger
            ? c.red400
            : c.textSecondary;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: NxMotion.fast,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: widget.selected
                ? tint.withValues(alpha: 0.1)
                : (_hover ? c.selectedBackground : Colors.transparent),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 12, color: iconColor),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: widget.titleSize,
                        fontWeight: FontWeight.w500,
                        fontFamily: widget.titleFamily,
                        color: titleColor,
                      ),
                    ),
                    if (widget.desc != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.desc!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            TextStyle(fontSize: 10, color: c.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
              if (widget.trailing != null) ...[
                const SizedBox(width: 8),
                widget.trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Blinking stream cursor (prototype animate-pulse '▌'): a 6×14 pulsing
/// block in the streaming color; the 500ms Timer is always cancelled in
/// [dispose].
class _Blink extends StatefulWidget {
  const _Blink({required this.color});

  final Color color;

  @override
  State<_Blink> createState() => _BlinkState();
}

class _BlinkState extends State<_Blink> {
  Timer? _timer;
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() => _visible = !_visible);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0.15,
      duration: const Duration(milliseconds: 250),
      child: Container(
        width: 6,
        height: 14,
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}
