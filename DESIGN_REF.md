# NEXORA Visual Fidelity Reference (extracted from Web Prototype)

This is the exact design language extracted from the React/Tailwind web
prototype (`NEXORA_Web_Prototype.zip`). Every value below is authoritative.

## Fonts
- Sans: **Inter** (400/500/600/700) — already bundled, family name `'Inter'`
- Mono: **FiraCode** (400) — family name `'FiraCode'`
- Never use 'Segoe UI'/'monospace' anymore.

## Colors (AppColors — already ported 1:1)
| Token | Hex | Usage |
|---|---|---|
| background | #1E1E1E | app/editor background |
| activityBar | #181818 | top bar, activity bar, left panel bg, tabs bar, terminal header |
| panelBackground | #252526 | cards, composer shells, dropdown menus |
| inputBackground | #2A2D2E | inputs, pills, chat composer, git commit box |
| hoverBackground | #333333 | hover fill |
| hoverBackground2 | #3C3C3C | hover fill strong (menu items #37373d vs #3c3c3c note below) |
| selectedBackground | #37373D | active list item / active tab content bg |
| border | #2B2B2B | primary borders |
| borderLight | #3C3C3C | input borders |
| borderFocused | #555555 | composer focus ring |
| textPrimary | #CCCCCC | default text |
| textSecondary | #858585 | muted text |
| textEditor | #D4D4D4 | code |
| accent | #007ACC | status bar bg |
| blue500 | #3B82F6 | active tab top border, indicators, focus borders |
| blue600 | #2563EB | primary buttons (Commit/Send/Save) |
| blue400 | #60A5FA | brand Sparkles, "NEXORA Agent" label, links |
| blueLight | #519ABA | tsx/ts file icons |
| success | #4EC9B0 | components (syntax), VITE |
| green400 | #4ADE80 | terminal user@host, untracked U, web toggle |
| warning | #DCB67A | folder icons |
| yellow400 | #FACC15 | diff tab, lightbulb quick-fix |
| red400 | #F87171 | stop, errors |
| red500 | #EF4444 | stop tint |
| purple400 | #C084FC | Thinking mode |
| iconJson #CBCB41 · iconCss #51B6C8 · iconMd #4EA1DF · iconSvg #B072A9 | file icons
| Syntax: keyword #C586C0 · typeKeyword #569CD6 · string #CE9178 · comment #6A9955 · number #B5CEA8 · functionColor #DCDCAA · attrColor #9CDCFE

## Motion (framer-motion → Flutter)
- View transitions (home/editor/settings): fade opacity 0→1, **150ms**,
  AnimatePresence mode="wait" → `AnimatedSwitcher` 150ms FadeTransition.
- Dropdowns / popups: opacity 0→1 + y 5→0 (open upward from bottom bar:
  y+5), **150ms**.
- AgentRunner panel: opacity + y 20→0 + scale 0.98→1, **200ms**.
- Profile popup (activity bar): opacity + x -10→0, **150ms**.
- `animate-pulse` (status bar Radio, terminal cursor, streaming): opacity
  1↔0 loop **600ms-1s** → `NexoraBlink` widget or pulsing AnimatedOpacity.
- `animate-spin` (Loader2): rotating icon → `RotationTransition` repeating.
- Composer glow hover: opacity 0.3→0.6, **500ms**.
- Hover color transitions: 150ms (AnimatedContainer/MouseRegion).

## Icon mapping (lucide → Material)
- Menu→Icons.menu · Search→Icons.search · Play→Icons.play_arrow ·
  Square→Icons.stop · Layout→Icons.dashboard_outlined (panel layout) ·
  Bell→Icons.notifications_none · Moon/Sun→Icons.dark_mode/light_mode
- Home→Icons.home_outlined · Files→Icons.folder_open ·
  GitBranch→Icons.account_tree · Package→Icons.inventory_2_outlined ·
  Settings→Icons.settings_outlined · Github→Icons.code (no brand icon; use
  generic) · User→Icons.person_outline · LogOut→Icons.logout ·
  CreditCard→Icons.credit_card · Plug→Icons.power (or cable) ·
  Sparkles→Icons.auto_awesome · Zap→Icons.bolt · Brain→Icons.psychology ·
  Globe→Icons.public · Check→Icons.check · ChevronDown/Right→Icons
  .expand_more/chevron_right · X→Icons.close · MoreHorizontal→
  Icons.more_horiz · Maximize2→Icons.open_in_full · History→Icons.history ·
  Lightbulb→Icons.lightbulb (yellow #facc15) · FilePlus→Icons.note_add ·
  FolderPlus→Icons.create_new_folder_outlined · RefreshCcw→Icons.refresh ·
  CopyMinus→Icons.content_copy · FileCode2→Icons.code ·
  FileJson→Icons.data_object · FileText→Icons.description ·
  FileImage→Icons.image_outlined · Send→Icons.send (filled look) ·
  AtSign→Icons.alternate_email · MessageSquare→Icons.chat_bubble_outline ·
  Loader2→spinning Icons.refresh · Circle→Icons.circle (size 8, #333) ·
  Terminal→Icons.terminal · Trash2→Icons.delete_outline ·
  SplitSquareHorizontal→Icons.vertical_split · LayoutPanelTop→
  Icons.web_asset · Radio→Icons.sensors · XCircle→Icons.cancel ·
  AlertTriangle→Icons.warning_amber · Command→Icons.keyboard_command_key
  (fallback: NexoraKbd '⌘')
Icon style: outline variants, sizes per component (most 14, activity bar 22,
file tree 14, status bar 12).

## Shell layout (exact)
- TopBar: **h-9 = 36px**, bg #181818, border-b #2b2b2b, px-3 (12px).
  Left: menu icon 14 + menus File Edit Selection View Go Run Terminal Help
  (12px, gap 12, #cccccc hover white). Center: search pill max-w-sm
  (384px) bg #2a2d2e border #3c3c3c rounded-md(6) px-3 py-1: Search icon 12
  #858585 + "NEXORA (⌘K)" 12px medium #858585 centered, hover bg #333.
  Right: theme Sun 14, Bell 14 + blue-500 dot (2x2 -top-1 -right-1),
  divider (h-4 w-px #3c3c3c), Agent/Stop tinted button, divider, Layout 14.
  Windows: add min/max/close at far right #858585 hover white, close hover
  red. Whole bar is a window drag region (GestureDetector onPanStart →
  windowManager.startDragging()) EXCEPT interactive children.
- ActivityBar: **w-12 = 48px** bg #181818 border-r #2b2b2b, py-3 (12px),
  gap 16 (gap-4) between icons. Icons 22-24px strokeWidth-equivalent thin.
  Top: Home. divider (w-8 h-px #2b2b2b my-4px). Files, Search, GitBranch,
  Package. Bottom (justify-between pushes down): Github, User, Settings.
  Active: white icon + 2px left inset bar blue-500 (absolute left-0
  top-0 bottom-0). Inactive #858585 hover white. Profile popup: left-14
  (56px) bottom-10 (40px) w-64 (256px) bg #1e1e1e border #3c3c3c rounded-md
  shadow-2xl; header user@nexora.ai white medium + "Pro Plan Active" 12
  #858585; rows CreditCard/Plug/Settings + Sign Out red-400; rows px-4 py-2
  14px hover bg #2a2d2e.
- LeftPanel: **w-64 = 256px** bg #181818 border-r #2b2b2b. Header: px-5
  py-2.5, 11px semibold uppercase #cccccc (EXPLORER / SEARCH / SOURCE
  CONTROL / EXTENSIONS).
- AiChat panel: **w-[350px] = 350px** border-l #2b2b2b bg #181818 shadow-lg.
- TerminalPane: **h-64 = 256px** default, bg #1e1e1e border-t #2b2b2b.
- StatusBar: **h-6 = 24px** bg #007acc text white 11px. Left: GitBranch 12
  "main*" (hover bg white/10) + XCircle 0 + AlertTriangle 0. Right: Radio 12
  pulsing "Port: 5173" + UTF-8 + language + Prettier (all hover white/10,
  px-2 h-full).
- View container: bg #1e1e1e, all transitions 150ms fade.

## Home dashboard
- Centered column, shifted up (mt-[-10vh] ≈ Padding top 8% of height).
- Logo row: Sparkles #60A5FA 32px + "NEXORA" 30px semibold white
  tracking-wide, opacity .9, mb-40px, gap-12px.
- Composer: relative; GLOW: absolute -inset-0.5 gradient blue-500/20 →
  purple-500/20, blur-md, rounded-xl(12), opacity .3 hover .6 (500ms).
  Card: bg #252526 border #3c3c3c rounded-xl shadow-2xl focus border #555.
  textarea: pt-20 px-20 h-96px 16px white, placeholder #858585 ("Tell
  NEXORA what to build... (⌘K)" agent / "Ask a question...").
  Bottom row px-16 pb-12: left = Mode chip (rounded-md 6px px-10 py-6 12px
  medium; Normal: bg #3c3c3c/50 text #cccccc; Agent/Architect: bg
  blue-500/10 border blue-500/30 text blue-400; icon MessageSquare/Zap/Check
  14 + label + ChevronDown 12) + divider w-px h-16px #3c3c3c + Context
  ghost chip (AtSign 14 + "Context" #858585) + Thinking chip (Brain 14,
  purple tint when active: bg purple-500/10 border purple-500/30 text
  purple-400) + Web chip (Globe 14, green tint when active: green-500/10
  border green-500/30 text green-400). Right: kbd chip (⌘ Enter, bg #1e1e1e
  border #3c3c3c rounded mono 12 #858585) + send button p-8px bg blue-600
  rounded-md(6) hover blue-500, Sparkles 16 white.
  Dropdowns open UP (bottom-full mb-2), w-48/w-40 bg #252526 border
  #3c3c3c rounded-lg(8) shadow-xl p-4px; option: px-12 py-8 rounded-md,
  title 14 medium + desc 10px #858585 ml-24px; active: bg blue-500/10 text
  blue-400; hover bg #37373d.
- Shortcuts row mt-32: gap-24 items: icon 16 #858585 + label 14 + kbd chip
  (bg #2a2d2e border #3c3c3c rounded 4 mono 12 #858585): New Project ⌘N,
  Open Workspace ⌘O, Terminal ⌘J, Search Files ⇧⌘F. hover: text white.
- Bottom (absolute bottom-48px, w-full max-w-xl=576px mx-auto, opacity .7
  hover 1): "RECENT WORKSPACES" 10px bold uppercase tracking-widest
  #858585 mb-12 centered + 2-col grid gap-12. Item: p-12 rounded-lg border
  transparent hover #3c3c3c + bg hover #252526; row1: name 14 medium white
  + time 12 #858585 right; row2: path 12 #858585 truncated.

## Code editor
- Tab bar: bg #181818, tabs px-12 py-8 13px border-r #2b2b2b; ACTIVE: bg
  #1e1e1e text white + 2px TOP border blue-500; inactive #858585 hover bg
  #1e1e1e. Left: file type letter chip 11px mono #519aba (diff tab: yellow
  #facc15). Close X 14 appears on hover (opacity 0→100), active tab always
  shows. Dirty: yellow dot instead of X? (prototype uses X only; we keep
  dirty dot for functionality, styled #facc15 6px).
- Breadcrumbs: h-24px px-16 12px #858585, "src › App.tsx" (› separator),
  bg #1e1e1e border-b #2b2b2b.
- Editor surface: mono FiraCode 13px height 1.6, line numbers pr-24 pl-16
  #858585 opacity .5, border-r #2b2b2b mr-16, hover line number → #cccccc.
  Code line hover bg #2a2d2e/50.
- Minimap: w-16 = 64px border-l #2b2b2b/50; top: viewport slider h-32px bg
  #333/30 hover #333/50; bars below opacity .2, 1px tall colored lines
  (purple #c586c0, blue #569cd6, orange #ce9178, teal #4ec9b0) with varied
  widths (24-48px) and indent pl-4..24.
- Diff rows: removed bg red-500/20 text red-300; added bg green-500/20 text
  green-300; ± marker column w-24px centered; Accept (bg blue-600 text
  white px-12 py-4 12px rounded) / Reject (text #cccccc hover bg #3c3c3c) /
  More (…) floating top-right of diff.

## Terminal
- Header: bg #181818 border-b #2b2b2b px-16 11px uppercase tracking-wide.
  Tabs: PROBLEMS (badge bg #3c3c3c rounded-full px-6 white), OUTPUT, DEBUG
  CONSOLE, **TERMINAL** (active: white + border-b-2 blue-500), PORTS;
  #858585 hover white, py-10. Right: shell chip (bg #2a2d2e border #3c3c3c
  rounded-md(6) px-8 py-2 12px lowercase #cccccc + Terminal icon 12) +
  Plus/Split/Trash/Maximize(LayoutPanelTop)/X icons 14 #858585 hover white.
- Body: p-16 FiraCode 13px. Prompt: user@nexora green-400 bold, ':', cwd
  blue-400 bold, '$' white, command white. Output colored (VITE teal
  #4ec9b0, links blue #569cd6 underline). Cursor: pulsing white 8x16 block.
- Input row: colored prompt + FiraCode 13.

## AI chat panel
- Header: p-12 bg #181818 border-b #2b2b2b: Sparkles 16 blue-400 +
  "Composer" 14 semibold #cccccc. Right: model chip (bg #2a2d2e border
  #3c3c3c rounded px-8 py-4 12 #cccccc + model name + ChevronDown 12),
  History 14, Maximize2 14, MoreHorizontal 14 (#858585 hover white).
- Messages: p-16 space-y-24, bg #1e1e1e. USER: "You" 14 semibold #cccccc +
  bubble bg #2a2d2e p-12 rounded-lg(8) border #3c3c3c 14px #cccccc. AI:
  "NEXORA Agent" blue-400 semibold + Sparkles 14 + bubble bg #1e1e1e border
  #3c3c3c; lists with markers, code blocks dark #1e1e1e.
- Composer: p-16. Card bg #2a2d2e border #3c3c3c rounded-xl(12) shadow-lg
  focus border #555; textarea pt-16 px-12 h-80 13px white. Bottom row:
  border-t #3c3c3c/50 pt-4: Mode chip 11px (Agent tinted) + @ AtSign 14 +
  Thinking Brain 12 (purple tint) + Web Globe 14 (green tint) … right: Send
  button p-6 bg blue-600 rounded-md(6) hover blue-500 icon 14 white.
- Context popup opens UP above composer: bg #252526 border #3c3c3c
  rounded-lg shadow-2xl; header "Add Context" 12 semibold #858585; rows:
  icon 14 + title 14 + shortcut desc 11 #555; hover bg #37373d.
- Mode dropdown: w-40, options title 12 + optional desc 10.

## Git panel
- Commit box: bg #2a2d2e border #3c3c3c rounded(6) focus:border blue-500;
  textarea h-64px 13px "Message (⌘Enter to commit)". Commit button: w-full
  mt-8 bg blue-600 hover blue-500 rounded(6) py-4 13px medium white.
- Section header: "CHANGES" 11 semibold + count badge bg #333 rounded-full
  px-6 10px; hover bg #2a2d2e; chevron.
- File row: pl-24 pr-8 py-4 13px hover bg #2a2d2e rounded: name #cccccc +
  dir 11px #858585 + status letter 11 bold blue-400 (U: green-400) + Plus
  icon on hover.

## Search panel
- Search field: bg #2a2d2e border #3c3c3c rounded(6) focus blue-500 with
  ChevronRight 14 leading; toggles: Aa (case), ab (word), .* (regex) as
  small square icon buttons p-2 hover bg #333 rounded 14 #858585 hover
  white; active: blue-500/10 tint + blue-400.
- Replace field ml-16 with Replace icon.
- Results count: "n results in m files" 12 #858585 semibold.

## Settings
- Layout: left nav w-56 (224px) bg #181818 border-r #2b2b2b pt-24 px-12:
  "Settings" 18 semibold white mb-24. Tabs: w-full px-12 py-8 rounded-md
  14 gap-12: active bg #37373d text white icon blue-400; else #cccccc hover
  bg #2a2d2e. Tabs: Monitor General, Palette Appearance, Cpu AI & Models,
  Key API Keys, Github Integrations, Keyboard Shortcuts, Blocks Extensions,
  Shield Privacy.
- Content: p-40 max-w-2xl (576px) mx-auto space-y-40: h3 20px medium white
  + desc 12 #858585. Toggle rows: label white medium + desc 12 #858585,
  border-b #2b2b2b py-8, NexoraToggle. Selects: bg #2a2d2e border #3c3c3c
  rounded p-8 14. API key inputs: bg #1e1e1e mono. Tab content switches
  with fade+y 150ms.
- Integration card: bg #2a2d2e border #3c3c3c rounded-lg p-16: icon 24 +
  title white medium + desc 12 + Connect ghost button.

## AgentRunner (floating panel)
- fixed bottom-48px right-24 w-80 (320px) bg #1e1e1e border #2b2b2b
  rounded-lg(8) shadow-2xl p-16 z-50. Entry: opacity+y20+scale .98 200ms.
- Header: "BACKGROUND TASK" 10 bold uppercase #858585 + "Cursor Agent
  Running" 14 medium #cccccc + X 14. Steps: Check 14 blue-500 (done),
  spinning Loader (running), Circle 14 #333 (pending); text 13 (pending
  #858585 / running white / done #cccccc). Footer: "Cancel Task" ghost
  (bg #2a2d2e border #3c3c3c rounded 12 #cccccc).
- Steps advance every 1.5s. Mock content is FINE (matches prototype).

## Explorer
- Header row: px-16 py-8 border-b #2b2b2b bg #181818: "NEXORA" 11 bold
  uppercase #cccccc + icons: note_add 14, create_new_folder_outlined 14,
  refresh 13, content_copy 14 (#858585 hover white, gap-8).
- Folder row: px-16 py-4 13px hover bg #2a2d2e: chevron 14 #858585 +
  FolderOpen/Folder 14 #dcb67a + name #cccccc. Children: border-l #2b2b2b
  ml-24. File row: icon 14 colored by ext + name 13 #cccccc; ACTIVE: bg
  #37373d text white, name in icon color.

## Status bar extras
- Keep our real: branch (GitBranch 12 "main*" — append * when dirty),
  Ln/Col, Spaces, language — styled as prototype items (white 11px, px-8
  h-full hover white/10). Radio pulsing "Port: 5173" (mock), UTF-8,
  language name, "Prettier" (mock).
