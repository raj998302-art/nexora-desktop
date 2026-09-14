import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Lightweight regex-based syntax highlighter (no external deps).
///
/// A single combined regular expression is built per language — named
/// capture groups in priority order: blockComment | lineComment | string |
/// number | tag/cssProp (where applicable) | annotation | identifier |
/// anyWord. The whole source is walked once with [RegExp.allMatches] and a
/// coalesced span tree is emitted (adjacent runs of equal style merge into
/// one span, keeping large files fast). Files longer than 200 000 characters
/// return a single plain span immediately.
class SyntaxHighlighter {
  SyntaxHighlighter._();

  /// Above this size, highlighting is skipped entirely.
  static const int _maxChars = 200000;

  /// Compiled pattern + token-kind table, cached per language.
  static final Map<String, _Compiled> _cache = <String, _Compiled>{};

  /// Returns a [TextSpan] styling [code] for [language] using palette [c].
  ///
  /// Handles line comments (`//`, `#`, `--` per language), block comments
  /// (`/* ... */` for c-like languages), escape-aware strings (`'...'`,
  /// `"..."`, `` `...` ``), numbers, keywords, class-ish identifiers
  /// (Capitalized words → `c.blueLight`), annotations (`@word` →
  /// `c.warning`) and booleans/null-ish literals (→ `c.success`); everything
  /// else renders with `c.editorForeground`.
  static TextSpan highlight(String code, String language, AppColors c,
      {double fontSize = 13}) {
    final root = TextStyle(
      fontFamily: 'monospace',
      fontSize: fontSize,
      height: 1.5,
      color: c.editorForeground,
    );
    if (code.length > _maxChars) {
      return TextSpan(style: root, text: code);
    }
    final lang = _normalize(language);
    if (lang == 'markdown') {
      return _markdown(code, c, root);
    }

    final cfg = _langOf(lang);
    final compiled = _cache[lang] ??= _build(cfg);
    final styles = _Styles(c);
    final b = _SpanBuilder();
    for (final m in compiled.regex.allMatches(code)) {
      b.add(m[0]!, styles.of(m, compiled.kinds, cfg));
    }
    return b.build(root);
  }

  // ------------------------------------------------------------------ //
  // Language normalization & configuration
  // ------------------------------------------------------------------ //

  /// Maps common aliases to the canonical language id.
  static String _normalize(String language) {
    switch (language.trim().toLowerCase()) {
      case 'js':
      case 'jsx':
      case 'mjs':
        return 'javascript';
      case 'ts':
      case 'tsx':
        return 'typescript';
      case 'py':
        return 'python';
      case 'rs':
        return 'rust';
      case 'sh':
      case 'bash':
      case 'zsh':
        return 'shell';
      case 'yml':
        return 'yaml';
      case 'htm':
        return 'html';
      case 'c++':
      case 'cxx':
        return 'cpp';
      default:
        return language.trim().toLowerCase();
    }
  }

  static const _Lang _plain = _Lang();

  static _Lang _langOf(String lang) => _langs[lang] ?? _plain;

  static const Map<String, _Lang> _langs = <String, _Lang>{
    'dart': _Lang(
        keywords: _kwDart,
        lineCommentTokens: <String>['//'],
        blockComments: true),
    'python': _Lang(
        keywords: _kwPython, lineCommentTokens: <String>['#']),
    'javascript':
        _Lang(keywords: _kwJs, lineCommentTokens: <String>['//'], blockComments: true),
    'typescript':
        _Lang(keywords: _kwTs, lineCommentTokens: <String>['//'], blockComments: true),
    'json': _Lang(),
    'yaml': _Lang(
        lineCommentTokens: <String>['#'],
        caseInsensitive: true,
        literals: _yamlLiterals),
    'html': _Lang(tags: true),
    'css': _Lang(blockComments: true, cssProps: true),
    'c': _Lang(
        keywords: _kwC, lineCommentTokens: <String>['//'], blockComments: true),
    'cpp': _Lang(
        keywords: _kwCpp, lineCommentTokens: <String>['//'], blockComments: true),
    'rust': _Lang(
        keywords: _kwRust, lineCommentTokens: <String>['//'], blockComments: true),
    'go': _Lang(
        keywords: _kwGo, lineCommentTokens: <String>['//'], blockComments: true),
    'java': _Lang(
        keywords: _kwJava, lineCommentTokens: <String>['//'], blockComments: true),
    'shell': _Lang(keywords: _kwShell, lineCommentTokens: <String>['#']),
    'toml': _Lang(
        lineCommentTokens: <String>['#'],
        caseInsensitive: true,
        literals: _yamlLiterals),
    'xml': _Lang(tags: true),
    'sql': _Lang(
        keywords: _kwSql,
        literals: _sqlLiterals,
        lineCommentTokens: <String>['--'],
        caseInsensitive: true),
  };

  // ------------------------------------------------------------------ //
  // Pattern construction
  // ------------------------------------------------------------------ //

  /// Builds the combined token regex. `kinds[i]` describes capture group
  /// `i + 1` (every alternative wraps exactly one named group, and all
  /// inner groups are non-capturing, so the numbering is stable).
  static _Compiled _build(_Lang cfg) {
    final alts = <String>[];
    final kinds = <String>[];
    void add(String kind, String pattern) {
      kinds.add(kind);
      alts.add(pattern);
    }

    if (cfg.blockComments) {
      add('comment', r'(?<blockComment>/\*[\s\S]*?\*/)');
    }
    if (cfg.lineCommentTokens.isNotEmpty) {
      final markers =
          cfg.lineCommentTokens.map(RegExp.escape).join('|');
      add('comment', '(?<lineComment>(?:$markers)[^\\n]*)');
    }
    add(
        'string',
        r'''(?<string>'(?:[^'\\\n]|\\.)*'|"(?:[^"\\\n]|\\.)*"|`(?:[^`\\]|\\.)*`)''');
    add(
        'number',
        r'(?<number>0[xX][0-9a-fA-F_]+|\d[\d_]*(?:\.[\d_]+)?(?:[eE][+-]?\d+)?|\.\d[\d_]*)');
    if (cfg.tags) {
      add('tag', r'(?<tag><\s*/?\s*[a-zA-Z][\w:.-]*)');
    }
    if (cfg.cssProps) {
      add('cssProp', r'(?<cssProp>[a-zA-Z-]+(?=\s*:))');
    }
    add('annotation', r'(?<annotation>@\w+)');
    add('identifier', r'(?<identifier>[A-Za-z_$][\w$]*)');
    add('any', r'(?<anyWord>.)');

    return _Compiled(RegExp(alts.join('|')), kinds);
  }

  // ------------------------------------------------------------------ //
  // Markdown (headings + bold only)
  // ------------------------------------------------------------------ //

  static TextSpan _markdown(String code, AppColors c, TextStyle root) {
    final b = _SpanBuilder();
    final heading = TextStyle(color: c.keyword, fontWeight: FontWeight.bold);
    final bold =
        TextStyle(color: c.editorForeground, fontWeight: FontWeight.bold);
    final plain = TextStyle(color: c.editorForeground);
    final headingRe = RegExp(r'^\s{0,3}#{1,6}(\s|$)');
    final boldRe = RegExp(r'\*\*[^*\n]+\*\*|__[^_\n]+__');
    final lines = code.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (headingRe.hasMatch(line)) {
        b.add(line, heading);
      } else {
        var last = 0;
        for (final m in boldRe.allMatches(line)) {
          if (m.start > last) {
            b.add(line.substring(last, m.start), plain);
          }
          b.add(m[0]!, bold);
          last = m.end;
        }
        if (last < line.length) {
          b.add(line.substring(last), plain);
        }
      }
      if (i < lines.length - 1) {
        b.add('\n', plain);
      }
    }
    return b.build(root);
  }
}

// -------------------------------------------------------------------- //
// Internal support classes
// -------------------------------------------------------------------- //

/// Per-language highlighting configuration.
class _Lang {
  /// Language keywords (compared in original case, or lowercased when
  /// [caseInsensitive]).
  final Set<String> keywords;

  /// Booleans / null-ish literals (styled with `c.success`).
  final Set<String> literals;

  /// Line-comment markers, e.g. `//`, `#`, `--`.
  final List<String> lineCommentTokens;

  /// Whether `/* ... */` block comments apply (c-like family).
  final bool blockComments;

  /// Whether `<tag` sequences highlight as tags (html/xml).
  final bool tags;

  /// Whether `name:` sequences highlight as properties (css).
  final bool cssProps;

  /// Lowercase keyword/literal matching (sql, yaml, toml).
  final bool caseInsensitive;

  const _Lang({
    this.keywords = const <String>{},
    this.literals = _coreLiterals,
    this.lineCommentTokens = const <String>[],
    this.blockComments = false,
    this.tags = false,
    this.cssProps = false,
    this.caseInsensitive = false,
  });
}

/// A compiled token regex plus the token kind of each capture group.
class _Compiled {
  final RegExp regex;

  /// `kinds[i]` is the kind of capture group `i + 1`.
  final List<String> kinds;

  const _Compiled(this.regex, this.kinds);
}

/// The style set for one palette; token matches map onto these styles.
class _Styles {
  final AppColors c;

  _Styles(this.c);

  late final TextStyle comment =
      TextStyle(color: c.comment, fontStyle: FontStyle.italic);
  late final TextStyle string = TextStyle(color: c.string);
  late final TextStyle number = TextStyle(color: c.number);
  late final TextStyle keyword = TextStyle(color: c.keyword);
  late final TextStyle literal = TextStyle(color: c.success);
  late final TextStyle klass = TextStyle(color: c.blueLight);
  late final TextStyle annotation = TextStyle(color: c.warning);
  late final TextStyle plain = TextStyle(color: c.editorForeground);

  /// Style for a token match: the first participating capture group decides.
  TextStyle of(RegExpMatch m, List<String> kinds, _Lang cfg) {
    for (var i = 0; i < kinds.length; i++) {
      final g = m.group(i + 1);
      if (g == null) continue;
      switch (kinds[i]) {
        case 'comment':
          return comment;
        case 'string':
          return string;
        case 'number':
          return number;
        case 'tag':
        case 'cssProp':
          return keyword;
        case 'annotation':
          return annotation;
        case 'identifier':
          return _identifier(g, cfg);
      }
    }
    return plain;
  }

  TextStyle _identifier(String word, _Lang cfg) {
    final probe = cfg.caseInsensitive ? word.toLowerCase() : word;
    if (cfg.literals.contains(probe)) return literal;
    if (cfg.keywords.contains(probe)) return keyword;
    final code = word.codeUnitAt(0);
    return (code >= 0x41 && code <= 0x5A) ? klass : plain;
  }
}

/// Accumulates styled text runs, merging adjacent runs with equal styles so
/// the final span tree stays small.
class _SpanBuilder {
  final List<TextSpan> _spans = <TextSpan>[];
  final StringBuffer _buf = StringBuffer();
  TextStyle? _style;

  void add(String text, TextStyle style) {
    if (_style == style) {
      _buf.write(text);
      return;
    }
    _flush();
    _style = style;
    _buf.write(text);
  }

  void _flush() {
    if (_buf.isNotEmpty) {
      _spans.add(TextSpan(text: _buf.toString(), style: _style));
      _buf.clear();
    }
  }

  TextSpan build(TextStyle root) {
    _flush();
    return TextSpan(style: root, children: _spans.isEmpty ? null : _spans);
  }
}

// -------------------------------------------------------------------- //
// Keyword tables (true/false/null-ish literals are handled separately)
// -------------------------------------------------------------------- //

const Set<String> _coreLiterals = <String>{
  'true', 'false', 'null', 'True', 'False', 'None',
  'nil', 'nullptr', 'undefined', 'NULL', 'NaN',
};

const Set<String> _yamlLiterals = <String>{
  'true', 'false', 'null', 'yes', 'no', 'on', 'off', 'nil', 'nan',
};

const Set<String> _sqlLiterals = <String>{'null', 'true', 'false'};

const Set<String> _kwDart = <String>{
  'abstract', 'as', 'assert', 'async', 'await', 'base', 'break', 'case',
  'catch', 'class', 'const', 'continue', 'covariant', 'default',
  'deferred', 'do', 'dynamic', 'else', 'enum', 'export', 'extends',
  'extension', 'external', 'factory', 'final', 'finally', 'for', 'get',
  'hide', 'if', 'implements', 'import', 'in', 'interface', 'is', 'late',
  'library', 'mixin', 'new', 'on', 'operator', 'part', 'required',
  'rethrow', 'return', 'sealed', 'set', 'show', 'static', 'super',
  'switch', 'sync', 'this', 'throw', 'try', 'typedef', 'var', 'void',
  'when', 'while', 'with', 'yield',
};

const Set<String> _kwPython = <String>{
  'and', 'as', 'assert', 'async', 'await', 'break', 'case', 'class',
  'continue', 'def', 'del', 'elif', 'else', 'except', 'finally', 'for',
  'from', 'global', 'if', 'import', 'in', 'is', 'lambda', 'match',
  'nonlocal', 'not', 'or', 'pass', 'raise', 'return', 'try', 'while',
  'with', 'yield',
};

const Set<String> _kwJs = <String>{
  'async', 'await', 'break', 'case', 'catch', 'class', 'const',
  'continue', 'debugger', 'default', 'delete', 'do', 'else', 'export',
  'extends', 'finally', 'for', 'from', 'function', 'get', 'if', 'import',
  'in', 'instanceof', 'let', 'new', 'of', 'return', 'set', 'static',
  'super', 'switch', 'this', 'throw', 'try', 'typeof', 'var', 'void',
  'while', 'with', 'yield',
};

const Set<String> _kwTs = <String>{
  ..._kwJs,
  'abstract', 'any', 'asserts', 'bigint', 'boolean', 'declare', 'enum',
  'implements', 'infer', 'interface', 'is', 'keyof', 'module', 'namespace',
  'never', 'number', 'object', 'override', 'private', 'protected',
  'public', 'readonly', 'satisfies', 'string', 'symbol', 'type',
  'unknown',
};

const Set<String> _kwC = <String>{
  'auto', 'break', 'case', 'char', 'const', 'continue', 'default', 'do',
  'double', 'else', 'enum', 'extern', 'float', 'for', 'goto', 'if',
  'inline', 'int', 'long', 'register', 'restrict', 'return', 'short',
  'signed', 'sizeof', 'static', 'struct', 'switch', 'typedef', 'union',
  'unsigned', 'void', 'volatile', 'while', '_Bool', '_Complex',
  '_Imaginary',
};

const Set<String> _kwCpp = <String>{
  ..._kwC,
  'alignas', 'alignof', 'and', 'bool', 'catch', 'char8_t', 'char16_t',
  'char32_t', 'class', 'co_await', 'co_return', 'co_yield', 'concept',
  'const_cast', 'constexpr', 'decltype', 'delete', 'dynamic_cast',
  'explicit', 'export', 'friend', 'mutable', 'namespace', 'new',
  'noexcept', 'not', 'nullptr', 'operator', 'or', 'private', 'protected',
  'public', 'reinterpret_cast', 'requires', 'static_assert',
  'static_cast', 'template', 'this', 'throw', 'try', 'typeid', 'typename',
  'using', 'virtual', 'wchar_t',
};

const Set<String> _kwRust = <String>{
  'as', 'async', 'await', 'break', 'const', 'continue', 'crate', 'dyn',
  'else', 'enum', 'extern', 'fn', 'for', 'if', 'impl', 'in', 'let',
  'loop', 'match', 'mod', 'move', 'mut', 'pub', 'ref', 'return', 'self',
  'static', 'struct', 'super', 'trait', 'type', 'unsafe', 'use', 'where',
  'while', 'box', 'final', 'macro', 'override', 'priv', 'typeof',
  'unsized', 'virtual', 'yield',
};

const Set<String> _kwGo = <String>{
  'break', 'case', 'chan', 'const', 'continue', 'default', 'defer',
  'else', 'fallthrough', 'for', 'func', 'go', 'goto', 'if', 'import',
  'interface', 'map', 'package', 'range', 'return', 'select', 'struct',
  'switch', 'type', 'var',
};

const Set<String> _kwJava = <String>{
  'abstract', 'assert', 'boolean', 'break', 'byte', 'case', 'catch',
  'char', 'class', 'const', 'continue', 'default', 'do', 'double',
  'else', 'enum', 'extends', 'final', 'finally', 'float', 'for', 'goto',
  'if', 'implements', 'import', 'instanceof', 'int', 'interface', 'long',
  'native', 'new', 'package', 'permits', 'private', 'protected',
  'public', 'record', 'return', 'sealed', 'short', 'static', 'strictfp',
  'super', 'switch', 'synchronized', 'this', 'throw', 'throws',
  'transient', 'try', 'var', 'void', 'volatile', 'while', 'yield',
};

const Set<String> _kwShell = <String>{
  'alias', 'break', 'case', 'continue', 'coproc', 'declare', 'do', 'done',
  'elif', 'else', 'esac', 'exit', 'export', 'fi', 'for', 'function',
  'if', 'in', 'local', 'readonly', 'return', 'select', 'shift', 'source',
  'then', 'time', 'trap', 'typeset', 'unset', 'until', 'while',
};

const Set<String> _kwSql = <String>{
  'add', 'all', 'alter', 'and', 'any', 'as', 'asc', 'begin', 'between',
  'by', 'case', 'check', 'column', 'constraint', 'create', 'cross',
  'current_date', 'current_time', 'current_timestamp', 'database',
  'default', 'delete', 'desc', 'distinct', 'drop', 'else', 'end',
  'escape', 'exists', 'foreign', 'from', 'full', 'grant', 'group',
  'having', 'if', 'index', 'inner', 'insert', 'into', 'is', 'join',
  'key', 'left', 'like', 'limit', 'natural', 'not', 'null', 'offset',
  'on', 'or', 'order', 'outer', 'partition', 'primary', 'references',
  'restrict', 'revoke', 'right', 'rollback', 'rows', 'select', 'set',
  'table', 'then', 'to', 'transaction', 'trigger', 'union', 'unique',
  'update', 'user', 'using', 'values', 'view', 'when', 'where', 'with',
};
