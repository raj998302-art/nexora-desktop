// NEXORA — AgentRunner (Web Prototype AgentRunner.tsx): the floating
// "Background Task" panel rendered as a Stack overlay by MainLayout
// (bottom 48 / right 24). Entry/exit: 200ms opacity + y 20 + scale 0.98.
//
// The step list advances on a 1500ms Timer like the prototype — this is
// intentionally MOCK content (the prototype is mock too). The timer cancels
// on dispose and resets whenever `agentRunning` flips.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/ui_provider.dart';
import '../theme/app_colors.dart';
import 'nexora_ui.dart';

class AgentRunner extends StatelessWidget {
  const AgentRunner({super.key});

  static const List<String> _steps = [
    'Inspecting project files',
    'Analyzing codebase structure',
    'Executing modifications',
    'Running local verification',
  ];

  @override
  Widget build(BuildContext context) {
    final ui = context.watch<UiProvider>();
    final c = ui.palette;
    final running = ui.agentRunning;

    // Reverse works automatically: the Animated* widgets animate back to the
    // hidden targets while the panel stays mounted. IgnorePointer keeps the
    // invisible panel from swallowing clicks.
    return IgnorePointer(
      ignoring: !running,
      child: AnimatedOpacity(
        duration: NxMotion.medium,
        curve: NxMotion.curve,
        opacity: running ? 1.0 : 0.0,
        child: AnimatedSlide(
          duration: NxMotion.medium,
          curve: NxMotion.curve,
          // ~20px of the ~240px-tall panel.
          offset: running ? Offset.zero : const Offset(0, 0.085),
          child: AnimatedScale(
            duration: NxMotion.medium,
            curve: NxMotion.curve,
            scale: running ? 1.0 : 0.98,
            child: Container(
              width: 320,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: c.background,
                border: Border.all(color: c.border),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ---- Header ------------------------------------------------
                  Container(
                    padding: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: c.border))),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'BACKGROUND TASK',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                  color: c.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Cursor Agent Running',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: c.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        NexoraIconButton(
                          icon: Icons.close,
                          size: 14,
                          tooltip: 'Close',
                          onPressed: () => ui.setAgentRunning(false),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _AgentSteps(
                    running: running,
                    steps: _steps,
                    onCancel: () => ui.setAgentRunning(false),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Steps list + footer. States: pending → running → done; the "running" step
// gets a repeating spin (Loader2), done steps a blue-500 check, pending an
// 8px #333 circle. Advancing every 1500ms while `running`.
// ---------------------------------------------------------------------------

class _AgentSteps extends StatefulWidget {
  final bool running;
  final List<String> steps;
  final VoidCallback onCancel;

  const _AgentSteps({
    required this.running,
    required this.steps,
    required this.onCancel,
  });

  @override
  State<_AgentSteps> createState() => _AgentStepsState();
}

class _AgentStepsState extends State<_AgentSteps> {
  Timer? _timer;
  int _completed = -1; // -1 → all pending; == steps.length → all done.

  @override
  void initState() {
    super.initState();
    if (widget.running) _start();
  }

  @override
  void didUpdateWidget(covariant _AgentSteps oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.running == oldWidget.running) return;
    _timer?.cancel();
    _timer = null;
    _completed = -1;
    if (widget.running) _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      if (!mounted) return;
      setState(() {
        _completed++;
        if (_completed >= widget.steps.length) {
          _timer?.cancel();
          _timer = null;
        }
      });
    });
  }

  /// 0 = pending, 1 = running, 2 = done.
  int _statusOf(int i) {
    if (i < _completed) return 2;
    if (i == _completed) return 1;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<UiProvider>().palette;
    final runningColor =
        c.brightness == Brightness.dark ? c.textOnAccent : c.textPrimary;
    final allDone = _completed >= widget.steps.length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < widget.steps.length; i++)
          _stepRow(c, i, runningColor),
        if (!allDone)
          Container(
            margin: const EdgeInsets.only(top: 16),
            padding: const EdgeInsets.only(top: 12),
            decoration:
                BoxDecoration(border: Border(top: BorderSide(color: c.border))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _CancelButton(onPressed: widget.onCancel),
              ],
            ),
          ),
      ],
    );
  }

  Widget _stepRow(AppColors c, int i, Color runningColor) {
    final status = _statusOf(i);
    final Widget leading;
    switch (status) {
      case 2:
        leading = Icon(Icons.check, size: 14, color: c.blue500);
        break;
      case 1:
        leading = const _Spin();
        break;
      default:
        leading = Icon(Icons.circle, size: 8, color: c.hoverBackground2);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: Center(child: leading),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.steps[i],
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: status == 0
                    ? c.textSecondary
                    : status == 1
                        ? runningColor
                        : c.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Repeating spin for the in-progress step (prototype `animate-spin`).
class _Spin extends StatefulWidget {
  const _Spin();

  @override
  State<_Spin> createState() => _SpinState();
}

class _SpinState extends State<_Spin> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<UiProvider>().palette;
    return RotationTransition(
      turns: _controller,
      child: Icon(Icons.refresh, size: 14, color: c.textPrimary),
    );
  }
}

/// "Cancel Task" ghost button: bg #2a2d2e, border #3c3c3c, rounded 4,
/// 12px #cccccc, hover #333 (prototype px-3 py-1 text-xs rounded).
class _CancelButton extends StatefulWidget {
  final VoidCallback onPressed;
  const _CancelButton({required this.onPressed});

  @override
  State<_CancelButton> createState() => _CancelButtonState();
}

class _CancelButtonState extends State<_CancelButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<UiProvider>().palette;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: NxMotion.fast,
          curve: NxMotion.curve,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: _hover ? c.hoverBackground : c.inputBackground,
            border: Border.all(color: c.borderLight),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            'Cancel Task',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: c.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
