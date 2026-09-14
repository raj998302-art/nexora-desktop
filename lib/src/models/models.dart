// NEXORA — shared domain models.
library;

/// A node in the workspace file tree.
class FileNode {
  final String name;
  final String path;
  final bool isDir;
  final List<FileNode> children;
  bool expanded;

  FileNode({
    required this.name,
    required this.path,
    required this.isDir,
    List<FileNode>? children,
    this.expanded = false,
  }) : children = children ?? <FileNode>[];

  FileNode cloneWithChildren(List<FileNode> newChildren) => FileNode(
        name: name,
        path: path,
        isDir: isDir,
        children: newChildren,
        expanded: expanded,
      );
}

/// A single open editor tab.
class EditorTab {
  final String path;
  final String name;
  String content;
  String savedContent;
  int cursorLine;
  int cursorCol;
  int scrollOffsetY;
  final String language;

  EditorTab({
    required this.path,
    required this.name,
    required this.content,
    required this.language,
    this.cursorLine = 0,
    this.cursorCol = 0,
    this.scrollOffsetY = 0,
    String? savedContent,
  }) : savedContent = savedContent ?? content;

  bool get dirty => content != savedContent;

  EditorTab copyWith({
    String? content,
    String? savedContent,
    int? cursorLine,
    int? cursorCol,
    int? scrollOffsetY,
  }) =>
      EditorTab(
        path: path,
        name: name,
        content: content ?? this.content,
        savedContent: savedContent ?? this.savedContent,
        language: language,
        cursorLine: cursorLine ?? this.cursorLine,
        cursorCol: cursorCol ?? this.cursorCol,
        scrollOffsetY: scrollOffsetY ?? this.scrollOffsetY,
      );
}

/// Role of a chat message.
enum ChatRole { system, user, assistant }

/// One message in a chat session.
class ChatMessage {
  final ChatRole role;
  String content;
  final DateTime timestamp;
  final String? attachedContext; // e.g. "main.dart (selection)"
  final List<PendingEdit> edits;

  ChatMessage({
    required this.role,
    required this.content,
    DateTime? timestamp,
    this.attachedContext,
    List<PendingEdit>? edits,
  })  : timestamp = timestamp ?? DateTime.now(),
        edits = edits ?? <PendingEdit>[];

  Map<String, dynamic> toJson() => {
        'role': role.name,
        'content': content,
        'ts': timestamp.millisecondsSinceEpoch,
        'ctx': attachedContext,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        role: ChatRole.values.firstWhere(
          (r) => r.name == json['role'],
          orElse: () => ChatRole.user,
        ),
        content: json['content'] as String? ?? '',
        timestamp: DateTime.fromMillisecondsSinceEpoch(
            (json['ts'] as num?)?.toInt() ?? 0),
        attachedContext: json['ctx'] as String?,
      );
}

/// A persisted chat conversation.
class ChatSession {
  final String id;
  String title;
  List<ChatMessage> messages;
  final DateTime createdAt;
  DateTime updatedAt;

  ChatSession({
    required this.id,
    required this.title,
    required this.messages,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
        'messages': messages.map((m) => m.toJson()).toList(),
      };

  factory ChatSession.fromJson(Map<String, dynamic> json) => ChatSession(
        id: json['id'] as String,
        title: json['title'] as String? ?? 'Untitled',
        messages: (json['messages'] as List? ?? [])
            .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.fromMillisecondsSinceEpoch(
            (json['createdAt'] as num?)?.toInt() ?? 0),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
            (json['updatedAt'] as num?)?.toInt() ?? 0),
      );
}

/// A file edit proposed by the AI agent, pending review.
class PendingEdit {
  final String path;
  final String newContent;
  String? oldContent;
  bool accepted;
  bool rejected;

  PendingEdit({
    required this.path,
    required this.newContent,
    this.oldContent,
    this.accepted = false,
    this.rejected = false,
  });
}

/// Git status of a single file.
class GitFileStatus {
  final String path;
  final String indexStatus; // staged letter
  final String workStatus; // unstaged letter
  final bool untracked;

  GitFileStatus({
    required this.path,
    required this.indexStatus,
    required this.workStatus,
    this.untracked = false,
  });

  String get label {
    if (untracked) return 'U';
    if (indexStatus != '.' && indexStatus != ' ') return indexStatus;
    if (workStatus != '.' && workStatus != ' ') return workStatus;
    return '?';
  }

  bool get staged => !untracked && indexStatus != '.' && indexStatus != ' ';
}

/// One line of a unified diff.
class DiffLine {
  final String type; // 'add' | 'del' | 'context' | 'hunk' | 'meta'
  final String text;
  final int? oldLine;
  final int? newLine;

  DiffLine(this.type, this.text, {this.oldLine, this.newLine});
}

/// A file-level parsed diff.
class FileDiff {
  final String path;
  final List<DiffLine> lines;

  FileDiff({required this.path, required this.lines});

  int get additions => lines.where((l) => l.type == 'add').length;
  int get deletions => lines.where((l) => l.type == 'del').length;
}

/// A search hit.
class SearchHit {
  final String path;
  final int line;
  final String lineText;
  final int matchStart;
  final int matchEnd;

  SearchHit({
    required this.path,
    required this.line,
    required this.lineText,
    required this.matchStart,
    required this.matchEnd,
  });
}

/// Application settings (persisted as JSON).
class AppSettings {
  // AI
  String aiBaseUrl;
  String aiModel;
  String aiApiType; // 'auto' | 'ollama' | 'openai'
  double aiTemperature;
  int aiMaxTokens;

  // Editor
  int tabSize;
  bool showLineNumbers;
  bool showMinimap;
  bool wordWrap;

  // Appearance
  String themeMode; // 'dark' | 'light'

  // AI features
  bool ghostTextEnabled;

  AppSettings({
    this.aiBaseUrl = 'http://localhost:11434',
    this.aiModel = 'qwen2.5-coder:7b',
    this.aiApiType = 'auto',
    this.aiTemperature = 0.2,
    this.aiMaxTokens = 4096,
    this.tabSize = 2,
    this.showLineNumbers = true,
    this.showMinimap = true,
    this.wordWrap = false,
    this.themeMode = 'dark',
    this.ghostTextEnabled = true,
  });

  Map<String, dynamic> toJson() => {
        'aiBaseUrl': aiBaseUrl,
        'aiModel': aiModel,
        'aiApiType': aiApiType,
        'aiTemperature': aiTemperature,
        'aiMaxTokens': aiMaxTokens,
        'tabSize': tabSize,
        'showLineNumbers': showLineNumbers,
        'showMinimap': showMinimap,
        'wordWrap': wordWrap,
        'themeMode': themeMode,
        'ghostTextEnabled': ghostTextEnabled,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        aiBaseUrl: json['aiBaseUrl'] as String? ?? 'http://localhost:11434',
        aiModel: json['aiModel'] as String? ?? 'qwen2.5-coder:7b',
        aiApiType: json['aiApiType'] as String? ?? 'auto',
        aiTemperature: (json['aiTemperature'] as num?)?.toDouble() ?? 0.2,
        aiMaxTokens: (json['aiMaxTokens'] as num?)?.toInt() ?? 4096,
        tabSize: (json['tabSize'] as num?)?.toInt() ?? 2,
        showLineNumbers: json['showLineNumbers'] as bool? ?? true,
        showMinimap: json['showMinimap'] as bool? ?? true,
        wordWrap: json['wordWrap'] as bool? ?? false,
        themeMode: json['themeMode'] as String? ?? 'dark',
        ghostTextEnabled: json['ghostTextEnabled'] as bool? ?? true,
      );
}

/// A recently opened folder.
class RecentFolder {
  final String path;
  final DateTime openedAt;

  RecentFolder({required this.path, required this.openedAt});

  Map<String, dynamic> toJson() =>
      {'path': path, 'at': openedAt.millisecondsSinceEpoch};

  factory RecentFolder.fromJson(Map<String, dynamic> json) => RecentFolder(
        path: json['path'] as String,
        openedAt: DateTime.fromMillisecondsSinceEpoch(
            (json['at'] as num?)?.toInt() ?? 0),
      );
}
