// NEXORA — diff review dialog for AI-proposed file edits (PendingEdit).
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
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: c.border),
      ),
      child: SizedBox(
        width: width,
        height: height,
        child: Column(
          children: [
            _buildHeader(c),
            Divider(height: 1, thickness: 1, color: c.border),
            Expanded(child: _buildBody(c)),
            if (_error.isNotEmpty)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                color: c.error.withValues(alpha: 0.1),
                child: Text(
                  _error,
                  style: TextStyle(fontSize: 11, color: c.error),
                ),
              ),
            Divider(height: 1, thickness: 1, color: c.border),
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
          Text(
            '+$_adds',
            style: TextStyle(
                fontSize: 11, color: c.success, fontFamily: 'monospace'),
          ),
          const SizedBox(width: 4),
          Text(
            '−$_dels',
            style: TextStyle(
                fontSize: 11, color: c.error, fontFamily: 'monospace'),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.edit.path,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                color: c.textSecondary,
                fontFamily: 'monospace',
              ),
            ),
          ),
          IconButton(
            tooltip: 'Close',
            icon: Icon(Icons.close, size: 16, color: c.textSecondary),
            onPressed: () => Navigator.of(context).pop(),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            style: IconButton.styleFrom(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(AppColors c) {
    if (_isNewFile) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Icon(Icons.add_circle_outline, size: 12, color: c.success),
                const SizedBox(width: 6),
                Text(
                  'New file — ${_rows.length} lines',
                  style: TextStyle(fontSize: 11, color: c.textSecondary),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: c.border),
          Expanded(child: _buildLines(c)),
        ],
      );
    }
    if (_rows.isEmpty) {
      return Center(
        child: Text(
          'No textual changes detected.',
          style: TextStyle(fontSize: 11, color: c.textSecondary),
        ),
      );
    }
    return _buildLines(c);
  }

  Widget _buildLines(AppColors c) {
    return ListView.builder(
      itemCount: _rows.length,
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemBuilder: (context, index) => _buildRow(_rows[index], c),
    );
  }

  /// One fixed-height (18px) diff row: old/new line-number gutters (40px
  /// each, right-aligned), a +/−/space marker, then the code text.
  Widget _buildRow(DiffLine line, AppColors c) {
    final isAdd = line.type == 'add';
    final isDel = line.type == 'del';
    final marker = isAdd ? '+' : (isDel ? '−' : ' ');
    final markerColor = isAdd ? c.success : (isDel ? c.error : c.textSecondary);
    final textColor = isAdd ? c.success : (isDel ? c.error : c.textPrimary);
    final monoSecondary = TextStyle(
      fontSize: 11,
      color: c.textSecondary,
      fontFamily: 'monospace',
    );
    return Container(
      height: 18,
      color: isAdd
          ? c.diffAddBg
          : isDel
              ? c.diffDelBg
              : null,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              line.oldLine?.toString() ?? '',
              maxLines: 1,
              textAlign: TextAlign.right,
              style: monoSecondary,
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              line.newLine?.toString() ?? '',
              maxLines: 1,
              textAlign: TextAlign.right,
              style: monoSecondary,
            ),
          ),
          SizedBox(
            width: 14,
            child: Text(
              marker,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: markerColor,
                fontFamily: 'monospace',
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
                color: textColor,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(AppColors c) {
    final edit = widget.edit;
    final decided = edit.accepted || edit.rejected;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          if (edit.accepted) ...[
            Icon(Icons.check, size: 14, color: c.success),
            const SizedBox(width: 6),
            Text(
              'Applied to workspace',
              style: TextStyle(fontSize: 12, color: c.success),
            ),
          ] else if (edit.rejected) ...[
            Icon(Icons.block, size: 14, color: c.textSecondary),
            const SizedBox(width: 6),
            Text('Rejected',
                style: TextStyle(fontSize: 12, color: c.textSecondary)),
          ],
          const Spacer(),
          if (decided)
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: c.textPrimary,
                side: BorderSide(color: c.borderLight),
                minimumSize: const Size(72, 32),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                textStyle: const TextStyle(fontSize: 12),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Close'),
            )
          else ...[
            OutlinedButton(
              onPressed: _reject,
              style: OutlinedButton.styleFrom(
                foregroundColor: c.error,
                side: BorderSide(color: c.error.withValues(alpha: 0.6)),
                minimumSize: const Size(72, 32),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                textStyle: const TextStyle(fontSize: 12),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Reject'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _apply,
              style: FilledButton.styleFrom(
                backgroundColor: c.accent,
                foregroundColor: c.textOnAccent,
                minimumSize: const Size(104, 32),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                textStyle: const TextStyle(fontSize: 12),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
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
