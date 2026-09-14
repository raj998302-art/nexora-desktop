// NEXORA — settings screen, restyled to the Web Prototype (DESIGN_REF
// "Settings"): 224px left navigation rail + animated tabbed content
// (fade + slide, 150ms) switching between General / Appearance / AI & Models
// / API Keys / Integrations / Shortcuts / Extensions / Privacy.
//
// REAL mutations (SettingsProvider.update → persisted immediately):
//   aiBaseUrl, aiModel, aiApiType, aiTemperature, aiMaxTokens,
//   ghostTextEnabled, showLineNumbers, showMinimap, wordWrap, tabSize,
//   themeMode (synced to UiProvider), plus Test Connection with the
//   discovered-models dropdown + refresh.
// Mock-only controls mirror the prototype: Auto Save, Format on Save,
// default terminal shell, provider API keys, GitHub Connect.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/settings_provider.dart';
import '../providers/ui_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/nexora_ui.dart';

/// Prototype "white" text: white on the dark palette, dark ink on light.
Color _brightColor(AppColors c) =>
    c.brightness == Brightness.dark ? c.textOnAccent : c.textPrimary;

class _SettingsTab {
  final String label;
  final IconData icon;
  const _SettingsTab(this.label, this.icon);
}

const List<_SettingsTab> _tabs = [
  _SettingsTab('General', Icons.monitor_outlined),
  _SettingsTab('Appearance', Icons.palette_outlined),
  _SettingsTab('AI & Models', Icons.memory),
  _SettingsTab('API Keys', Icons.vpn_key_outlined),
  _SettingsTab('Integrations', Icons.code),
  _SettingsTab('Shortcuts', Icons.keyboard_outlined),
  _SettingsTab('Extensions', Icons.widgets_outlined),
  _SettingsTab('Privacy', Icons.shield_outlined),
];

/// Our REAL global key bindings (main_layout.dart) shown on Shortcuts.
const List<(String, String)> _shortcutRows = [
  ('Save File', 'Ctrl+S'),
  ('Save All Files', 'Ctrl+Shift+S'),
  ('Command Palette', 'Ctrl+K'),
  ('Attach Selection to Chat', 'Ctrl+L'),
  ('Run Active File', 'F5'),
  ('Toggle Terminal', 'Ctrl+`'),
  ('New Terminal', 'Ctrl+Shift+K'),
  ('Toggle Sidebar', 'Ctrl+B'),
  ('Toggle AI Chat Panel', 'Ctrl+J'),
  ('Open Folder', 'Ctrl+O'),
  ('New File', 'Ctrl+N'),
  ('Search Files', 'Ctrl+Shift+F'),
];

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _tab = 0;

  // Mock-only local state (prototype mock controls).
  bool _autoSave = true;
  bool _formatOnSave = true;
  String _shell = 'bash';

  late final TextEditingController _baseUrl;
  late final TextEditingController _maxTokens;

  @override
  void initState() {
    super.initState();
    final s = context.read<SettingsProvider>().settings;
    _baseUrl = TextEditingController(text: s.aiBaseUrl);
    _maxTokens = TextEditingController(text: s.aiMaxTokens.toString());
  }

  @override
  void dispose() {
    _baseUrl.dispose();
    _maxTokens.dispose();
    super.dispose();
  }

  void _commitBaseUrl() {
    final v = _baseUrl.text.trim();
    final sp = context.read<SettingsProvider>();
    if (sp.settings.aiBaseUrl != v) {
      sp.update((s) => s.aiBaseUrl = v);
    }
  }

  void _commitMaxTokens() {
    var v = int.tryParse(_maxTokens.text.trim()) ?? 4096;
    if (v < 64) v = 64;
    if (v > 32768) v = 32768;
    if (_maxTokens.text.trim() != v.toString()) {
      _maxTokens.text = v.toString();
    }
    final sp = context.read<SettingsProvider>();
    if (sp.settings.aiMaxTokens != v) {
      sp.update((s) => s.aiMaxTokens = v);
    }
  }

  void _setTheme(String mode) {
    context.read<SettingsProvider>().update((s) => s.themeMode = mode);
    context
        .read<UiProvider>()
        .setThemeMode(mode == 'light' ? ThemeMode.light : ThemeMode.dark);
  }

  // --------------------------------------------------------------- layout

  @override
  Widget build(BuildContext context) {
    final c = context.watch<UiProvider>().palette;
    final sp = context.watch<SettingsProvider>();
    final s = sp.settings;

    return Container(
      color: c.background,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _navRail(c),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 576),
                  child: AnimatedSwitcher(
                    duration: NxMotion.fast,
                    switchInCurve: NxMotion.curve,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.02),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: KeyedSubtree(
                      key: ValueKey<int>(_tab),
                      child: _tabContent(c, sp, s),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navRail(AppColors c) {
    return Container(
      width: 224,
      decoration: BoxDecoration(
        color: c.activityBar,
        border: Border(right: BorderSide(color: c.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 24, 12, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 24),
              child: Text(
                'Settings',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: _brightColor(c),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  for (var i = 0; i < _tabs.length; i++)
                    _NavTabItem(
                      tab: _tabs[i],
                      active: i == _tab,
                      onTap: () => setState(() => _tab = i),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabContent(AppColors c, SettingsProvider sp, AppSettings s) {
    switch (_tab) {
      case 0:
        return _generalTab(c, sp, s);
      case 1:
        return _appearanceTab(c, sp, s);
      case 2:
        return _aiTab(c, sp, s);
      case 3:
        return _apiKeysTab(c);
      case 4:
        return _integrationsTab(c);
      case 5:
        return _shortcutsTab(c);
      case 6:
        return _extensionsTab(c);
      default:
        return _privacyTab(c);
    }
  }

  // -------------------------------------------------------------- helpers

  Widget _sectionHeader(AppColors c, String title, String desc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: _brightColor(c),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          desc,
          style: TextStyle(
              fontFamily: 'Inter', fontSize: 12, color: c.textSecondary),
        ),
      ],
    );
  }

  Widget _fieldLabel(AppColors c, String label) {
    return Text(
      label,
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: c.textSecondary,
      ),
    );
  }

  /// Prototype toggle row: label 14 white medium + desc 12, border-b, py-8.
  Widget _toggleRow(AppColors c, String label, String desc, bool value,
      ValueChanged<bool> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration:
          BoxDecoration(border: Border(bottom: BorderSide(color: c.border))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _brightColor(c),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: c.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          NexoraToggle(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  /// Prototype select: bg #2a2d2e, border #3c3c3c, rounded, p-8, 14px.
  Widget _select(
    AppColors c, {
    required String value,
    required List<String> items,
    required ValueChanged<String> onChanged,
    bool mono = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: c.inputBackground,
        border: Border.all(color: c.borderLight),
        borderRadius: BorderRadius.circular(6),
      ),
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        borderRadius: BorderRadius.circular(8),
        dropdownColor: c.panelBackground,
        style: TextStyle(
            fontFamily: 'Inter', fontSize: 13, color: c.textPrimary),
        icon: Icon(Icons.expand_more, size: 14, color: c.textSecondary),
        underline: const SizedBox.shrink(),
        items: [
          for (final it in items)
            DropdownMenuItem(
              value: it,
              child: Text(
                it,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: mono ? 'FiraCode' : 'Inter',
                  fontSize: 13,
                  color: c.textPrimary,
                ),
              ),
            ),
        ],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }

  Widget _comingSoonPanel(AppColors c, IconData icon, String title,
      String desc) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: c.panelBackground,
        border: Border.all(color: c.borderLight),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, size: 28, color: c.textSecondary),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: _brightColor(c),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            desc,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: 'Inter', fontSize: 12.5, color: c.textSecondary),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- GENERAL

  Widget _generalTab(AppColors c, SettingsProvider sp, AppSettings s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionHeader(
            c, 'General', 'Configure basic workspace behavior.'),
        const SizedBox(height: 28),
        // Mock (prototype — exact order + copy: Auto Save, Format on Save, Shell):
        _toggleRow(c, 'Auto Save', 'Automatically save files after a delay.',
            _autoSave, (v) => setState(() => _autoSave = v)),
        _toggleRow(c, 'Format on Save',
            'Run Prettier or the default formatter when saving.', _formatOnSave,
            (v) => setState(() => _formatOnSave = v)),
        const SizedBox(height: 32),
        _fieldLabel(c, 'Default Terminal Shell'),
        const SizedBox(height: 8),
        _select(c,
            value: _shell,
            items: const ['bash', 'zsh', 'powershell'],
            onChanged: (v) => setState(() => _shell = v)),
        // Real editor controls (beyond the prototype — functional extras):
        const SizedBox(height: 32),
        _toggleRow(c, 'Show Line Numbers',
            'Display line numbers in the editor gutter.', s.showLineNumbers,
            (v) => sp.update((st) => st.showLineNumbers = v)),
        _toggleRow(c, 'Word Wrap', 'Wrap long lines to fit the editor width.',
            s.wordWrap, (v) => sp.update((st) => st.wordWrap = v)),
        _tabSizeRow(c, sp),
      ],
    );
  }

  /// Real tab size — 2/4/8 segments (never an orphan selection).
  Widget _tabSizeRow(AppColors c, SettingsProvider sp) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration:
          BoxDecoration(border: Border(bottom: BorderSide(color: c.border))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tab Size',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _brightColor(c),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Spaces per indentation level.',
                  style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: c.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Row(
            children: [
              _SegmentButton(
                  label: '2',
                  active: sp.tabSizeEffective == 2,
                  onTap: () => sp.update((st) => st.tabSize = 2)),
              const SizedBox(width: 6),
              _SegmentButton(
                  label: '4',
                  active: sp.tabSizeEffective == 4,
                  onTap: () => sp.update((st) => st.tabSize = 4)),
              const SizedBox(width: 6),
              _SegmentButton(
                  label: '8',
                  active: sp.tabSizeEffective == 8,
                  onTap: () => sp.update((st) => st.tabSize = 8)),
            ],
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------- APPEARANCE

  Widget _appearanceTab(AppColors c, SettingsProvider sp, AppSettings s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionHeader(c, 'Appearance', 'Customize how NEXORA looks.'),
        const SizedBox(height: 28),
        _fieldLabel(c, 'Theme'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _ThemeOption(
                icon: Icons.dark_mode,
                label: 'Dark',
                active: s.themeMode != 'light',
                onTap: () => _setTheme('dark'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ThemeOption(
                icon: Icons.light_mode,
                label: 'Light',
                active: s.themeMode == 'light',
                onTap: () => _setTheme('light'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        _toggleRow(c, 'Show Minimap',
            'Display the code minimap next to the editor.', s.showMinimap,
            (v) => sp.update((st) => st.showMinimap = v)),
      ],
    );
  }

  // ---------------------------------------------------------- AI & MODELS

  Widget _aiTab(AppColors c, SettingsProvider sp, AppSettings s) {
    // Prefer the discovered list; always include the current value so the
    // Dropdown never gets an orphaned `value`.
    final models = <String>[
      s.aiModel,
      ...sp.availableModels.where((m) => m != s.aiModel),
    ];
    final test = sp.lastTest;
    final double temperature = s.aiTemperature.clamp(0.0, 2.0).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionHeader(c, 'AI & Models',
            'Configure default models for Chat, Agent, and Autocomplete.'),
        const SizedBox(height: 28),
        _fieldLabel(c, 'Chat Model'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _select(c,
                  value: s.aiModel,
                  items: models,
                  mono: true,
                  onChanged: (v) => sp.update((st) => st.aiModel = v)),
            ),
            const SizedBox(width: 6),
            NexoraIconButton(
              onPressed: () => sp.refreshModels(),
              icon: Icons.refresh,
              size: 14,
              tooltip: 'Refresh model list',
              hoverFill: true,
            ),
          ],
        ),
        const SizedBox(height: 20),
        _fieldLabel(c, 'Base URL'),
        const SizedBox(height: 8),
        Focus(
          onFocusChange: (hasFocus) {
            if (!hasFocus) _commitBaseUrl();
          },
          child: NexoraField(
            controller: _baseUrl,
            hint: 'http://localhost:11434',
            style: TextStyle(
                fontFamily: 'FiraCode',
                fontSize: 13,
                color: c.textPrimary),
            onSubmitted: (_) => _commitBaseUrl(),
          ),
        ),
        const SizedBox(height: 20),
        _fieldLabel(c, 'API Type'),
        const SizedBox(height: 8),
        _select(c,
            value: ['auto', 'ollama', 'openai'].contains(s.aiApiType)
                ? s.aiApiType
                : 'auto',
            items: const ['auto', 'ollama', 'openai'],
            onChanged: (v) => sp.update((st) => st.aiApiType = v)),
        const SizedBox(height: 20),
        Row(
          children: [
            Text(
              'Temperature',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: _brightColor(c),
              ),
            ),
            const Spacer(),
            Text(
              temperature.toStringAsFixed(1),
              style: TextStyle(
                  fontFamily: 'FiraCode',
                  fontSize: 12,
                  color: c.textSecondary),
            ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 3,
            activeTrackColor: c.blue600,
            inactiveTrackColor: c.borderLight,
            thumbColor: c.blue500,
            overlayColor: c.blue500.withValues(alpha: 0.15),
          ),
          child: Slider(
            value: temperature,
            min: 0.0,
            max: 2.0,
            divisions: 40,
            onChanged: (v) => sp.update((st) => st.aiTemperature = v),
          ),
        ),
        const SizedBox(height: 12),
        _fieldLabel(c, 'Max Tokens'),
        const SizedBox(height: 8),
        Focus(
          onFocusChange: (hasFocus) {
            if (!hasFocus) _commitMaxTokens();
          },
          child: NexoraField(
            controller: _maxTokens,
            hint: '4096',
            style: TextStyle(
                fontFamily: 'FiraCode',
                fontSize: 13,
                color: c.textPrimary),
            onSubmitted: (_) => _commitMaxTokens(),
          ),
        ),
        const SizedBox(height: 28),
        _toggleRow(
            c,
            'Enable Inline Autocomplete',
            'Show ghost text suggestions as you type (Copilot-style).',
            s.ghostTextEnabled,
            (v) => sp.update((st) => st.ghostTextEnabled = v)),
        const SizedBox(height: 28),
        Align(
          alignment: Alignment.centerLeft,
          child: NexoraPrimaryButton(
            onPressed: sp.testing ? null : () => sp.testConnection(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (sp.testing)
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: c.textOnAccent),
                  )
                else
                  const Icon(Icons.network_check),
                const SizedBox(width: 6),
                Text(sp.testing ? 'Testing…' : 'Test Connection'),
              ],
            ),
          ),
        ),
        if (test != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  test.ok ? Icons.check_circle : Icons.cancel,
                  size: 14,
                  color: test.ok ? c.green400 : c.red400,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    test.message,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: test.ok ? c.green400 : c.red400,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ------------------------------------------------------------- API KEYS

  Widget _apiKeysTab(AppColors c) {
    const keys = [
      ('OpenAI API Key', 'sk-...'),
      ('Anthropic API Key', 'sk-ant-...'),
      ('Google Gemini API Key', 'AIza...'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionHeader(c, 'API Keys',
            'Manage keys for external AI providers. Keys stay on this machine.'),
        const SizedBox(height: 28),
        for (final k in keys) ...[
          _fieldLabel(c, k.$1),
          const SizedBox(height: 8),
          _apiKeyField(c, k.$2),
          const SizedBox(height: 20),
        ],
      ],
    );
  }

  /// Mock password-style field — prototype: bg #1e1e1e, mono font.
  Widget _apiKeyField(AppColors c, String hint) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: c.background,
        border: Border.all(color: c.borderLight),
        borderRadius: BorderRadius.circular(6),
      ),
      child: TextField(
        style: TextStyle(
            fontFamily: 'FiraCode', fontSize: 13, color: c.textPrimary),
        cursorColor: c.blue400,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
              fontFamily: 'FiraCode',
              fontSize: 13,
              color: c.textSecondary),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  // ---------------------------------------------------------- INTEGRATIONS

  Widget _integrationsTab(AppColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionHeader(
            c, 'Integrations', 'Connect NEXORA to external services.'),
        const SizedBox(height: 28),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: c.inputBackground,
            border: Border.all(color: c.borderLight),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.code, size: 24, color: _brightColor(c)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GitHub Connect',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _brightColor(c),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Sync repositories, issues and pull requests.',
                      style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: c.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              NexoraGhostButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content:
                          Text('GitHub integration is coming soon.')));
                },
                child: const Text('Connect'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------ SHORTCUTS

  Widget _shortcutsTab(AppColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionHeader(c, 'Shortcuts',
            'Keyboard shortcuts used across the NEXORA editor.'),
        const SizedBox(height: 20),
        for (final r in _shortcutRows)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: c.border))),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    r.$1,
                    style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: c.textPrimary),
                  ),
                ),
                NexoraKbd(r.$2),
              ],
            ),
          ),
      ],
    );
  }

  // ------------------------------------------ EXTENSIONS / PRIVACY (mock)

  Widget _extensionsTab(AppColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionHeader(
            c, 'Extensions', 'Extend NEXORA with languages, themes and tools.'),
        const SizedBox(height: 28),
        _comingSoonPanel(
          c,
          Icons.widgets_outlined,
          'Extensions marketplace',
          'Install extensions for new languages, themes and tools. Coming soon.',
        ),
      ],
    );
  }

  Widget _privacyTab(AppColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionHeader(c, 'Privacy', 'Your code stays local by default.'),
        const SizedBox(height: 28),
        _comingSoonPanel(
          c,
          Icons.shield_outlined,
          'Local-first by design',
          'Chat history, settings and recents are stored on this machine only. '
          'Telemetry controls are coming soon.',
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Left-nav tab — active: #37373d bg, white label, blue-400 icon; 150ms.
// ---------------------------------------------------------------------------

class _NavTabItem extends StatefulWidget {
  final _SettingsTab tab;
  final bool active;
  final VoidCallback onTap;

  const _NavTabItem({
    required this.tab,
    required this.active,
    required this.onTap,
  });

  @override
  State<_NavTabItem> createState() => _NavTabItemState();
}

class _NavTabItemState extends State<_NavTabItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<UiProvider>().palette;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: NxMotion.fast,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: widget.active
                ? c.selectedBackground
                : (_hover ? c.inputBackground : Colors.transparent),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(
                widget.tab.icon,
                size: 16,
                color: widget.active ? c.blue400 : c.textPrimary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AnimatedDefaultTextStyle(
                  duration: NxMotion.fast,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: (widget.active || _hover)
                        ? _brightColor(c)
                        : c.textPrimary,
                  ),
                  child: Text(widget.tab.label),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Small segmented choice button (Tab Size 2/4/8).
// ---------------------------------------------------------------------------

class _SegmentButton extends StatefulWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _SegmentButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  State<_SegmentButton> createState() => _SegmentButtonState();
}

class _SegmentButtonState extends State<_SegmentButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<UiProvider>().palette;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: NxMotion.fast,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: widget.active
                ? c.selectedBackground
                : c.inputBackground,
            border: Border.all(
                color: widget.active ? c.blue500 : c.borderLight),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: (widget.active || _hover)
                  ? _brightColor(c)
                  : c.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Theme choice button (Dark / Light) — active: blue-500/10 tint + blue-400.
// ---------------------------------------------------------------------------

class _ThemeOption extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  State<_ThemeOption> createState() => _ThemeOptionState();
}

class _ThemeOptionState extends State<_ThemeOption> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<UiProvider>().palette;
    final fg = widget.active
        ? c.blue400
        : (_hover ? _brightColor(c) : c.textPrimary);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: NxMotion.fast,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: widget.active
                ? c.blue500.withValues(alpha: 0.1)
                : c.inputBackground,
            border: Border.all(
                color: widget.active
                    ? c.blue500.withValues(alpha: 0.3)
                    : c.borderLight),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, size: 14, color: fg),
              const SizedBox(width: 8),
              AnimatedDefaultTextStyle(
                duration: NxMotion.fast,
                style: TextStyle(
                    fontFamily: 'Inter', fontSize: 13, color: fg),
                child: Text(widget.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
