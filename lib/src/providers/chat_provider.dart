import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/ai_service.dart';
import '../services/settings_service.dart';

/// AI chat state: sessions (persisted), streaming responses, agent file-edit
/// proposals with accept/reject, and Ctrl+L editor context.
class ChatProvider extends ChangeNotifier {
  final AiService ai;

  List<ChatSession> sessions = [];
  String currentSessionId = '';

  bool isStreaming = false;
  String streamingError = '';
  final List<String> _log = [];

  /// Context attached from the editor via Ctrl+L, e.g. selection text.
  String? pendingContext;
  String? pendingContextLabel;

  /// Invoked after agent edits are accepted so the workspace tree refreshes
  /// and open tabs reload.
  final void Function(String path)? onFileWritten;

  ChatProvider({required this.ai, this.onFileWritten}) {
    sessions = SettingsService.loadChatSessions();
    if (sessions.isEmpty) {
      _newSession();
    } else {
      currentSessionId = sessions.first.id;
    }
  }

  ChatSession get currentSession {
    final i = sessions.indexWhere((s) => s.id == currentSessionId);
    return i != -1 ? sessions[i] : _newSession();
  }

  List<ChatMessage> get messages => currentSession.messages;

  void addLog(String line) {
    _log.add(line);
    if (_log.length > 200) _log.removeAt(0);
    notifyListeners();
  }

  List<String> get log => List.unmodifiable(_log);

  // --------------------------------------------------------------- sessions

  ChatSession _newSession() {
    final s = ChatSession(
      id: 's${DateTime.now().millisecondsSinceEpoch}',
      title: 'New chat',
      messages: [],
    );
    sessions.insert(0, s);
    currentSessionId = s.id;
    _persist();
    notifyListeners();
    return s;
  }

  void newSession() {
    if (isStreaming) stop();
    _newSession();
  }

  void switchSession(String id) {
    if (isStreaming) stop();
    currentSessionId = id;
    notifyListeners();
  }

  void deleteSession(String id) {
    sessions.removeWhere((s) => s.id == id);
    if (currentSessionId == id) {
      if (sessions.isEmpty) {
        _newSession();
      } else {
        currentSessionId = sessions.first.id;
      }
    }
    _persist();
    notifyListeners();
  }

  void _persist() {
    // Edits are transient — strip them from persisted messages.
    SettingsService.saveChatSessions(sessions);
  }

  // ---------------------------------------------------------------- context

  void setContext(String text, String label) {
    pendingContext = text;
    pendingContextLabel = label;
    notifyListeners();
  }

  void clearContext() {
    pendingContext = null;
    pendingContextLabel = null;
    notifyListeners();
  }

  // ------------------------------------------------------------------- send

  StreamSubscription<String>? _sub;

  Future<void> sendMessage(String text, {String? workspaceRoot}) async {
    if (text.trim().isEmpty || isStreaming) return;
    final session = currentSession;

    final userMsg = ChatMessage(role: ChatRole.user, content: text, attachedContext: pendingContextLabel);
    session.messages.add(userMsg);
    if (session.messages.length == 1) {
      session.title = text.length > 48 ? '${text.substring(0, 48)}…' : text;
    }
    final ctxText = pendingContext;
    final ctxLabel = pendingContextLabel;
    clearContext();

    final reply = ChatMessage(role: ChatRole.assistant, content: '');
    session.messages.add(reply);
    isStreaming = true;
    streamingError = '';
    notifyListeners();
    _persist();

    // Build request payload: system prompt + LAST 40 messages (audit fix #2:
    // previously the FIRST 40 were taken, dropping the newest turns).
    final history = session.messages.length <= 40
        ? session.messages
        : session.messages.sublist(session.messages.length - 40);
    final payload = <ChatMessage>[
      ChatMessage(role: ChatRole.system, content: _systemPrompt(workspaceRoot)),
      ...history.where((m) => m != reply).map((m) => ChatMessage(
            role: m.role,
            content: m == userMsg && ctxText != null && ctxText.isNotEmpty
                ? '$text\n\n[Context: $ctxLabel]\n```\n$ctxText\n```'
                : m.content,
          )),
    ];

    try {
      _sub = ai.chatStream(payload).listen(
        (delta) {
          reply.content += delta;
          notifyListeners();
        },
        onError: (Object e) {
          streamingError = e.toString();
          _finishStream(session, reply);
        },
        onDone: () => _finishStream(session, reply),
        cancelOnError: true,
      );
    } catch (e) {
      streamingError = e.toString();
      _finishStream(session, reply);
    }
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    if (isStreaming) {
      _finishStream(currentSession, _lastAssistant);
    }
  }

  ChatMessage get _lastAssistant {
    final msgs = currentSession.messages;
    for (var i = msgs.length - 1; i >= 0; i--) {
      if (msgs[i].role == ChatRole.assistant) return msgs[i];
    }
    return ChatMessage(role: ChatRole.assistant, content: '');
  }

  void _finishStream(ChatSession session, ChatMessage reply) {
    isStreaming = false;
    _sub = null;
    _parseAgentEdits(reply);
    session.updatedAt = DateTime.now();
    _persist();
    notifyListeners();
  }

  // -------------------------------------------------------- agent file edits

  /// The agent proposes edits with fenced blocks:
  /// ```nexora-write path="relative/path.dart"
  /// <full new file content>
  /// ```
  /// They are parsed into [PendingEdit]s shown with accept/reject UI.
  void _parseAgentEdits(ChatMessage reply) {
    reply.edits.clear();
    final regex = RegExp(
      r'```nexora-write\s+path="([^"]+)"\s*\n([\s\S]*?)\n?```',
      multiLine: true,
    );
    for (final m in regex.allMatches(reply.content)) {
      final relPath = (m.group(1) ?? '').trim();
      if (relPath.isEmpty) continue;
      reply.edits.add(PendingEdit(path: relPath, newContent: m.group(2) ?? ''));
    }
  }

  void acceptEdit(ChatMessage message, PendingEdit edit, {String? workspaceRoot}) {
    if (workspaceRoot == null || workspaceRoot.isEmpty) {
      streamingError = 'Open a folder before accepting file edits.';
      notifyListeners();
      return;
    }
    final abs = _absPath(workspaceRoot, edit.path);
    String? old;
    if (File(abs).existsSync()) {
      try {
        old = File(abs).readAsStringSync();
      } catch (_) {}
    }
    try {
      File(abs).writeAsStringSync(edit.newContent);
    } catch (e) {
      streamingError = 'Write failed: $e';
      notifyListeners();
      return;
    }
    edit.accepted = true;
    edit.oldContent = old;
    onFileWritten?.call(abs);
    _persist();
    notifyListeners();
  }

  void rejectEdit(ChatMessage message, PendingEdit edit) {
    edit.rejected = true;
    notifyListeners();
  }

  String _absPath(String root, String rel) {
    var r = rel;
    while (r.startsWith('/') || r.startsWith('\\')) {
      r = r.substring(1);
    }
    return '$root${Platform.pathSeparator}${r.replaceAll('/', Platform.pathSeparator)}';
  }

  // ------------------------------------------------------------- system rule

  String _systemPrompt(String? workspaceRoot) {
    final buf = StringBuffer(
      'You are NEXORA, an expert AI coding assistant embedded in a desktop IDE. '
      'Answer concisely. When you create or fully rewrite a file, emit it as:\n'
      '```nexora-write path="relative/path/from/workspace/root"\n'
      '<complete new file content>\n'
      '```\n'
      'Use ONE such block per file. For small snippets, use normal fenced code blocks instead.\n',
    );
    // Workspace rules file (like .cursorrules): .nexora/rules.md
    if (workspaceRoot != null && workspaceRoot.isNotEmpty) {
      final rules = File(
          '$workspaceRoot${Platform.pathSeparator}.nexora${Platform.pathSeparator}rules.md');
      if (rules.existsSync()) {
        try {
          final txt = rules.readAsStringSync().trim();
          if (txt.isNotEmpty) {
            buf.write('\nPROJECT RULES (user-defined):\n$txt\n');
          }
        } catch (_) {}
      }
    }
    return buf.toString();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
