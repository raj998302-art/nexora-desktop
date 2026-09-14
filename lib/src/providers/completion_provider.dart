import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/ai_service.dart';

/// Ghost-text (inline tab completion) state. The editor calls [request] after
/// a typing pause; the provider debounces, calls the AI FIM endpoint, and
/// exposes the current suggestion which the editor overlays after the caret.
/// Tab accepts, Escape or any edit dismisses.
class CompletionProvider extends ChangeNotifier {
  final AiService _ai;
  final bool Function() _enabled;

  Timer? _debounce;
  String _suggestion = '';
  String _forPath = '';
  int _forOffset = -1;
  bool _inFlight = false;
  int _generation = 0;

  CompletionProvider(this._ai, this._enabled);

  String get suggestion => _suggestion;
  String get forPath => _forPath;
  int get forOffset => _forOffset;
  bool get hasSuggestion => _suggestion.isNotEmpty;

  /// [prefix] is text before the caret; [suffix] after it.
  void request(String path, int offset, String prefix, String suffix) {
    _debounce?.cancel();
    if (!_enabled() || prefix.trim().length < 3) {
      _clear();
      return;
    }
    final gen = ++_generation;
    _debounce = Timer(const Duration(milliseconds: 600), () async {
      if (_inFlight) return;
      _inFlight = true;
      try {
        final text = await _ai.completeCode(prefix, suffix);
        if (_generation != gen) return; // stale
        if (text.isEmpty) {
          _clear();
          return;
        }
        _suggestion = text;
        _forPath = path;
        _forOffset = offset;
        notifyListeners();
      } finally {
        _inFlight = false;
      }
    });
  }

  /// Called on any keystroke/edit to invalidate the current ghost text.
  void invalidate() {
    _debounce?.cancel();
    if (_suggestion.isNotEmpty) {
      _clear();
    }
  }

  void _clear() {
    _suggestion = '';
    _forPath = '';
    _forOffset = -1;
    notifyListeners();
  }

  /// Accept: returns the suggestion and clears state.
  String accept() {
    final s = _suggestion;
    _debounce?.cancel();
    _clear();
    return s;
  }

  void dismiss() {
    _debounce?.cancel();
    if (_suggestion.isNotEmpty || _forOffset != -1) _clear();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
