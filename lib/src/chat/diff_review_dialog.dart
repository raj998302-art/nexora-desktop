// NEXORA — diff review dialog for AI-proposed file edits (PendingEdit),
// restyled to the Web Prototype (prototype diff rows + Accept/Reject bar).
//
// Renders a line diff (LCS) between the on-disk content and the agent's
// proposed content; Apply / Reject are performed through the ChatProvider
// and the dialog pops itself once decided. Review-only from the caller's
// perspective — no state is owned here beyond the computed diff.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/chat_provider.dart';
import '../providers/ui_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/nexora_ui.dart';

/// Opens the diff review dialog for [edit].
///
/// The dialog computes the diff between `edit.oldContent` (null ⇒ new file)
/// and `edit.newContent` and wires its own Apply / Reject buttons to the
/// [ChatProvider]; the caller merely awaits completion.
Future<void> showDiffReviewDialog(
  BuildContext context, {
  required ChatMessage message,
  required PendingEdit edit,
  required String? workspaceRoot,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => _DiffReviewDialog(
      message: message,
      edit: edit,
      workspaceRoot: workspaceRoot,
    ),
  );
}

class _DiffReviewDialog extends StatefulWidget {
  const _DiffReviewDialog({
    required this.message,
    required this.edit,
    required this.workspaceRoot,
  });

  final ChatMessage message;
  final PendingEdit edit;
  final String? workspaceRoot;

  @override
  State<_DiffReviewDialog> createState() => _DiffReviewDialogState();
}

class _DiffReviewDialogState extends State<_DiffReviewDialog> {
  late final bool _isNewFile;
  late final List<FileDiff> _diffs;
  late final List<DiffLine> _rows;
  late final int _adds;
  late final int _dels;
  String _error = '';

  @override
  void initState() {
    super.initState();
    final edit = widget.edit;
    _isNewFile = edit.oldContent == null;
    if (_isNewFile) {
      _diffs = const <FileDiff>[];
      final newLines = _splitLines(edit.newContent);
      _rows = [
        for (var i = 0; i < newLines.length; i++)
          DiffLine('add', newLines[i], newLine: i + 1),
      ];
    } else {
      _diffs = _computeDiff(edit.oldContent!, edit.newContent);
      _rows = [for (final diff in _diffs) ...diff.lines];
    }
    _adds = _rows.where((line) => line.type == 'add').length;
    _dels = _rows.where((line) => line.type == 'del').length;
  }

  void _apply() {
    final chat = context.read<ChatProvider>();
    chat.acceptEdit(widget.message, widget.edit,
        workspaceRoot: widget.workspaceRoot);
    if (widget.edit.accepted) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _error = chat.streamingError.isNotEmpty
          ? chat.streamingError
          : 'Could not apply the change — open a folder first.';
    });
  }

  void _reject() {
    context.read<ChatProvider>().rejectEdit(widget.message, widget.edit);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // Watch so an Apply/Reject performed elsewhere (chat card buttons)
    // updates this dialog's state too.
    context.watch<ChatProvider>();
    final c = context.watch<UiProvider>().palette;

    final size = MediaQuery.of(context).size;
    final width = math.min(720.0, size.width * 0.9);
    final height = math.min(520.0, size.height * 0.9);

    return Dialog(
      backgroundColor: c.panelBackground,
      insetPadding: const EdgeInsets.all(16),
      elevation: 12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: c.borderLight),
      ),
      child: SizedBox(
        width: width,
        height: height,
        child: Column(
          children: [
            _buildHeader(c),
            Expanded(child: _buildBody(c)),
            if (_error.isNotEmpty) _buildErrorStrip(c),
            _buildActions(c),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AppColors c) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: c.panelBackground,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          Icon(Icons.description, size: 16, color: c.blueLight),
          const SizedBox(width: 8),
          Text(
            'Apply file change',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.edit.path,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: c.textSecondary,
                fontFamily: 'FiraCode',
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '+$_adds',
            style: TextStyle(
                fontSize: 11, color: c.green400, fontFamily: 'FiraCode'),
          ),
          const SizedBox(width: 4),
          Text(
            '−$_dels',
            style:
                TextStyle(fontSize: 11, color: c.red400, fontFamily: 'FiraCode'),
          ),
          const SizedBox(width: 8),
          NexoraIconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icons.close,
            size: 14,
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  Widget _buildBody(AppColors c) {
    if (_isNewFile) {
      return _buildNewFilePreview(c);
    }
    if (_rows.isEmpty) {
      return Center(
        child: Text(
          'No textual changes detected.',
          style: TextStyle(fontSize: 12, color: c.textSecondary),
        ),
      );
    }
    return _buildLines(c);
  }

  /// New-file centered preview: line count (12 `#858585`) over a dark mono
  /// preview block (prototype "new file" state).
  Widget _buildNewFilePreview(AppColors c) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_circle_outline, size: 14, color: c.green400),
            const SizedBox(height: 8),
            Text(
              'New file — ${_rows.length} lines',
              style: TextStyle(fontSize: 12, color: c.textSecondary),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: c.background,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: c.borderLight),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final line in _rows)
                          Text(
                            '+ ${line.text}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: c.green400,
                              fontFamily: 'FiraCode',
                              height: 1.4,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLines(AppColors c) {
    return ListView.builder(
      itemCount: _rows.length,
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemBuilder: (context, index) => _buildRow(_rows[index], c),
    );
  }

  /// One fixed-height (18px) diff row (prototype: FiraCode 12): old/new
  /// line-number gutters (36px each, right-aligned 11 `#858585`), a
  /// +/−/space marker, then the code text. Removed rows: red-500/20 bg +
  /// red-400 text; added rows: green-500/20 bg + green-400 text; context
  /// rows keep plain foreground; hunk rows render blue on `#1e1e1e`.
  Widget _buildRow(DiffLine line, AppColors c) {
    final isAdd = line.type == 'add';
    final isDel = line.type == 'del';
    final isHunk = line.type == 'hunk';
    final marker = isAdd ? '+' : (isDel ? '−' : (isHunk ? '@' : ' '));
    final Color? bg;
    final Color fg;
    if (isAdd) {
      bg = c.diffAddBg;
      fg = c.green400;
    } else if (isDel) {
      bg = c.diffDelBg;
      fg = c.red400;
    } else if (isHunk) {
      bg = c.background;
      fg = c.blue400;
    } else {
      bg = null;
      fg = c.textPrimary;
    }
    final numStyle = TextStyle(
      fontSize: 11,
      color: c.textSecondary,
      fontFamily: 'FiraCode',
    );
    return Container(
      height: 18,
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              line.oldLine?.toString() ?? '',
              maxLines: 1,
              textAlign: TextAlign.right,
              style: numStyle,
            ),
          ),
          SizedBox(
            width: 36,
            child: Text(
              line.newLine?.toString() ?? '',
              maxLines: 1,
              textAlign: TextAlign.right,
              style: numStyle,
            ),
          ),
          SizedBox(
            width: 16,
            child: Text(
              marker,
              maxLines: 1,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: fg,
                fontFamily: 'FiraCode',
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              line.text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: fg,
                fontFamily: 'FiraCode',
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Error strip (apply failed): red-500/10 fill, red-400 3px left rule.
  Widget _buildErrorStrip(AppColors c) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: c.red500.withValues(alpha: 0.1),
        border: Border(left: BorderSide(color: c.red400, width: 3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 12, color: c.red400),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _error,
              style: TextStyle(fontSize: 11, color: c.red400, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(AppColors c) {
    final edit = widget.edit;
    final decided = edit.accepted || edit.rejected;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          if (edit.accepted) ...[
            Icon(Icons.check, size: 14, color: c.green400),
            const SizedBox(width: 6),
            Text(
              'Applied to workspace',
              style: TextStyle(fontSize: 12, color: c.green400),
            ),
          ] else if (edit.rejected) ...[
            Icon(Icons.block, size: 14, color: c.textSecondary),
            const SizedBox(width: 6),
            Text('Rejected',
                style: TextStyle(fontSize: 12, color: c.textSecondary)),
          ],
          const Spacer(),
          if (decided)
            NexoraGhostButton(
              onPressed: () => Navigator.of(context).pop(),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: const Text('Close'),
            )
          else ...[
            NexoraGhostButton(
              onPressed: _reject,
              foreground: c.red400,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: const Text('Reject'),
            ),
            const SizedBox(width: 8),
            NexoraPrimaryButton(
              onPressed: _apply,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: const Text('Apply change'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Split into display lines: drop one trailing newline (so "a\nb" and
/// "a\nb\n" diff as equal) and normalize CRLF so LF-written AI output diffs
/// cleanly against CRLF files.
List<String> _splitLines(String text) {
  final lines = text.split('\n');
  if (lines.isNotEmpty && lines.last == '') {
    lines.removeLast();
  }
  return [
    for (final line in lines)
      line.endsWith('\r') ? line.substring(0, line.length - 1) : line
  ];
}

/// LCS is computed only up to this many lines per side; beyond it a
/// whole-file replacement diff (all del + all add) keeps the dialog fast.
const int _maxLcsLines = 800;

/// Classic LCS line diff. Returns a single-entry [FileDiff] list (the
/// signature mirrors the git-service parser so callers can treat both
/// alike). Deletions keep old numbering, additions new numbering, context
/// lines advance both.
List<FileDiff> _computeDiff(String oldText, String newText) {
  final a = _splitLines(oldText);
  final b = _splitLines(newText);
  final out = <DiffLine>[];

  if (a.length > _maxLcsLines || b.length > _maxLcsLines) {
    var n = 0;
    for (final line in a) {
      out.add(DiffLine('del', line, oldLine: ++n));
    }
    n = 0;
    for (final line in b) {
      out.add(DiffLine('add', line, newLine: ++n));
    }
  } else {
    final n = a.length;
    final m = b.length;
    // dp[i][j] = length of the LCS of a[i..] and b[j..]
    final dp = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));
    for (var i = n - 1; i >= 0; i--) {
      final row = dp[i];
      final below = dp[i + 1];
      for (var j = m - 1; j >= 0; j--) {
        row[j] = a[i] == b[j]
            ? below[j + 1] + 1
            : math.max(below[j], row[j + 1]);
      }
    }
    var i = 0;
    var j = 0;
    var oldNo = 0;
    var newNo = 0;
    while (i < n && j < m) {
      if (a[i] == b[j]) {
        out.add(DiffLine('context', a[i],
            oldLine: ++oldNo, newLine: ++newNo));
        i++;
        j++;
      } else if (dp[i + 1][j] >= dp[i][j + 1]) {
        out.add(DiffLine('del', a[i], oldLine: ++oldNo));
        i++;
      } else {
        out.add(DiffLine('add', b[j], newLine: ++newNo));
        j++;
      }
    }
    while (i < n) {
      out.add(DiffLine('del', a[i], oldLine: ++oldNo));
      i++;
    }
    while (j < m) {
      out.add(DiffLine('add', b[j], newLine: ++newNo));
      j++;
    }
  }

  return [FileDiff(path: 'buffer', lines: out)];
}
