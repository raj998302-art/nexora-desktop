# NEXORA — AI-Native Coding Environment

A **Cursor / Codex-style AI IDE for Windows**, built entirely in native Flutter.
No WebViews — every pixel (explorer, editor, terminal, git, chat) is a real
Flutter widget wired to real OS processes: a live file system, a live `git`
CLI, live shell sessions, and a streaming LLM backend of your choice.

![NEXORA](https://img.shields.io/badge/platform-windows%20%7C%20linux%20%7C%20macos-blueviolet)
![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)

---

## Features

### Editor
- Real code editor with **syntax highlighting** for 16+ languages (regex
  tokenizer, zero dependencies)
- Line numbers with current-line highlight, breadcrumbs, minimap
- Smart **Tab** / **Enter**: Tab accepts inline AI completion or indents;
  Enter auto-indents (brace-aware); `Ctrl+/` toggles line comments
- Dirty-state tracking with safe close prompts

### AI (bring your own model server)
- **Chat panel** with streaming responses, persisted multi-session history
- **Agent mode**: the model proposes full-file writes in fenced
  `nexora-write` blocks → you get an **Accept / Reject diff review** (LCS
  line diff) before anything touches disk
- **Ghost text tab-completion** (fill-in-the-middle) — debounced, 1.5 s
  budget, fails silently
- **`Ctrl+L`** attaches the current editor selection to the chat as context
- **AI commit messages** — one click drafts a conventional-commit line from
  the staged diff
- **Project rules**: drop instructions in `.nexora/rules.md` — they are
  injected into every system prompt (like `.cursorrules`)
- Works with **Ollama** (`/api/chat`) and any **OpenAI-compatible** server
  (`/v1/chat/completions`, `/v1/completions` with suffix) — LM Studio,
  llama.cpp, vLLM, etc.

### Workspace
- Explorer tree with create / rename / delete (deleting a folder closes
  **all** of its open tabs), context menus, recent folders
- Full-text **search** with plain / regex / case-sensitive modes, grouped
  results, click-to-jump
- **Terminal**: real `cmd.exe` / `bash` processes, multiple sessions, stderr
  coloring
- **Run active file** (`F5`): maps `dart` / `python` / `node` / `go` / `rs` /
  `c` / `cpp` / `java` / `sh` / `html` to run commands in a fresh terminal

### Git
- Status, staged/unstaged sections, diffs with syntax-colored line states
- Stage / unstage / discard (with confirm), commit, log
- **Push / pull / fetch** with progress feedback
- Branch + ahead/behind in the status bar

### Shell niceties
- **Command palette** (`Ctrl+Shift+P` or `Ctrl+K`) — fuzzy, keyboard-driven
- Global shortcuts: `Ctrl+S` save · `Ctrl+Shift+S` save all · `Ctrl+O` open
  folder · `Ctrl+B` sidebar · `Ctrl+J` AI panel · ``Ctrl+` `` terminal ·
  `Ctrl+Shift+K` new terminal · `Ctrl+W` close tab · `Ctrl+N` new file
- **Dark & light themes** — every color flows from one palette (no hardcoded
  whites that vanish in light mode)
- Resizable panels — the dividers actually resize things
- Window-close guard: unsaved changes prompt before exit

## Getting started

### Prerequisites
- Flutter SDK (stable)
- `git` on PATH
- An AI backend, e.g. [Ollama](https://ollama.com):
  ```bash
  ollama pull qwen2.5-coder:7b   # default model
  ollama serve
  ```

### Run locally
```bash
flutter pub get
flutter run -d windows        # or -d linux / -d macos
```

### Build a release binary
```bash
flutter build windows --release
# binary: build/windows/x64/runner/Release/nexora.exe
```

### Configure the AI
Settings (gear in the activity bar → *AI Provider*):
- **Base URL** — e.g. `http://localhost:11434` (Ollama) or
  `http://localhost:1234/v1` (LM Studio)
- **Model** — pick from the dropdown after pressing refresh
- **API type** — `auto` probes both protocols
- *Test connection* verifies reachability **and** that the model exists

## Keyboard reference

| Keys | Action |
| --- | --- |
| `Ctrl+Shift+P` / `Ctrl+K` | Command palette |
| `Ctrl+S` / `Ctrl+Shift+S` | Save / save all |
| `Ctrl+O` | Open folder |
| `Ctrl+N` / `Ctrl+W` | New file / close tab |
| `Ctrl+L` | Attach selection to AI chat |
| `Tab` | Accept ghost-text completion / indent |
| `Ctrl+/` | Toggle line comment |
| `F5` | Run active file |
| `Ctrl+B` / `Ctrl+J` | Toggle sidebar / AI panel |
| `` Ctrl+` `` / `Ctrl+Shift+K` | Toggle terminal / new terminal |
| `Ctrl+Shift+E` / `F` / `G` | Explorer / search / git panel |

## Project rules

Create `.nexora/rules.md` in your workspace root:

```markdown
- Always use riverpod-style providers
- Prefer const constructors
- Never edit generated files
```

## CI

GitHub Actions (`.github/workflows/windows.yml`) builds a Windows release on
every push to `main`, runs `flutter analyze` + `flutter test`, and uploads a
**zipped portable release** artifact (`NEXORA-Windows-Portable`).

## Architecture

```
lib/
  main.dart                  # provider graph, cross-provider wiring, window close guard
  src/
    models/models.dart       # FileNode, EditorTab, ChatMessage/Session, PendingEdit, diffs…
    theme/app_colors.dart    # dark + light palettes (single source of color truth)
    services/
      ai_service.dart        # streaming chat (Ollama NDJSON + OpenAI SSE), FIM, testConnection
      fs_service.dart        # tree build, CRUD, search — throws real errors
      git_service.dart       # status/diff/stage/commit/push/pull/fetch/log + diff parser
      settings_service.dart  # JSON persistence under ~/.nexora/
      highlighter.dart       # regex syntax highlighter
    providers/               # ui, settings, workspace, editor, chat, terminal, git, completion
    screens/                 # main_layout (shortcuts + close guard), home, editor workspace, settings
    panels/                  # explorer, search, git
    editor/code_editor.dart  # EditableText subclass w/ highlight, ghost text, gutter, minimap
    chat/                    # ai_chat panel + diff review dialog (accept/reject agent writes)
    terminal/terminal_pane.dart
    widgets/                 # top bar, activity bar, status bar, command palette
```

State management: `provider` (ChangeNotifier). Zero HTTP/widget dependencies
beyond `provider` and `window_manager` — networking is `dart:io HttpClient`.

## License

MIT — see your fork's LICENSE or add one before distributing.
