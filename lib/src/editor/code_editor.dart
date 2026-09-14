import 'dart:io' show Platform;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/models.dart' show EditorTab;
import '../providers/chat_provider.dart';
import '../providers/completion_provider.dart';
import '../providers/editor_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/ui_provider.dart';
import '../providers/workspace_provider.dart';
import '../services/highlighter.dart';
import '../theme/app_colors.dart';

/// The NEXORA code editor: tab strip, breadcrumbs, and a REAL editable code
/// surface with live syntax highlighting (via a [TextEditingController] that
/// overrides [TextEditingController.buildTextSpan] to call
/// [SyntaxHighlighter.highlight]), synced line-number gutter, minimap, ghost
/// text (AI tab-completion), auto-indent, Tab-insert, line comments, Ctrl+L
/// selection→chat context and reveal-to-line for search results.
class CodeEditor extends StatefulWidget {
  const CodeEditor({Key? key}) : super(key: key);

  @override
  State<CodeEditor> createState() => _CodeEditorState();
}

/// Per-tab editing state: one controller / scroll controller / focus node per
/// open tab path, so cursor + scroll survive tab switches.
class _TabView {
  final String path;
  final _HighlightingController controller;
  final ScrollController scroll;
  final FocusNode focus;
  String lastText;
  TextSelection lastSelection = const TextSelection.collapsed(offset: 0);
  int restoreAttempts = 0;

  _TabView({
    required this.path,
    required this.controller,
    required this.scroll,
    required this.focus,
    required this.lastText,
  });

  void dispose() {
    controller.dispose();
    scroll.dispose();
    focus.dispose();
  }
}

/// [TextEditingController] that renders its text through the syntax
/// highlighter. `EditableTextState.buildTextSpan()` delegates to
/// `controller.buildTextSpan(...)` in this SDK, so overriding here gives every
/// edit real-time highlighting. The computed span is cached per
/// (language, palette, text) so cursor-move rebuilds are cheap.
class _HighlightingController extends TextEditingController {
  String language;
  AppColors palette;

  _HighlightingController({
    required String text,
    required this.language,
    required this.palette,
  }) : super(text: text);

  TextSpan? _cached;
  String _cacheKey = '';

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final key = '$language|${identityHashCode(palette)}|${text.length}|${text.hashCode}';
    if (_cached != null && _cacheKey == key) return _cached!;
    _cached = SyntaxHighlighter.highlight(text, language, palette,
        fontSize: _CodeEditorState.codeFontSize);
    _cacheKey = key;
    return _cached!;
  }
}

class _CodeEditorState extends State<CodeEditor> {
  static const double codeFontSize = 13;
  static const double lineHeight = codeFontSize * 1.5; // 19.5 — matches strut.
  static const double gutterWidth = 48;
  static const double minimapWidth = 60;
  static const double codeLeftPadding = 16;
  static double? _cachedCharWidth;

  final Map<String, _TabView> _views = {};
  String? _activePath;
  bool _pruneScheduled = false;
  bool _syncingExternal = false;

  // ------------------------------------------------------------ view mgmt

  /// Dispose controllers for tabs that no longer exist. Deferred to a
  /// post-frame callback so the EditableText that used the controller has
  /// unmounted first (its dispose removes listeners; disposing the notifier
  /// before that would trip ChangeNotifier's debug assert).
  void _schedulePrune() {
    if (_pruneScheduled) return;
    _pruneScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pruneScheduled = false;
      if (!mounted) return;
      final live =
          context.read<EditorProvider>().tabs.map((t) => t.path).toSet();
      _views.removeWhere((path, view) {
        if (live.contains(path)) return false;
        view.dispose();
        return true;
      });
    });
  }

  _TabView _viewFor(EditorTab tab, AppColors c) {
    final existing = _views[tab.path];
    if (existing != null) {
      // Keep highlight config live (theme switches / language changes).
      existing.controller.language = tab.language;
      existing.controller.palette = c;
      return existing;
    }
    final view = _TabView(
      path: tab.path,
      controller: _HighlightingController(
        text: tab.content,
        language: tab.language,
        palette: c,
      ),
      scroll: ScrollController(),
      focus: FocusNode(),
      lastText: tab.content,
    );
    view.controller.addListener(() => _onControllerChange(view));
    view.scroll.addListener(() => _onScrollChange(view));
    _views[tab.path] = view;
    return view;
  }

  @override
  void dispose() {
    for (final v in _views.values) {
      v.dispose();
    }
    _views.clear();
    super.dispose();
  }

  // ------------------------------------------------------------ listeners

  void _onControllerChange(_TabView view) {
    if (!mounted || _syncingExternal) return;
    final editor = context.read<EditorProvider>();
    final tab = editor.activeTab;
    if (tab == null || tab.path != view.path) return; // inactive view
    final value = view.controller.value;
    final text = value.text;

    // Cursor tracking (0-based line/col; the status bar adds +1).
    if (value.selection.isValid) {
      final base = value.selection.baseOffset.clamp(0, text.length);
      var line = 0;
      var lastNl = -1;
      for (var i = 0; i < base; i++) {
        if (text.codeUnitAt(i) == 0x0A) {
          line++;
          lastNl = i;
        }
      }
      final col = base - lastNl - 1;
      editor.updateCursor(line, col);
    }

    if (text != view.lastText) {
      view.lastText = text;
      editor.updateContent(text);
      // Invalidate ghost text FIRST, then schedule a fresh (debounced)
      // completion request after the frame settles.
      context.read<CompletionProvider>().invalidate();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _requestCompletion(view);
      });
    } else if (value.selection != view.lastSelection) {
      // Caret moved without editing — refresh the completion context.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _requestCompletion(view);
      });
    }
    view.lastSelection = value.selection;
  }

  void _onScrollChange(_TabView view) {
    if (!mounted || !view.scroll.hasClients) return;
    final editor = context.read<EditorProvider>();
    final tab = editor.activeTab;
    if (tab == null || tab.path != view.path) return;
    editor.updateScrollY(view.scroll.offset.round());
  }

  void _requestCompletion(_TabView view) {
    final editor = context.read<EditorProvider>();
    final tab = editor.activeTab;
    if (tab == null || tab.path != view.path) return;
    final sel = view.controller.selection;
    if (!sel.isValid) return;
    final text = view.controller.text;
    final off = sel.baseOffset.clamp(0, text.length);
    final prefixStart = off > 2000 ? off - 2000 : 0;
    final suffixEnd = off + 500 < text.length ? off + 500 : text.length;
    context.read<CompletionProvider>().request(
          view.path,
          off,
          text.substring(prefixStart, off),
          text.substring(off, suffixEnd),
        );
  }

  // ------------------------------------------------------------ keyboard

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final editor = context.read<EditorProvider>();
    final tab = editor.activeTab;
    if (tab == null) return KeyEventResult.ignored;
    final view = _views[tab.path];
    if (view == null) return KeyEventResult.ignored;
    final ctrl = view.controller;
    final hw = HardwareKeyboard.instance;
    final modifier = hw.isControlPressed || hw.isMetaPressed;
    final key = event.logicalKey;

    // Escape — dismiss ghost text.
    if (key == LogicalKeyboardKey.escape) {
      final completion = context.read<CompletionProvider>();
      if (completion.hasSuggestion) {
        completion.dismiss();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    // Tab — accept ghost suggestion at the caret, else insert indent spaces.
    if (key == LogicalKeyboardKey.tab && !modifier) {
      final completion = context.read<CompletionProvider>();
      if (completion.hasSuggestion &&
          completion.forPath == tab.path &&
          completion.forOffset == ctrl.selection.baseOffset) {
        _insertAtCaret(ctrl, completion.accept());
      } else {
        _insertAtCaret(
            ctrl, ' ' * context.read<SettingsProvider>().tabSizeEffective);
      }
      return KeyEventResult.handled;
    }

    // Enter — newline with auto-indent.
    if ((key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) &&
        !modifier &&
        !hw.isAltPressed) {
      _insertNewlineWithIndent(
          ctrl, context.read<SettingsProvider>().tabSizeEffective);
      return KeyEventResult.handled;
    }

    // Ctrl+L — attach selection to the AI chat as context.
    if (modifier && key == LogicalKeyboardKey.keyL) {
      _attachSelectionToChat(tab, view);
      return KeyEventResult.handled;
    }

    // Ctrl+/ — toggle `//` line comment on the selected lines.
    if (modifier && key == LogicalKeyboardKey.slash) {
      _toggleLineComment(ctrl);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _insertAtCaret(TextEditingController ctrl, String insertion) {
    final value = ctrl.value;
    if (!value.selection.isValid) return;
    final start = value.selection.start;
    final end = value.selection.end;
    final newText = value.text.replaceRange(start, end, insertion);
    ctrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + insertion.length),
      composing: TextRange.empty,
    );
  }

  void _insertNewlineWithIndent(TextEditingController ctrl, int tabSize) {
    final value = ctrl.value;
    if (!value.selection.isValid) return;
    final text = value.text;
    final start = value.selection.start;
    final end = value.selection.end;

    final lineStart = start == 0 ? 0 : text.lastIndexOf('\n', start - 1) + 1;
    final beforeCaret = text.substring(lineStart, start);
    final indentMatch = RegExp(r'^[ \t]*').firstMatch(beforeCaret);
    var indent = indentMatch?.group(0) ?? '';

    final trimmed = beforeCaret.trimRight();
    if (trimmed.endsWith('{') ||
        trimmed.endsWith('(') ||
        trimmed.endsWith('[') ||
        trimmed.endsWith(':')) {
      indent += ' ' * tabSize;
    }
    if (end < text.length &&
        (text[end] == '}' || text[end] == ')' || text[end] == ']')) {
      // Simple heuristic: outdent by up to 2 trailing spaces.
      var cut = indent.length;
      var removed = 0;
      while (cut > 0 && indent.codeUnitAt(cut - 1) == 0x20 && removed < 2) {
        cut--;
        removed++;
      }
      indent = indent.substring(0, cut);
    }

    final insertion = '\n$indent';
    ctrl.value = TextEditingValue(
      text: text.replaceRange(start, end, insertion),
      selection: TextSelection.collapsed(offset: start + insertion.length),
      composing: TextRange.empty,
    );
  }

  void _toggleLineComment(TextEditingController ctrl) {
    final value = ctrl.value;
    final text = value.text;
    if (text.isEmpty || !value.selection.isValid) return;
    final start = value.selection.start.clamp(0, text.length);
    final end = value.selection.end.clamp(start, text.length);

    final firstLineStart =
        start == 0 ? 0 : text.lastIndexOf('\n', start - 1) + 1;
    var lastLineEnd = text.indexOf('\n', end);
    if (lastLineEnd == -1) lastLineEnd = text.length;

    final block = text.substring(firstLineStart, lastLineEnd);
    final lines = block.split('\n');
    final nonEmpty = lines.where((l) => l.trim().isNotEmpty).toList();
    final allCommented = nonEmpty.isNotEmpty &&
        nonEmpty.every((l) => l.trimLeft().startsWith('//'));

    final out = <String>[];
    for (final line in lines) {
      if (line.trim().isEmpty) {
        out.add(line);
        continue;
      }
      if (allCommented) {
        var i = line.indexOf('//');
        if (i == -1) {
          out.add(line);
          continue;
        }
        var stripped = line.substring(0, i) + line.substring(i + 2);
        if (i < stripped.length && stripped[i] == ' ') {
          stripped = stripped.substring(0, i) + stripped.substring(i + 1);
        }
        out.add(stripped);
      } else {
        final lead = RegExp(r'^\s*').firstMatch(line)?.group(0) ?? '';
        out.add('${lead}// ${line.substring(lead.length)}');
      }
    }
    final newBlock = out.join('\n');
    ctrl.value = TextEditingValue(
      text: text.replaceRange(firstLineStart, lastLineEnd, newBlock),
      selection: TextSelection(
        baseOffset: firstLineStart,
        extentOffset: firstLineStart + newBlock.length,
      ),
      composing: TextRange.empty,
    );
  }

  void _attachSelectionToChat(EditorTab tab, _TabView view) {
    final sel = view.controller.selection;
    final selected =
        sel.isValid && !sel.isCollapsed ? sel.textInside(view.controller.text) : '';
    final c = context.read<UiProvider>().palette;
    if (selected.trim().isEmpty) {
      _snack('Select some text first to attach it to the chat', c);
      return;
    }
    context
        .read<ChatProvider>()
        .setContext(selected, '${tab.name} (selection)');
    final ui = context.read<UiProvider>();
    if (!ui.rightPanelOpen) ui.toggleRightPanel();
    _snack('Selection attached to chat', c);
  }

  void _snack(String message, AppColors c) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(milliseconds: 1800),
        backgroundColor: c.panelBackground,
        content: Text(message,
            style: TextStyle(color: c.textPrimary, fontSize: 12)),
      ),
    );
  }

  // ------------------------------------------------------------ restore

  static int _offsetForLineCol(String text, int line, int col) {
    var ln = 0;
    var idx = -1;
    for (var i = 0; i < text.length && ln < line; i++) {
      if (text.codeUnitAt(i) == 0x0A) {
        ln++;
        idx = i;
      }
    }
    if (ln < line) return text.length;
    final start = idx + 1;
    var end = start;
    while (end < text.length && text.codeUnitAt(end) != 0x0A && end - start < col) {
      end++;
    }
    return end;
  }

  void _schedulePostFrame(EditorTab tab, _TabView view, {bool restore = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final editor = context.read<EditorProvider>();
      final active = editor.activeTab;
      if (active == null || active.path != tab.path) return;
      // External content change (e.g. reloadTab after an AI file write):
      // resync the controller OUTSIDE build so listener side effects
      // (updateContent/updateCursor → notifyListeners) never run mid-build.
      if (view.controller.text != active.content) {
        _syncingExternal = true;
        try {
          view.controller.value = TextEditingValue(
            text: active.content,
            selection: TextSelection.collapsed(
                offset: _offsetForLineCol(
                    active.content, active.cursorLine, active.cursorCol)),
          );
          view.lastText = active.content;
        } finally {
          _syncingExternal = false;
        }
      }
      // Reveal (search results) takes precedence over saved scroll/selection.
      final line = editor.consumeReveal(active.path);
      if (line != null) {
        _jumpToLine(view, line);
        return;
      }
      if (restore) _restoreViewState(active, view);
    });
  }

  void _jumpToLine(_TabView view, int oneBasedLine) {
    final targetLine = (oneBasedLine - 3).clamp(0, 1000000);
    if (view.scroll.hasClients) {
      final max = view.scroll.position.maxScrollExtent;
      view.scroll.jumpTo((targetLine * lineHeight).clamp(0.0, max));
    }
    final off = _offsetForLineCol(view.controller.text, oneBasedLine - 1, 0);
    view.controller.selection = TextSelection.collapsed(offset: off);
    view.focus.requestFocus();
  }

  void _restoreViewState(EditorTab tab, _TabView view) {
    if (view.scroll.hasClients) {
      final max = view.scroll.position.maxScrollExtent;
      view.scroll
          .jumpTo(tab.scrollOffsetY.toDouble().clamp(0.0, max));
    } else if (view.restoreAttempts < 5) {
      view.restoreAttempts++;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _restoreViewState(tab, view);
      });
      return;
    }
    final off = _offsetForLineCol(
        view.controller.text, tab.cursorLine, tab.cursorCol);
    if (off <= view.controller.text.length) {
      view.controller.selection = TextSelection.collapsed(offset: off);
    }
  }

  // ------------------------------------------------------------ metrics

  static double get _charWidth {
    if (_cachedCharWidth != null) return _cachedCharWidth!;
    final tp = TextPainter(
      text: const TextSpan(
          text: 'MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM',
          style: TextStyle(fontFamily: 'monospace', fontSize: codeFontSize)),
      textDirection: TextDirection.ltr,
    )..layout();
    _cachedCharWidth = tp.width / 50;
    tp.dispose();
    return _cachedCharWidth!;
  }

  // ------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final editor = context.watch<EditorProvider>();
    final ui = context.watch<UiProvider>();
    final settings = context.watch<SettingsProvider>();
    final completion = context.watch<CompletionProvider>();
    final workspace = context.watch<WorkspaceProvider>();
    final c = ui.palette;

    _schedulePrune();

    final tab = editor.activeTab;

    return Column(
      children: [
        _buildTabBarRow(editor, c),
        if (tab != null) _buildBreadcrumbRow(tab, workspace.rootPath, c),
        Expanded(
          child: tab == null
              ? _buildEmptyState(c)
              : _buildEditorArea(
                  tab, settings, completion, c),
        ),
      ],
    );
  }

  Widget _buildEmptyState(AppColors c) {
    return Container(
      color: c.editorBackground,
      width: double.infinity,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.description_outlined, size: 40, color: c.textSecondary),
            const SizedBox(height: 12),
            Text('No file open',
                style: TextStyle(color: c.textSecondary, fontSize: 13)),
            const SizedBox(height: 4),
            Text('Ctrl+N for a new file',
                style: TextStyle(color: c.textSecondary, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  // ---------------- tab bar ----------------

  Widget _buildTabBarRow(EditorProvider editor, AppColors c) {
    final tabs = editor.tabs;
    return Container(
      height: 35,
      color: c.activityBar,
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < tabs.length; i++)
                    _TabChip(
                      tab: tabs[i],
                      active: i == editor.activeIndex,
                      palette: c,
                      onSelect: () => editor.setActive(i),
                      onClose: () => _closeTabAt(i),
                    ),
                ],
              ),
            ),
          ),
          SizedBox(
            width: 30,
            child: IconButton(
              tooltip: 'New file (untitled)',
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.add, size: 16, color: c.textSecondary),
              onPressed: () => editor.openUntitled(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _closeTabAt(int index) async {
    final editor = context.read<EditorProvider>();
    if (index < 0 || index >= editor.tabs.length) return;
    final tab = editor.tabs[index];
    final c = context.read<UiProvider>().palette;
    if (tab.dirty) {
      // Closing must never silently lose edits (audit fix).
      final discard = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: c.panelBackground,
          title: Text('Discard changes?',
              style: TextStyle(color: c.textPrimary, fontSize: 15)),
          content: Text('Discard changes to ${tab.name}?',
              style: TextStyle(color: c.textSecondary, fontSize: 13)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Cancel', style: TextStyle(color: c.textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child:
                  Text('Discard', style: TextStyle(color: c.error)),
            ),
          ],
        ),
      );
      if (discard == true) editor.discardAndClose(index);
      return;
    }
    editor.closeTab(index);
  }

  // ---------------- breadcrumb ----------------

  Widget _buildBreadcrumbRow(EditorTab tab, String? rootPath, AppColors c) {
    var rel = tab.path;
    if (rootPath != null && rootPath.isNotEmpty) {
      final sep = Platform.pathSeparator;
      final prefix = rootPath.endsWith(sep) ? rootPath : '$rootPath$sep';
      if (rel.startsWith(prefix)) rel = rel.substring(prefix.length);
    }
    final segments = rel.split(Platform.pathSeparator).where((s) => s.isNotEmpty).toList();
    final children = <Widget>[];
    for (var i = 0; i < segments.length; i++) {
      if (i > 0) {
        children.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Icon(Icons.chevron_right, size: 12, color: c.textSecondary),
        ));
      }
      children.add(Text(
        segments[i],
        style: TextStyle(
          color: i == segments.length - 1 ? c.textPrimary : c.textSecondary,
          fontSize: 12,
        ),
      ));
    }
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: c.editorBackground,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: children),
        ),
      ),
    );
  }

  // ---------------- editor area ----------------

  Widget _buildEditorArea(
      EditorTab tab, SettingsProvider settings, CompletionProvider completion, AppColors c) {
    final view = _viewFor(tab, c);

    if (_activePath != tab.path) {
      _activePath = tab.path;
      view.restoreAttempts = 0;
      _schedulePostFrame(tab, view, restore: true);
    } else {
      _schedulePostFrame(tab, view);
    }

    final text = view.controller.text;
    final lines = text.split('\n');
    final ghostEnabled = settings.s.ghostTextEnabled &&
        completion.hasSuggestion &&
        completion.forPath == tab.path;

    return Container(
      color: c.editorBackground,
      child: Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (settings.s.showLineNumbers)
                _LineGutter(
                  scroll: view.scroll,
                  lineCount: lines.length,
                  currentLine: tab.cursorLine + 1,
                  palette: c,
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(
                      left: codeLeftPadding, right: codeLeftPadding),
                  child: Focus(
                    onKeyEvent: _onKey,
                    child: _CodeField(
                      controller: view.controller,
                      focusNode: view.focus,
                      scrollController: view.scroll,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: codeFontSize,
                        height: 1.5,
                        color: c.editorForeground,
                      ),
                      strutStyle: const StrutStyle(
                        fontFamily: 'monospace',
                        fontSize: codeFontSize,
                        height: 1.5,
                        forceStrutHeight: true,
                      ),
                      cursorColor: c.accent,
                      selectionColor: c.selection,
                    ),
                  ),
                ),
              ),
              if (settings.s.showMinimap)
                _Minimap(
                  lines: lines,
                  currentLine: tab.cursorLine + 1,
                  palette: c,
                ),
            ],
          ),
          if (ghostEnabled)
            _GhostOverlay(
              scroll: view.scroll,
              caretLine: tab.cursorLine,
              caretCol: tab.cursorCol,
              caretOffset: view.controller.selection.isValid
                  ? view.controller.selection.baseOffset
                  : -1,
              showGutter: settings.s.showLineNumbers,
              suggestion: completion.suggestion,
              forOffset: completion.forOffset,
              palette: c,
            ),
        ],
      ),
    );
  }
}

/// Monospace, syntax-highlighted editing surface.
class _CodeField extends EditableText {
  _CodeField({
    required TextEditingController controller,
    required super.focusNode,
    required super.scrollController,
    required TextStyle style,
    required StrutStyle strutStyle,
    required Color cursorColor,
    required Color selectionColor,
  }) : super(
          controller: controller,
          style: style,
          strutStyle: strutStyle,
          cursorColor: cursorColor,
          backgroundCursorColor: cursorColor,
          selectionColor: selectionColor,
          maxLines: null,
          minLines: null,
          expands: true,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          autocorrect: false,
          enableSuggestions: false,
          mouseCursor: SystemMouseCursors.text,
        );
}

/// Line-number gutter, kept in sync with the editor's internal scroll by
/// translating its content by the live scroll offset.
class _LineGutter extends StatelessWidget {
  final ScrollController scroll;
  final int lineCount;
  final int currentLine; // 1-based
  final AppColors palette;

  const _LineGutter({
    required this.scroll,
    required this.lineCount,
    required this.currentLine,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _CodeEditorState.gutterWidth,
      child: ClipRect(
        child: Listener(
          // Forward wheel events so scrolling over the gutter scrolls code.
          onPointerSignal: (event) {
            if (event is PointerScrollEvent &&
                scroll.hasClients &&
                scroll.position.maxScrollExtent > 0) {
              final pos = scroll.position;
              final target = (scroll.offset + event.scrollDelta.dy)
                  .clamp(pos.minScrollExtent, pos.maxScrollExtent);
              pos.jumpTo(target);
            }
          },
          child: AnimatedBuilder(
            animation: scroll,
            builder: (context, _) {
              final offset = scroll.hasClients ? scroll.offset : 0.0;
              return Transform.translate(
                offset: Offset(0, -offset),
                // OverflowBox gives the number column unbounded height so a
                // long file never trips RenderFlex overflow; ClipRect trims.
                child: OverflowBox(
                  alignment: Alignment.topLeft,
                  minWidth: _CodeEditorState.gutterWidth,
                  maxWidth: _CodeEditorState.gutterWidth,
                  minHeight: 0,
                  maxHeight: double.infinity,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (var i = 1; i <= lineCount; i++)
                        SizedBox(
                          height: _CodeEditorState.lineHeight,
                          width: _CodeEditorState.gutterWidth,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                              '$i',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                                height: 1.625, // 12 * 1.625 == 19.5
                                color: i == currentLine
                                    ? palette.textPrimary
                                    : palette.textSecondary,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Cheap minimap: one 2px row per source line, width proportional to line
/// length, capped at 300 rows, non-interactive.
class _Minimap extends StatelessWidget {
  final List<String> lines;
  final int currentLine; // 1-based
  final AppColors palette;

  const _Minimap({
    required this.lines,
    required this.currentLine,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final count = lines.length < 300 ? lines.length : 300;
    return Container(
      width: _CodeEditorState.minimapWidth,
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: palette.borderLight)),
      ),
      child: ClipRect(
        child: IgnorePointer(
          child: Opacity(
            opacity: 0.7,
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.only(top: 2, left: 3),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < count; i++)
                      Container(
                        height: 2,
                        margin: const EdgeInsets.only(bottom: 1),
                        width: (lines[i].length * 0.8)
                            .clamp(2.0, _CodeEditorState.minimapWidth - 8)
                            .toDouble(),
                        color: i + 1 == currentLine
                            ? palette.blueLight.withValues(alpha: 0.35)
                            : palette.textPrimary.withValues(alpha: 0.35),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ghost-text overlay: the inline AI completion rendered after the caret, or
/// a "Tab to accept" pill when the inline hint does not fit.
class _GhostOverlay extends StatelessWidget {
  final ScrollController scroll;
  final int caretLine; // 0-based
  final int caretCol;
  final int caretOffset;
  final bool showGutter;
  final String suggestion;
  final int forOffset;
  final AppColors palette;

  const _GhostOverlay({
    required this.scroll,
    required this.caretLine,
    required this.caretCol,
    required this.caretOffset,
    required this.showGutter,
    required this.suggestion,
    required this.forOffset,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final height = constraints.maxHeight;
          final width = constraints.maxWidth;
          final charWidth = _CodeEditorState._charWidth;
          return AnimatedBuilder(
            animation: scroll,
            builder: (context, _) {
              final scrollOffset = scroll.hasClients ? scroll.offset : 0.0;
              final caretY = caretLine * _CodeEditorState.lineHeight - scrollOffset;
              final baseX = (showGutter ? _CodeEditorState.gutterWidth : 0.0) +
                  _CodeEditorState.codeLeftPadding;
              final caretX = baseX + caretCol * charWidth;
              final firstNewline = suggestion.indexOf('\n');
              final firstLine =
                  firstNewline == -1 ? suggestion : suggestion.substring(0, firstNewline);
              final hasMore = firstNewline != -1;
              final inlineSuffix = hasMore ? ' …' : '';
              final estWidth =
                  charWidth * (suggestion.length < 40 ? suggestion.length : 40);
              final maxX = width - _CodeEditorState.minimapWidth - 8;

              final offsetMatches = forOffset == caretOffset;
              if (offsetMatches &&
                  caretY >= 0 &&
                  caretY <= height - 24 &&
                  caretX + estWidth < maxX) {
                return Stack(children: [
                  Positioned(
                    left: caretX,
                    top: caretY,
                    child: Text(
                      '$firstLine$inlineSuffix',
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: _CodeEditorState.codeFontSize,
                        height: 1.5,
                        color: palette.textSecondary.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
                ]);
              }
              if (!offsetMatches) return const SizedBox.shrink();
              final preview = firstLine.length > 60
                  ? '${firstLine.substring(0, 60)}…'
                  : firstLine;
              return Stack(children: [
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: palette.panelBackground,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: palette.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Tab',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: palette.accent)),
                        const SizedBox(width: 6),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 240),
                          child: Text(
                            preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11, color: palette.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ]);
            },
          );
        },
      ),
    );
  }
}

/// A single editor tab chip: dirty dot instead of a close icon when unsaved.
class _TabChip extends StatefulWidget {
  final EditorTab tab;
  final bool active;
  final AppColors palette;
  final VoidCallback onSelect;
  final VoidCallback onClose;

  const _TabChip({
    required this.tab,
    required this.active,
    required this.palette,
    required this.onSelect,
    required this.onClose,
  });

  @override
  State<_TabChip> createState() => _TabChipState();
}

class _TabChipState extends State<_TabChip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.palette;
    final active = widget.active;
    final bg = active
        ? c.editorBackground
        : (_hover ? c.borderLight.withValues(alpha: 0.25) : Colors.transparent);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onSelect,
        child: Container(
          height: 35,
          padding: const EdgeInsets.only(left: 12, right: 4),
          decoration: BoxDecoration(
            color: bg,
            border: Border(
              top: BorderSide(
                width: 2,
                color: active ? c.accent : Colors.transparent,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.tab.name,
                style: TextStyle(
                  fontSize: 12,
                  color: active ? c.textPrimary : c.textSecondary,
                ),
              ),
              const SizedBox(width: 6),
              if (widget.tab.dirty)
                Container(
                  width: 6,
                  height: 6,
                  decoration:
                      BoxDecoration(color: c.error, shape: BoxShape.circle),
                )
              else
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: widget.onClose,
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: Icon(Icons.close, size: 14, color: c.textSecondary),
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
