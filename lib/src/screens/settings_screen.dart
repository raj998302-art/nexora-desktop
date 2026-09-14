// NEXORA — settings screen: AI Provider / Editor / Appearance cards.
//
// Every mutation goes through SettingsProvider.update((s){...}) so values
// persist immediately. Audit fixes: #11 (the tab-size segmented button always
// starts from tabSizeEffective, never a value outside {2,4,8}) and #12 (one
// single settings.showMinimap flag — no duplicated ui flag).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/settings_provider.dart';
import '../providers/ui_provider.dart';
import '../theme/app_colors.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
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

  @override
  Widget build(BuildContext context) {
    final c = context.watch<UiProvider>().palette;
    final sp = context.watch<SettingsProvider>();
    final s = sp.settings;

    return Container(
      color: c.background,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 780),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Settings',
                      style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('Preferences are saved automatically.',
                      style:
                          TextStyle(color: c.textSecondary, fontSize: 12)),
                  const SizedBox(height: 22),
                  _card(c, _aiSection(context, c, sp, s)),
                  const SizedBox(height: 16),
                  _card(c, _editorSection(context, c, sp, s)),
                  const SizedBox(height: 16),
                  _card(c, _appearanceSection(context, c, sp, s)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- helpers

  Widget _card(AppColors c, Widget child) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: c.panelBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.borderLight),
        ),
        child: child,
      );

  Widget _sectionTitle(AppColors c, String title) => Text(title,
      style: TextStyle(
          color: c.textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3));

  Widget _label(AppColors c, String label) => Text(label,
      style: TextStyle(color: c.textSecondary, fontSize: 11.5));

  InputDecoration _field(AppColors c, {String? label, String? hint}) =>
      InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: c.textSecondary, fontSize: 12),
        hintText: hint,
        hintStyle: TextStyle(
            color: c.textSecondary, fontSize: 12.5, fontFamily: 'monospace'),
        filled: true,
        fillColor: c.background,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: c.borderLight)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: c.accent, width: 1.2)),
      );

  Widget _dropdownBorder(AppColors c, Widget child) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: c.background,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: c.borderLight),
        ),
        child: child,
      );

  Widget _switchRow(AppColors c, String label, bool value,
      ValueChanged<bool> onChanged) {
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: TextStyle(color: c.textPrimary, fontSize: 12.5)),
        ),
        SwitchTheme(
          data: SwitchThemeData(
            trackColor: WidgetStateProperty.resolveWith((states) {
              return states.contains(WidgetState.selected)
                  ? c.accent
                  : c.borderLight;
            }),
            thumbColor: WidgetStateProperty.resolveWith((states) {
              return states.contains(WidgetState.selected)
                  ? c.textOnAccent
                  : c.textSecondary;
            }),
          ),
          child: Switch(value: value, onChanged: onChanged),
        ),
      ],
    );
  }

  ButtonStyle _segmentStyle(AppColors c) => ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? c.accentSoft
              : c.background;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? c.textPrimary
              : c.textSecondary;
        }),
        side: WidgetStatePropertyAll(BorderSide(color: c.borderLight)),
        textStyle:
            const WidgetStatePropertyAll(TextStyle(fontSize: 12.5)),
        padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 18, vertical: 9)),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6))),
      );

  // ------------------------------------------------------------ AI provider

  Widget _aiSection(
      BuildContext context, AppColors c, SettingsProvider sp, AppSettings s) {
    // Models: prefer the discovered list; always include the current value so
    // the Dropdown never gets an orphaned `value`.
    final models = <String>[
      s.aiModel,
      ...sp.availableModels.where((m) => m != s.aiModel),
    ];
    final test = sp.lastTest;
    final double temperature = s.aiTemperature.clamp(0.0, 2.0).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle(c, 'AI Provider'),
        const SizedBox(height: 16),
        Focus(
          onFocusChange: (hasFocus) {
            if (!hasFocus) _commitBaseUrl();
          },
          child: TextField(
            controller: _baseUrl,
            style: TextStyle(
                color: c.textPrimary,
                fontSize: 12.5,
                fontFamily: 'monospace'),
            decoration:
                _field(c, label: 'Base URL', hint: 'http://localhost:11434'),
            onSubmitted: (_) => _commitBaseUrl(),
          ),
        ),
        const SizedBox(height: 14),
        _label(c, 'Model'),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _dropdownBorder(
                c,
                DropdownButton<String>(
                  value: s.aiModel,
                  isExpanded: true,
                  dropdownColor: c.panelBackground,
                  style: TextStyle(color: c.textPrimary, fontSize: 12.5),
                  icon: Icon(Icons.expand_more, size: 18, color: c.textSecondary),
                  underline: const SizedBox.shrink(),
                  borderRadius: BorderRadius.circular(8),
                  items: [
                    for (final m in models)
                      DropdownMenuItem(
                        value: m,
                        child: Text(
                          m,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: c.textPrimary,
                              fontSize: 12.5,
                              fontFamily: 'monospace'),
                        ),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) sp.update((st) => st.aiModel = v);
                  },
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              icon: Icon(Icons.refresh, size: 16, color: c.textSecondary),
              tooltip: 'Refresh model list',
              onPressed: () => sp.refreshModels(),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _label(c, 'API type'),
        const SizedBox(height: 6),
        _dropdownBorder(
          c,
          DropdownButton<String>(
            value:
                ['auto', 'ollama', 'openai'].contains(s.aiApiType) ? s.aiApiType : 'auto',
            isExpanded: true,
            dropdownColor: c.panelBackground,
            style: TextStyle(color: c.textPrimary, fontSize: 12.5),
            icon: Icon(Icons.expand_more, size: 18, color: c.textSecondary),
            underline: const SizedBox.shrink(),
            borderRadius: BorderRadius.circular(8),
            items: const [
              DropdownMenuItem(value: 'auto', child: Text('auto')),
              DropdownMenuItem(value: 'ollama', child: Text('ollama')),
              DropdownMenuItem(value: 'openai', child: Text('openai')),
            ],
            onChanged: (v) {
              if (v != null) sp.update((st) => st.aiApiType = v);
            },
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Text('Temperature',
                style: TextStyle(color: c.textPrimary, fontSize: 12.5)),
            const Spacer(),
            Text(temperature.toStringAsFixed(1),
                style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 12,
                    fontFamily: 'monospace')),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 3,
            activeTrackColor: c.accent,
            inactiveTrackColor: c.borderLight,
            thumbColor: c.accent,
            overlayColor: c.accent.withValues(alpha: 0.15),
            valueIndicatorColor: c.panelBackground,
            valueIndicatorTextStyle:
                TextStyle(color: c.textPrimary, fontSize: 11),
          ),
          child: Slider(
            value: temperature,
            min: 0.0,
            max: 2.0,
            divisions: 40,
            label: 'Temperature: ${temperature.toStringAsFixed(1)}',
            onChanged: (v) => sp.update((st) => st.aiTemperature = v),
          ),
        ),
        const SizedBox(height: 8),
        Focus(
          onFocusChange: (hasFocus) {
            if (!hasFocus) _commitMaxTokens();
          },
          child: TextField(
            controller: _maxTokens,
            keyboardType: TextInputType.number,
            style: TextStyle(
                color: c.textPrimary,
                fontSize: 12.5,
                fontFamily: 'monospace'),
            decoration: _field(c, label: 'Max tokens'),
            onSubmitted: (_) => _commitMaxTokens(),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            FilledButton.icon(
              onPressed: sp.testing ? null : () => sp.testConnection(),
              style: FilledButton.styleFrom(
                backgroundColor: c.accent,
                foregroundColor: c.textOnAccent,
                disabledBackgroundColor: c.accentSoft,
                disabledForegroundColor: c.textSecondary,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 11),
                textStyle: const TextStyle(fontSize: 12.5),
              ),
              icon: sp.testing
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.network_check, size: 16),
              label: Text(sp.testing ? 'Testing…' : 'Test Connection'),
            ),
          ],
        ),
        if (test != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(test.ok ? Icons.check_circle : Icons.error,
                    size: 14, color: test.ok ? c.success : c.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    test.message,
                    style: TextStyle(
                        color: test.ok ? c.success : c.error, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 10),
        _switchRow(
            c, 'Inline AI completions (ghost text)', s.ghostTextEnabled,
            (v) => sp.update((st) => st.ghostTextEnabled = v)),
      ],
    );
  }

  // ----------------------------------------------------------------- editor

  Widget _editorSection(
      BuildContext context, AppColors c, SettingsProvider sp, AppSettings s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle(c, 'Editor'),
        const SizedBox(height: 16),
        _label(c, 'Tab size'),
        const SizedBox(height: 6),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 2, label: Text('2')),
            ButtonSegment(value: 4, label: Text('4')),
            ButtonSegment(value: 8, label: Text('8')),
          ],
          // Audit fix #11: never a selection outside {2,4,8}.
          selected: {sp.tabSizeEffective},
          showSelectedIcon: false,
          style: _segmentStyle(c),
          onSelectionChanged: (sel) =>
              sp.update((st) => st.tabSize = sel.first),
        ),
        const SizedBox(height: 10),
        _switchRow(c, 'Show line numbers', s.showLineNumbers,
            (v) => sp.update((st) => st.showLineNumbers = v)),
        // Audit fix #12: single flag, no second ui.* minimap toggle.
        _switchRow(c, 'Show minimap', s.showMinimap,
            (v) => sp.update((st) => st.showMinimap = v)),
        _switchRow(c, 'Word wrap', s.wordWrap,
            (v) => sp.update((st) => st.wordWrap = v)),
      ],
    );
  }

  // ------------------------------------------------------------- appearance

  Widget _appearanceSection(
      BuildContext context, AppColors c, SettingsProvider sp, AppSettings s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle(c, 'Appearance'),
        const SizedBox(height: 16),
        _label(c, 'Theme'),
        const SizedBox(height: 6),
        SegmentedButton<String>(
          segments: [
            ButtonSegment(
              value: 'dark',
              label: const Text('Dark'),
              icon: Icon(Icons.dark_mode, size: 14, color: c.textSecondary),
            ),
            ButtonSegment(
              value: 'light',
              label: const Text('Light'),
              icon: Icon(Icons.light_mode, size: 14, color: c.textSecondary),
            ),
          ],
          selected: {
            s.themeMode == 'light' ? 'light' : 'dark'
          },
          showSelectedIcon: false,
          style: _segmentStyle(c),
          onSelectionChanged: (sel) {
            final v = sel.first;
            sp.update((st) => st.themeMode = v);
            context.read<UiProvider>().setThemeMode(
                v == 'light' ? ThemeMode.light : ThemeMode.dark);
          },
        ),
      ],
    );
  }
}
