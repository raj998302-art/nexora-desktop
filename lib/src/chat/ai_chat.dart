// NEXORA — AI chat panel: agent conversation with session history,
// streamed markdown-ish replies (fenced code blocks), pending-context bar
// and agent file-edit proposals with inline diff review.
//
// Layout: header / error banner / message list (auto-scroll) / pending
// context bar / composer. The parent workspace sizes this panel; the widget
// only fills what it is given (audit fix #4/#5: no fixed width, no
// hardcoded colors — everything comes from the UiProvider palette).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/chat_provider.dart';
import '../providers/editor_provider.dart';
import '../providers/ui_provider.dart';
import '../providers/workspace_provider.dart';
import '../theme/app_colors.dart';
import 'diff_review_dialog.dart';

/// The NEXORA Agent chat panel. Fills its parent box.
class AiChat extends StatefulWidget {
  const AiChat({super.key});

  @override
  State<AiChat> createState() => _AiChatState();
}

class _AiChatState extends State<AiChat> {
  late final ChatProvider _chat;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final FocusNode _fieldFocus = FocusNode();
  String? _lastSessionId;

  @override
  void initState() {
    super.initState();
    // Providers live for the whole app lifetime (root MultiProvider), so
    // holding the reference is safe and allows clean listen/dispose.
    _chat = context.read<ChatProvider>();
    _chat.addListener(_onChatChanged);
    _lastSessionId = _chat.currentSessionId;
    // Open the panel at the bottom of the conversation history.
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
  }

  @override
  void dispose() {
    _chat.removeListener(_onChatChanged);
    _fieldFocus.dispose();
    _controller.dispose();
    _scroll.dispose();
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

  // ----------------------------------------------------------------- layout

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final c = context.watch<UiProvider>().palette;
    final editor = context.watch<EditorProvider>();

    return Container(
      decoration: BoxDecoration(
        color: c.editorBackground,
        border: Border(left: BorderSide(color: c.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(c, chat),
          if (chat.streamingError.isNotEmpty) _buildErrorBanner(c, chat),
          Expanded(
            child: chat.messages.isEmpty
                ? _buildEmptyState(c)
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(8),
                    itemCount: chat.messages.length,
                    itemBuilder: (context, index) =>
                        _buildMessage(chat, chat.messages[index], index, c),
                  ),
          ),
          if (chat.pendingContextLabel != null) _buildContextBar(c, chat),
          _buildInput(c, chat, editor),
        ],
      ),
    );
  }

  Widget _buildHeader(AppColors c, ChatProvider chat) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: c.activityBar,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome, size: 14, color: c.blueLight),
          const SizedBox(width: 8),
          Text(
            'NEXORA Agent',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: c.textPrimary,
            ),
          ),
          const Spacer(),
          _buildHistoryMenu(c, chat),
        ],
      ),
    );
  }

  Widget _buildHistoryMenu(AppColors c, ChatProvider chat) {
    return PopupMenuButton<String>(
      tooltip: 'Chat history',
      color: c.panelBackground,
      elevation: 8,
      constraints: const BoxConstraints(minWidth: 220),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: c.border),
      ),
      padding: const EdgeInsets.all(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Icon(Icons.history, size: 14, color: c.textSecondary),
      ),
      onSelected: (value) {
        if (value == '__new') {
          chat.newSession();
        } else if (value == '__del') {
          chat.deleteSession(chat.currentSessionId);
        } else if (value != chat.currentSessionId) {
          chat.switchSession(value);
        }
      },
      itemBuilder: (context) => [
        for (final session in chat.sessions.take(10))
          PopupMenuItem(
            value: session.id,
            height: 42,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    session.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: c.textPrimary),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${session.messages.length} msgs',
                  style: TextStyle(fontSize: 10, color: c.textSecondary),
                ),
              ],
            ),
          ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: '__new',
          height: 40,
          child: Row(
            children: [
              Icon(Icons.add, size: 14, color: c.textPrimary),
              const SizedBox(width: 8),
              Text('New chat',
                  style: TextStyle(fontSize: 12, color: c.textPrimary)),
            ],
          ),
        ),
        PopupMenuItem(
          value: '__del',
          height: 40,
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 14, color: c.error),
              const SizedBox(width: 8),
              Text('Delete current chat',
                  style: TextStyle(fontSize: 12, color: c.textPrimary)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBanner(AppColors c, ChatProvider chat) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: c.error.withValues(alpha: 0.1),
        border: Border(left: BorderSide(color: c.error, width: 3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 14, color: c.error),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              chat.streamingError,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: c.error, height: 1.4),
            ),
          ),
          const SizedBox(width: 6),
          // Rendered for visual closure only — the provider has no clear
          // API; the banner is overwritten on the next send.
          Icon(Icons.close, size: 14, color: c.error),
        ],
      ),
    );
  }

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
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'You',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: c.textSecondary,
                ),
              ),
              if (message.attachedContext != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: c.panelBackground,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.attach_file, size: 10, color: c.blueLight),
                      const SizedBox(width: 4),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 140),
                        child: Text(
                          message.attachedContext!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 10, color: c.blueLight),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: c.panelBackground,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: c.borderLight),
            ),
            child: SelectableText(
              message.content,
              style: TextStyle(
                  fontSize: 13, color: c.textPrimary, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssistantMessage(
      ChatProvider chat, ChatMessage message, bool isLast, AppColors c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 12, color: c.blueLight),
              const SizedBox(width: 6),
              Text(
                'NEXORA',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: c.blueLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: c.panelBackground,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: c.borderLight),
            ),
            child:
                _buildAssistantBody(chat, message, isLast, c),
          ),
          for (final edit in message.edits)
            _buildEditCard(chat, message, edit, c),
        ],
      ),
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
              TextStyle(fontSize: 13, color: c.textPrimary, height: 1.45),
        ));
      }
    }
    if (streaming) {
      children.add(Padding(
        padding: const EdgeInsets.only(top: 2),
        child: _Blink(color: c.blueLight),
      ));
    }
    if (children.isEmpty) {
      return streaming
          ? _Blink(color: c.blueLight)
          : const SizedBox.shrink();
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
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 4),
          ],
          SelectableText(
            body,
            style: TextStyle(
              fontSize: 12,
              color: c.textPrimary,
              fontFamily: 'monospace',
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
        ? c.success.withValues(alpha: 0.5)
        : edit.rejected
            ? c.textSecondary.withValues(alpha: 0.5)
            : c.borderLight;
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(10),
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
              Icon(Icons.edit_note, size: 14, color: c.blueLight),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  edit.path,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: c.textPrimary,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _editStatusChip(edit, c),
            ],
          ),
          if (!decided) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                OutlinedButton(
                  onPressed: () async {
                    await showDiffReviewDialog(
                      context,
                      message: message,
                      edit: edit,
                      workspaceRoot: workspace.rootPath,
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: c.textPrimary,
                    side: BorderSide(color: c.borderLight),
                    minimumSize: const Size(56, 28),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    textStyle: const TextStyle(fontSize: 11),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Review diff'),
                ),
                OutlinedButton(
                  onPressed: () => chat.rejectEdit(message, edit),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: c.error,
                    side: BorderSide(color: c.error.withValues(alpha: 0.6)),
                    minimumSize: const Size(56, 28),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    textStyle: const TextStyle(fontSize: 11),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Reject'),
                ),
                FilledButton(
                  onPressed: () => chat.acceptEdit(message, edit,
                      workspaceRoot: workspace.rootPath),
                  style: FilledButton.styleFrom(
                    backgroundColor: c.accent,
                    foregroundColor: c.textOnAccent,
                    minimumSize: const Size(56, 28),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    textStyle: const TextStyle(fontSize: 11),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
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
          Icon(Icons.check, size: 12, color: c.success),
          const SizedBox(width: 4),
          Text('Applied', style: TextStyle(fontSize: 10, color: c.success)),
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
        border: Border.all(color: c.warning.withValues(alpha: 0.6)),
      ),
      child: Text('Review', style: TextStyle(fontSize: 10, color: c.warning)),
    );
  }

  // ------------------------------------------------------------ context bar

  Widget _buildContextBar(AppColors c, ChatProvider chat) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.panelBackground,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.borderLight),
      ),
      child: Row(
        children: [
          Icon(Icons.attach_file, size: 12, color: c.blueLight),
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

  // ---------------------------------------------------------------- composer

  Widget _buildInput(AppColors c, ChatProvider chat, EditorProvider editor) {
    final activeTab = editor.activeTab;
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: c.panelBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.borderLight),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Focus(
            onKeyEvent: _handleKey,
            child: TextField(
              controller: _controller,
              focusNode: _fieldFocus,
              minLines: 1,
              maxLines: 5,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              cursorColor: c.accent,
              style: TextStyle(
                  fontSize: 13, color: c.textPrimary, height: 1.45),
              decoration: InputDecoration(
                hintText: 'Ask NEXORA… (Enter to send)',
                hintStyle:
                    TextStyle(fontSize: 13, color: c.textSecondary),
                isDense: true,
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              IconButton(
                tooltip: 'Attach active file',
                icon: Icon(
                  Icons.attach_file,
                  size: 14,
                  color: c.textSecondary.withValues(
                      alpha: activeTab == null ? 0.4 : 1),
                ),
                onPressed: activeTab == null ? null : _attachActiveFile,
                visualDensity: VisualDensity.compact,
                constraints:
                    const BoxConstraints(minWidth: 28, minHeight: 28),
                padding: EdgeInsets.zero,
                style: IconButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const Spacer(),
              if (chat.isStreaming)
                IconButton(
                  tooltip: 'Stop generating',
                  icon: Icon(Icons.stop, size: 16, color: c.error),
                  onPressed: chat.stop,
                  visualDensity: VisualDensity.compact,
                  constraints:
                      const BoxConstraints(minWidth: 28, minHeight: 28),
                  padding: EdgeInsets.zero,
                  style: IconButton.styleFrom(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                )
              else
                IconButton(
                  tooltip: 'Send message',
                  onPressed: _send,
                  visualDensity: VisualDensity.compact,
                  constraints:
                      const BoxConstraints(minWidth: 28, minHeight: 28),
                  padding: EdgeInsets.zero,
                  style: IconButton.styleFrom(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: c.accent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(Icons.send, size: 14, color: c.textOnAccent),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Blinking stream cursor: a 500ms Timer toggles an AnimatedOpacity — cheap,
/// and the timer is always cancelled in [dispose].
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
        width: 7,
        height: 14,
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}
