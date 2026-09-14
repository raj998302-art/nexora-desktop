import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/models.dart';

/// Outcome of an AI backend connectivity test.
class AiTestResult {
  /// Whether the backend is reachable and responded sanely.
  final bool ok;

  /// Human-readable status / warning / error text for the Settings screen.
  final String message;

  const AiTestResult(this.ok, this.message);
}

/// Connection, HTTP or backend-reported error. [toString] returns the raw
/// message so UI code can surface it directly.
class AiException implements Exception {
  final String message;

  AiException(this.message);

  @override
  String toString() => message;
}

/// Chat client for local AI backends — Ollama (`/api/*`) or any
/// OpenAI-compatible server (`/v1/*`).
///
/// Every public method re-reads [AppSettings] through the constructor's
/// `settingsGetter` at call time, so Settings-screen changes apply without
/// recreating the service. A single shared `dart:io` [HttpClient]
/// (connectionTimeout 8s) is created lazily and closed by [dispose].
class AiService {
  /// [settingsGetter] returns the CURRENT [AppSettings] each call (live values).
  AiService(AppSettings Function() settingsGetter)
      : _settingsGetter = settingsGetter;

  final AppSettings Function() _settingsGetter;

  /// Detected backend type: 'ollama', 'openai', or '' (unknown).
  String detectedType = '';

  HttpClient? _client;
  String? _lastProbedBase;
  String _cachedType = '';

  /// Per-request timeout for detection probes.
  static const Duration _probeTimeout = Duration(seconds: 4);

  /// Max silence between stream events before a chat stream errors out.
  static const Duration _streamIdleTimeout = Duration(seconds: 300);

  /// The shared, lazily created HTTP client.
  HttpClient get _http => _client ??=
      HttpClient()..connectionTimeout = const Duration(seconds: 8);

  // ------------------------------------------------------------------ //
  // Backend detection
  // ------------------------------------------------------------------ //

  /// Detects the backend type by probing `GET {base}/api/tags` (Ollama),
  /// then `GET {base}/v1/models` (OpenAI-compatible). The result is cached
  /// per baseUrl and re-probed when the baseUrl changes. Never throws —
  /// returns '' on failure. Uses a 4s timeout per probe.
  Future<String> detectApiType() async {
    var type = '';
    try {
      final base = _base(_settingsGetter());
      if (_lastProbedBase == base && _cachedType.isNotEmpty) {
        detectedType = _cachedType;
        return _cachedType;
      }
      _lastProbedBase = base;
      if (await _probe('$base/api/tags')) {
        type = 'ollama';
      } else if (await _probe('$base/v1/models')) {
        type = 'openai';
      }
      // Only successful detections are cached; failures retry cheaply.
      if (type.isNotEmpty) _cachedType = type;
    } catch (_) {
      type = ''; /* contract: never throws */
    }
    detectedType = type;
    return type;
  }

  // ------------------------------------------------------------------ //
  // Chat
  // ------------------------------------------------------------------ //

  /// Streaming chat. Yields string deltas of assistant content; throws
  /// [AiException] on connection or backend errors (the caller catches and
  /// shows them).
  ///
  /// Works with BOTH protocols:
  /// - Ollama: `POST {base}/api/chat` → NDJSON lines
  ///   `{"message":{"content":"..."},"done":bool}`.
  /// - OpenAI: `POST {base}/v1/chat/completions` → SSE lines
  ///   `data: {json}` with `choices[0].delta.content`, ended by
  ///   `data: [DONE]`.
  ///
  /// The response is parsed incrementally (utf8-decoded, buffered, split on
  /// '\n' with the partial remainder kept). If the backend reports a JSON
  /// `{"error": ...}` payload an [AiException] is thrown.
  Stream<String> chatStream(List<ChatMessage> messages) =>
      _chatStream(messages);

  /// Non-streaming chat (used for commit messages etc). Collects
  /// [chatStream] into the full reply text. Throws on error.
  Future<String> chatOnce(List<ChatMessage> messages, {int? maxTokens}) async {
    final buffer = StringBuffer();
    await for (final delta in _chatStream(messages, maxTokens: maxTokens)) {
      buffer.write(delta);
    }
    return buffer.toString();
  }

  // ------------------------------------------------------------------ //
  // Ghost-text code completion
  // ------------------------------------------------------------------ //

  /// Fast fill-in-the-middle completion for editor ghost text.
  ///
  /// Returns '' on ANY failure/timeout — NEVER throws, stays silent: ghost
  /// text is optional UX. Hard timeout 1500ms; token budget capped at 48.
  ///
  /// - openai type: `POST {base}/v1/completions` with `prompt`/`suffix`
  ///   (non-streaming). On HTTP failure/404 falls back to the Ollama path.
  /// - ollama type (and the openai fallback): `POST {base}/api/generate`
  ///   with a `<|fim_prefix|>…<|fim_suffix|>…<|fim_middle|>` prompt,
  ///   `raw: true`. If that fails, a chat-style completion is attempted —
  ///   only when the prefix is longer than 40 chars.
  ///
  /// Returned text is truncated at the first blank line and at 300 chars.
  Future<String> completeCode(String prefix, String suffix) async {
    try {
      return await _completeCode(prefix, suffix).timeout(
        const Duration(milliseconds: 1500),
        onTimeout: () => '',
      );
    } catch (_) {
      return ''; /* ghost text must stay silent on any failure */
    }
  }

  // ------------------------------------------------------------------ //
  // Settings-screen helpers
  // ------------------------------------------------------------------ //

  /// Connectivity test for the Settings screen. ALWAYS resolves within 6
  /// seconds (ok=false on timeout); never hangs, never leaves a dangling
  /// Completer, never leaks an HttpClient (the shared client is reused and
  /// closed by [dispose]).
  ///
  /// Probes the backend type, then loads the model list from
  /// `{base}/api/tags` or `{base}/v1/models` and verifies the configured
  /// model name appears (contains match). If the list loads but the model
  /// is missing, returns ok=true with a warning listing up to 6 available
  /// models; if the list fails, returns ok=false with the socket error.
  Future<AiTestResult> testConnection() async {
    try {
      return await _testConnection().timeout(
        const Duration(seconds: 6),
        onTimeout: () => const AiTestResult(
            false, 'Timed out after 6s — the backend is unreachable.'),
      );
    } catch (e) {
      return AiTestResult(false, e.toString());
    }
  }

  /// Best-effort list of model ids from the backend; empty list on failure.
  Future<List<String>> listModels() async {
    try {
      final s = _settingsGetter();
      final base = _base(s);
      final type = _explicitType(s) ?? await detectApiType();
      for (final url in _modelListUrls(base, type)) {
        try {
          final models = await _fetchModelNames(url);
          models.sort(
              (a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
          return models;
        } on Exception {
          /* try the next endpoint */
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Closes the shared HTTP client safely (idempotent).
  void dispose() {
    _client?.close(force: true);
    _client = null;
  }

  // ------------------------------------------------------------------ //
  // Internals
  // ------------------------------------------------------------------ //

  /// Normalizes the configured base URL: strips trailing '/', and prepends
  /// 'http://' when the user typed a bare host such as 'localhost:11434'.
  String _base(AppSettings s) {
    var b = s.aiBaseUrl.trim();
    if (b.isEmpty) b = 'http://localhost:11434';
    if (!b.startsWith('http://') && !b.startsWith('https://')) {
      b = 'http://$b';
    }
    while (b.endsWith('/')) {
      b = b.substring(0, b.length - 1);
    }
    return b;
  }

  /// Explicit backend type from settings, or null when 'auto'/invalid.
  String? _explicitType(AppSettings s) {
    final t = s.aiApiType.trim().toLowerCase();
    return (t == 'ollama' || t == 'openai') ? t : null;
  }

  /// Effective backend: explicit setting, else detection, else 'ollama'
  /// (the app default is a local Ollama endpoint).
  Future<String> _resolveType(AppSettings s) async {
    final explicit = _explicitType(s);
    if (explicit != null) {
      detectedType = explicit;
      return explicit;
    }
    final detected = await detectApiType();
    return detected.isNotEmpty ? detected : 'ollama';
  }

  /// Candidate model-list endpoints for the resolved backend type.
  List<String> _modelListUrls(String base, String type) {
    switch (type) {
      case 'openai':
        return ['$base/v1/models'];
      case 'ollama':
        return ['$base/api/tags'];
      default:
        return ['$base/api/tags', '$base/v1/models'];
    }
  }

  /// GET [url]; true for any 2xx response. Never throws.
  Future<bool> _probe(String url) async {
    final client = _http;
    try {
      final req = await client.getUrl(Uri.parse(url)).timeout(_probeTimeout);
      final res = await req.close().timeout(_probeTimeout);
      try {
        await res.drain<void>().timeout(_probeTimeout);
      } catch (_) {
        /* draining is best-effort */
      }
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  /// GET [url] and parse the model list (Ollama `models[].name` or
  /// OpenAI-compatible `data[].id`). Throws on HTTP/parse failure.
  Future<List<String>> _fetchModelNames(String url,
      {Duration timeout = const Duration(seconds: 4)}) async {
    final req = await _http.getUrl(Uri.parse(url)).timeout(timeout);
    final res = await req.close().timeout(timeout);
    final body = await res.transform(utf8.decoder).join().timeout(timeout);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw AiException('HTTP ${res.statusCode} from $url');
    }
    final obj = _tryJson(body);
    if (obj == null) throw AiException('Invalid JSON from $url');
    return _extractModelIds(obj);
  }

  /// The 6s-bounded test behind [testConnection].
  Future<AiTestResult> _testConnection() async {
    final s = _settingsGetter();
    final base = _base(s);
    final type = _explicitType(s) ?? await detectApiType();
    Object? lastError;
    for (final url in _modelListUrls(base, type)) {
      try {
        final models =
            await _fetchModelNames(url, timeout: const Duration(seconds: 3));
        return _checkModel(s, models, type);
      } on Exception catch (e) {
        lastError = e;
      }
    }
    return AiTestResult(
        false, 'Failed to reach backend: ${lastError ?? 'unknown error'}');
  }

  /// Model-availability verdict for the loaded model list.
  AiTestResult _checkModel(AppSettings s, List<String> models, String type) {
    final label = type.isEmpty ? 'auto' : type;
    final cfg = s.aiModel.trim().toLowerCase();
    final found =
        cfg.isNotEmpty && models.any((m) => m.toLowerCase().contains(cfg));
    if (found) {
      return AiTestResult(
          true, 'Connected ($label). Model "${s.aiModel}" is available.');
    }
    if (models.isEmpty) {
      return AiTestResult(
          true,
          'Connected ($label), but "${s.aiModel}" was not found and no other '
          'models are installed.');
    }
    final shown = models.take(6).join(', ');
    final extra = models.length > 6 ? ' (+${models.length - 6} more)' : '';
    return AiTestResult(
        true,
        'Connected ($label), but "${s.aiModel}" was not found. '
        'Available: $shown$extra');
  }

  /// Non-streaming JSON POST; returns the decoded object. Throws
  /// [AiException] on transport failure, non-2xx status or `{"error":...}`.
  Future<Map<String, dynamic>> _postJson(String url, Map<String, dynamic> body,
      {Duration timeout = const Duration(seconds: 5)}) async {
    final req = await _http.postUrl(Uri.parse(url)).timeout(timeout);
    req.headers.set('Content-Type', 'application/json');
    req.write(jsonEncode(body));
    final res = await req.close().timeout(timeout);
    final text = await res.transform(utf8.decoder).join().timeout(timeout);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final obj = _tryJson(text);
      final detail =
          obj != null ? (_errorText(obj) ?? _snippet(text)) : _snippet(text);
      throw AiException(
          'HTTP ${res.statusCode} from $url${detail.isEmpty ? '' : ': $detail'}');
    }
    final obj = _tryJson(text);
    if (obj == null) throw AiException('Invalid JSON from $url');
    final err = _errorText(obj);
    if (err != null) throw AiException(err);
    return obj;
  }

  /// The shared streaming chat implementation (chatStream with an optional
  /// token override used by [chatOnce]).
  Stream<String> _chatStream(List<ChatMessage> messages, {int? maxTokens}) async* {
    final s = _settingsGetter();
    final base = _base(s);
    final type = await _resolveType(s);
    final isOllama = type != 'openai';
    final url = isOllama ? '$base/api/chat' : '$base/v1/chat/completions';
    final apiMessages = <Map<String, String>>[
      for (final m in messages) {'role': m.role.name, 'content': m.content},
    ];
    final tokens = maxTokens ?? s.aiMaxTokens;
    final body = isOllama
        ? <String, dynamic>{
            'model': s.aiModel,
            'messages': apiMessages,
            'stream': true,
            'options': {'temperature': s.aiTemperature, 'num_predict': tokens},
          }
        : <String, dynamic>{
            'model': s.aiModel,
            'messages': apiMessages,
            'stream': true,
            'temperature': s.aiTemperature,
            'max_tokens': tokens,
          };

    final HttpClientRequest request;
    final HttpClientResponse response;
    try {
      request =
          await _http.postUrl(Uri.parse(url)).timeout(const Duration(seconds: 20));
      request.headers.set('Content-Type', 'application/json');
      request.write(jsonEncode(body));
      response = await request.close().timeout(const Duration(seconds: 120));
    } on TimeoutException {
      throw AiException('The AI backend did not respond in time.');
    } on Exception catch (e) {
      throw AiException('Cannot connect to $url: $e');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final text = await _drain(response);
      final obj = _tryJson(text);
      final detail =
          obj != null ? (_errorText(obj) ?? _snippet(text)) : _snippet(text);
      throw AiException(
          'HTTP ${response.statusCode} from $url${detail.isEmpty ? '' : ': $detail'}');
    }

    var buffer = '';
    var done = false;
    final stream = response.transform(utf8.decoder).timeout(
          _streamIdleTimeout,
          onTimeout: (sink) {
            sink.addError(
                AiException('Timed out while streaming the AI response.'));
            sink.close();
          },
        );
    await for (final chunk in stream) {
      buffer += chunk;
      while (!done) {
        final nl = buffer.indexOf('\n');
        if (nl == -1) break;
        final r = _parseStreamLine(buffer.substring(0, nl), isOllama);
        buffer = buffer.substring(nl + 1);
        final d = r.delta;
        if (d != null && d.isNotEmpty) yield d;
        if (r.done) done = true;
      }
      if (done) break;
    }
    // Final partial line when the stream ends without a trailing newline.
    if (!done && buffer.isNotEmpty) {
      final r = _parseStreamLine(buffer, isOllama);
      final d = r.delta;
      if (d != null && d.isNotEmpty) yield d;
    }
  }

  /// The ghost-text completion pipeline (errors are swallowed by the
  /// caller's 1500ms-bounded wrapper).
  Future<String> _completeCode(String prefix, String suffix) async {
    final s = _settingsGetter();
    final base = _base(s);
    final type = await _resolveType(s);
    // Cap the context so the round-trip fits the ghost-text time budget.
    final pre =
        prefix.length > 4000 ? prefix.substring(prefix.length - 4000) : prefix;
    final suf = suffix.length > 2000 ? suffix.substring(0, 2000) : suffix;

    if (type == 'openai') {
      try {
        final text = await _openaiFim(s, base, pre, suf);
        if (text.isNotEmpty) return _clip(text);
      } on Exception {
        /* 404 / failure → ollama-style FIM below */
      }
    }
    try {
      final text = await _ollamaFim(s, base, pre, suf);
      if (text.isNotEmpty) return _clip(text);
    } on Exception {
      /* → chat-style fallback below */
    }
    if (prefix.length > 40) {
      try {
        return _clip(await _chatComplete(s, base, type, pre));
      } on Exception {
        /* silent */
      }
    }
    return '';
  }

  /// OpenAI-style FIM via `POST {base}/v1/completions`.
  Future<String> _openaiFim(
      AppSettings s, String base, String prefix, String suffix) async {
    final obj = await _postJson('$base/v1/completions', <String, dynamic>{
      'model': s.aiModel,
      'prompt': prefix,
      'suffix': suffix,
      'max_tokens': 48,
      'temperature': 0.1,
      'stop': ['\n\n'],
    });
    final choices = obj['choices'];
    if (choices is List && choices.isNotEmpty) {
      final first = choices[0];
      if (first is Map) {
        final text = first['text'];
        if (text is String) return text;
      }
    }
    return '';
  }

  /// Ollama-style FIM via `POST {base}/api/generate` (raw prompt).
  Future<String> _ollamaFim(
      AppSettings s, String base, String prefix, String suffix) async {
    final obj = await _postJson('$base/api/generate', <String, dynamic>{
      'model': s.aiModel,
      'prompt': '<|fim_prefix|>$prefix<|fim_suffix|>$suffix<|fim_middle|>',
      'raw': true,
      'stream': false,
      'options': const <String, dynamic>{'temperature': 0.1, 'num_predict': 48},
    });
    final response = obj['response'];
    return response is String ? response : '';
  }

  /// Last-resort chat-style completion (prefix longer than 40 chars).
  Future<String> _chatComplete(
      AppSettings s, String base, String type, String prefix) async {
    final isOllama = type != 'openai';
    final url = isOllama ? '$base/api/chat' : '$base/v1/chat/completions';
    final messages = <Map<String, String>>[
      {
        'role': 'system',
        'content': 'You are a code completion engine. Output only the raw '
            'code that continues the given code. No explanations, no code '
            'fences.',
      },
      {
        'role': 'user',
        'content':
            'Continue this code exactly where it stops. Output ONLY the '
            'continuation:\n\n$prefix',
      },
    ];
    final body = isOllama
        ? <String, dynamic>{
            'model': s.aiModel,
            'messages': messages,
            'stream': false,
            'options':
                const <String, dynamic>{'temperature': 0.1, 'num_predict': 48},
          }
        : <String, dynamic>{
            'model': s.aiModel,
            'messages': messages,
            'stream': false,
            'temperature': 0.1,
            'max_tokens': 48,
          };
    final obj = await _postJson(url, body);
    if (isOllama) {
      final msg = obj['message'];
      if (msg is Map) {
        final content = msg['content'];
        if (content is String) return content;
      }
      return '';
    }
    final choices = obj['choices'];
    if (choices is List && choices.isNotEmpty) {
      final first = choices[0];
      if (first is Map) {
        final msg = first['message'];
        if (msg is Map) {
          final content = msg['content'];
          if (content is String) return content;
        }
      }
    }
    return '';
  }

  // ------------------------------------------------------------------ //
  // Small parse helpers
  // ------------------------------------------------------------------ //

  /// Parses one NDJSON / SSE line. Throws [AiException] on backend-reported
  /// errors; returns a done flag for `data: [DONE]` / ollama `done:true`.
  _StreamLine _parseStreamLine(String rawLine, bool isOllama) {
    var line = rawLine;
    if (line.endsWith('\r')) line = line.substring(0, line.length - 1);
    if (line.isEmpty) return const _StreamLine(null, false);
    if (!isOllama) {
      if (!line.startsWith('data:')) return const _StreamLine(null, false);
      var payload = line.substring(5);
      if (payload.startsWith(' ')) payload = payload.substring(1);
      if (payload == '[DONE]') return const _StreamLine(null, true);
      line = payload;
    }
    final obj = _tryJson(line);
    if (obj == null) return const _StreamLine(null, false);
    final err = _errorText(obj);
    if (err != null) throw AiException(err);
    final delta = isOllama ? _ollamaDelta(obj) : _openaiDelta(obj);
    final done = isOllama && obj['done'] == true;
    return _StreamLine(delta, done);
  }

  static String? _ollamaDelta(Map<String, dynamic> obj) {
    final msg = obj['message'];
    if (msg is Map) {
      final content = msg['content'];
      if (content is String) return content;
    }
    return null;
  }

  static String? _openaiDelta(Map<String, dynamic> obj) {
    final choices = obj['choices'];
    if (choices is List && choices.isNotEmpty) {
      final first = choices[0];
      if (first is Map) {
        final delta = first['delta'];
        if (delta is Map) {
          final content = delta['content'];
          if (content is String) return content;
        }
        // Some servers emit a final `message` chunk instead of `delta`.
        final msg = first['message'];
        if (msg is Map) {
          final content = msg['content'];
          if (content is String) return content;
        }
      }
    }
    return null;
  }

  /// Truncates ghost text at the first blank line and at 300 chars.
  static String _clip(String text) {
    var t = text.trim();
    final blank = t.indexOf('\n\n');
    if (blank != -1) t = t.substring(0, blank);
    if (t.length > 300) t = t.substring(0, 300);
    return t;
  }

  /// Reads (best-effort) an error response body.
  static Future<String> _drain(HttpClientResponse res) async {
    try {
      return await res
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      return '';
    }
  }

  /// Body snippet for error messages (max 200 chars).
  static String _snippet(String text) {
    final t = text.trim();
    return t.length > 200 ? t.substring(0, 200) : t;
  }

  static Map<String, dynamic>? _tryJson(String text) {
    if (text.isEmpty) return null;
    try {
      final v = jsonDecode(text);
      return v is Map<String, dynamic> ? v : null;
    } on FormatException {
      return null;
    }
  }

  /// Extracts an error message from a `{"error": ...}` payload, if any.
  static String? _errorText(Map<String, dynamic> obj) {
    final err = obj['error'];
    if (err == null) return null;
    if (err is Map) {
      final msg = err['message'] ?? err['msg'] ?? err['type'] ?? err['code'];
      return msg != null ? msg.toString() : err.toString();
    }
    if (err is String && err.trim().isNotEmpty) return err;
    return err.toString();
  }

  /// Model ids from either `{"models":[{"name":...}]}` (Ollama) or
  /// `{"data":[{"id":...}]}` (OpenAI-compatible).
  static List<String> _extractModelIds(Map<String, dynamic> obj) {
    final out = <String>[];
    final modelsField = obj['models'];
    final dataField = obj['data'];
    if (modelsField is List) _collect(modelsField, out);
    if (dataField is List) _collect(dataField, out);
    return out;
  }

  static void _collect(List list, List<String> out) {
    for (final entry in list) {
      if (entry is String) {
        if (entry.isNotEmpty) out.add(entry);
      } else if (entry is Map) {
        final id = entry['id'] ?? entry['name'] ?? entry['model'];
        if (id is String && id.isNotEmpty) out.add(id);
      }
    }
  }
}

/// One parsed stream line: optional content delta + stream-finished flag.
class _StreamLine {
  final String? delta;
  final bool done;
  const _StreamLine(this.delta, this.done);
}
