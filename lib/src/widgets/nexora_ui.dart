import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/ui_provider.dart';
import '../theme/app_colors.dart';

// ---------------------------------------------------------------------------
// NEXORA design system — reusable primitives ported from the Web Prototype.
// Every visual token comes from AppColors (the prototype palette). Usage:
//   final c = context.watch<UiProvider>().palette;
//   NexoraPrimaryButton(onPressed: ..., child: ...)
// ---------------------------------------------------------------------------

/// Motion tokens (framer-motion defaults from the prototype).
class NxMotion {
  /// Dropdowns / popups / view transitions: 150ms.
  static const Duration fast = Duration(milliseconds: 150);

  /// AgentRunner panel: 200ms.
  static const Duration medium = Duration(milliseconds: 200);

  /// Composer glow hover: 500ms.
  static const Duration slow = Duration(milliseconds: 500);

  static const Curve curve = Curves.easeOut;
}

/// Text style helpers (Inter sizes from the prototype's Tailwind classes).
class NxText {
  static const String sans = 'Inter';
  static const String mono = 'FiraCode';

  static TextStyle s(BuildContext context,
      {double size = 13,
      int weight = 400,
      Color? color,
      String family = sans,
      double? height,
      double? letterSpacing}) {
    final c = _palette(context);
    return TextStyle(
      fontFamily: family,
      fontSize: size,
      fontWeight: FontWeight.values[((weight ~/ 100)).clamp(0, 8)],
      color: color ?? c.textPrimary,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  static AppColors _palette(BuildContext context) =>
      context.watch<UiProvider>().palette;
}

/// Primary blue button — prototype `bg-blue-600 hover:bg-blue-500 rounded
/// text-white font-medium` (Commit, Send, Save Agent…).
class NexoraPrimaryButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  const NexoraPrimaryButton({
    Key? key,
    required this.onPressed,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    this.radius = 6,
  }) : super(key: key);

  @override
  State<NexoraPrimaryButton> createState() => _NexoraPrimaryButtonState();
}

class _NexoraPrimaryButtonState extends State<NexoraPrimaryButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<UiProvider>().palette;
    final enabled = widget.onPressed != null;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: NxMotion.fast,
          curve: NxMotion.curve,
          padding: widget.padding,
          decoration: BoxDecoration(
            color: !enabled
                ? c.hoverBackground
                : (_hover ? c.blue500 : c.blue600),
            borderRadius: BorderRadius.circular(widget.radius),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: c.blue600.withValues(alpha: 0.35),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: DefaultTextStyle(
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: enabled ? c.textOnAccent : c.textSecondary,
            ),
            child: IconTheme(
              data: IconThemeData(
                  size: 14, color: enabled ? c.textOnAccent : c.textSecondary),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Ghost / hover-only icon button — prototype `text-[#858585]
/// hover:text-white transition-colors` (+ optional hover bg `#333`).
class NexoraIconButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final double size;
  final String? tooltip;
  final bool hoverFill; // adds the #333 rounded hover background
  final Color? color;

  const NexoraIconButton({
    Key? key,
    required this.onPressed,
    required this.icon,
    this.size = 14,
    this.tooltip,
    this.hoverFill = false,
    this.color,
  }) : super(key: key);

  @override
  State<NexoraIconButton> createState() => _NexoraIconButtonState();
}

class _NexoraIconButtonState extends State<NexoraIconButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<UiProvider>().palette;
    final base = widget.color ?? c.textSecondary;
    final w = Tooltip(
      message: widget.tooltip ?? '',
      waitDuration: const Duration(milliseconds: 300),
      child: MouseRegion(
        cursor: widget.onPressed != null
            ? SystemMouseCursors.click
            : MouseCursor.defer,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: NxMotion.fast,
            padding: widget.hoverFill
                ? const EdgeInsets.all(6)
                : const EdgeInsets.all(4),
            decoration: widget.hoverFill && _hover
                ? BoxDecoration(
                    color: c.hoverBackground,
                    borderRadius: BorderRadius.circular(4))
                : null,
            child: Icon(
              widget.icon,
              size: widget.size,
              color: _hover && widget.onPressed != null
                  ? c.textOnAccent.withValues(alpha: 0.95)
                  : base,
            ),
          ),
        ),
      ),
    );
    return widget.tooltip == null || widget.tooltip!.isEmpty
        ? GestureDetector(
            onTap: widget.onPressed,
            child: MouseRegion(
              onEnter: (_) => setState(() => _hover = true),
              onExit: (_) => setState(() => _hover = false),
              child: Icon(
                widget.icon,
                size: widget.size,
                color: _hover && widget.onPressed != null
                    ? c.textOnAccent.withValues(alpha: 0.95)
                    : base,
              ),
            ),
          )
        : w;
  }
}

/// Outlined secondary button — prototype `bg-[#181818] border border-[#3c3c3c]
/// hover:bg-[#333] hover:text-white rounded text-sm` (Connect / Discard /
/// Cancel Task…).
class NexoraGhostButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? foreground;

  const NexoraGhostButton({
    Key? key,
    required this.onPressed,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    this.foreground,
  }) : super(key: key);

  @override
  State<NexoraGhostButton> createState() => _NexoraGhostButtonState();
}

class _NexoraGhostButtonState extends State<NexoraGhostButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<UiProvider>().palette;
    return MouseRegion(
      cursor: widget.onPressed != null
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: NxMotion.fast,
          padding: widget.padding,
          decoration: BoxDecoration(
            color: _hover ? c.hoverBackground : c.background,
            border: Border.all(color: c.borderLight),
            borderRadius: BorderRadius.circular(6),
          ),
          child: DefaultTextStyle(
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: widget.foreground ??
                  (_hover ? c.textOnAccent : c.textPrimary),
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Semantic tinted chip button — prototype `bg-blue-500/10 border
/// border-blue-500/20 text-blue-400` (Agent), red variant for Stop.
class NexoraTintButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final IconData? icon;
  final _Tint tint;

  const NexoraTintButton({
    Key? key,
    required this.onPressed,
    required this.child,
    this.icon,
    this.tint = _Tint.blue,
  }) : super(key: key);

  const NexoraTintButton.agent({Key? key, this.onPressed, required this.child, this.icon})
      : tint = _Tint.blue,
        super(key: key);

  const NexoraTintButton.stop({Key? key, this.onPressed, required this.child, this.icon})
      : tint = _Tint.red,
        super(key: key);

  @override
  State<NexoraTintButton> createState() => _NexoraTintButtonState();
}

enum _Tint { blue, red }

class _NexoraTintButtonState extends State<NexoraTintButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<UiProvider>().palette;
    final isRed = widget.tint == _Tint.red;
    final fg = isRed ? c.red400 : c.blue400;
    final fgHover = isRed ? const Color(0xFFfCA5A5) : const Color(0xFF93C5FD);
    return MouseRegion(
      cursor: widget.onPressed != null
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: NxMotion.fast,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: (isRed ? c.red500 : c.blue500).withValues(alpha: 0.1),
            border: Border.all(
                color: (isRed ? c.red500 : c.blue500).withValues(alpha: 0.2)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon,
                    size: 10, color: _hover ? fgHover : fg),
                const SizedBox(width: 6),
              ],
              DefaultTextStyle(
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: _hover ? fgHover : fg,
                ),
                child: widget.child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Keyboard hint chip — prototype `<kbd>`: `bg-[#1e1e1e]/bg-[#2a2d2e] border
/// border-[#3c3c3c] rounded text-xs font-mono text-[#858585]`.
class NexoraKbd extends StatelessWidget {
  final String label;
  const NexoraKbd(this.label, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final c = context.watch<UiProvider>().palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: c.inputBackground,
        border: Border.all(color: c.borderLight),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontFamily: 'FiraCode', fontSize: 10, color: c.textSecondary),
      ),
    );
  }
}

/// VS Code-style toggle switch — prototype `w-10 h-5 rounded-full bg-blue-600`
/// with a white knob that slides (200ms).
class NexoraToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const NexoraToggle({Key? key, required this.value, required this.onChanged})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final c = context.watch<UiProvider>().palette;
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 40,
        height: 20,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: value ? c.blue600 : c.borderLight,
          borderRadius: BorderRadius.circular(10),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 2,
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Prototype input field: `bg-[#2a2d2e] border border-[#3c3c3c] rounded
/// focus-within:border-blue-500 transition-colors`.
class NexoraField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final int maxLines;
  final int minLines;
  final TextStyle? style;
  final Widget? prefix;
  final Widget? suffix;
  final EdgeInsets padding;

  const NexoraField({
    Key? key,
    required this.controller,
    required this.hint,
    this.autofocus = false,
    this.onSubmitted,
    this.onChanged,
    this.maxLines = 1,
    this.minLines = 1,
    this.style,
    this.prefix,
    this.suffix,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final c = context.watch<UiProvider>().palette;
    return Focus(
      child: Builder(builder: (context) {
        final focused = Focus.of(context).hasFocus;
        return AnimatedContainer(
          duration: NxMotion.fast,
          decoration: BoxDecoration(
            color: c.inputBackground,
            border: Border.all(
                color: focused ? c.blue500 : c.borderLight, width: 1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              if (prefix != null) prefix!,
              Expanded(
                child: TextField(
                  controller: controller,
                  autofocus: autofocus,
                  maxLines: maxLines,
                  minLines: minLines,
                  onSubmitted: onSubmitted,
                  onChanged: onChanged,
                  style: style ??
                      TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          color: c.textOnAccent),
                  cursorColor: c.blue400,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: hint,
                    hintStyle: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: c.textSecondary),
                    border: InputBorder.none,
                    contentPadding: padding,
                  ),
                ),
              ),
              if (suffix != null) suffix!,
            ],
          ),
        );
      }),
    );
  }
}

/// Section header used across left panels — prototype LeftPanel title:
/// 11px uppercase semibold tracking-wide `#cccccc`.
class NexoraPanelHeader extends StatelessWidget {
  final String title;
  final List<Widget>? actions;
  const NexoraPanelHeader({Key? key, required this.title, this.actions})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final c = context.watch<UiProvider>().palette;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                color: c.textPrimary,
              ),
            ),
          ),
          if (actions != null) ...actions!,
        ],
      ),
    );
  }
}

/// Pulsing block cursor (prototype `animate-pulse bg-white w-2 h-4`) used by
/// the terminal prompt and streaming AI replies.
class NexoraBlink extends StatefulWidget {
  final double width;
  final double height;
  const NexoraBlink({Key? key, this.width = 8, this.height = 16})
      : super(key: key);

  @override
  State<NexoraBlink> createState() => _NexoraBlinkState();
}

class _NexoraBlinkState extends State<NexoraBlink>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(
          vsync: this, duration: const Duration(milliseconds: 600))
        ..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<UiProvider>().palette;
    return FadeTransition(
      opacity: Tween<double>(begin: 1.0, end: 0.0).animate(_controller),
      child: Container(
        width: widget.width,
        height: widget.height,
        color: c.textOnAccent,
      ),
    );
  }
}

/// Card container — prototype `bg-[#181818] border border-[#2b2b2b] rounded-lg
/// shadow-sm`.
class NexoraCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  const NexoraCard({
    Key? key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 8,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final c = context.watch<UiProvider>().palette;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: c.activityBar,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}
