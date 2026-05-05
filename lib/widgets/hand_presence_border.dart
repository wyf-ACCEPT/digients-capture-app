import 'package:flutter/material.dart';

import '../services/hand_presence/hand_presence_state.dart';
import '../theme/tokens.dart';

/// Full-bleed colored border that signals hand-presence state during
/// recording (§5 of MOBILE_APP_SPECS_V2_HAND_PRESENCE_FEEDBACK.md).
///
/// Drawn behind the recording HUD but in front of the camera preview, with
/// stroke + outer glow only — no opaque fill. Pulses on warning/none states
/// to mirror the cadence of the recording pill's red dot.
class HandPresenceBorder extends StatefulWidget {
  final HandPresenceState state;

  const HandPresenceBorder({super.key, required this.state});

  @override
  State<HandPresenceBorder> createState() => _HandPresenceBorderState();
}

class _HandPresenceBorderState extends State<HandPresenceBorder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtl;

  @override
  void initState() {
    super.initState();
    _pulseCtl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtl.dispose();
    super.dispose();
  }

  Color _colorFor(HandPresenceState s, DCColors c) {
    return switch (s) {
      HandPresenceState.both => c.accent,
      HandPresenceState.leftOnly => c.warning,
      HandPresenceState.rightOnly => c.warning,
      HandPresenceState.none => c.danger,
    };
  }

  bool _shouldPulse(HandPresenceState s) =>
      s != HandPresenceState.both;

  @override
  Widget build(BuildContext context) {
    final disableAnim = MediaQuery.of(context).disableAnimations;
    final padding = MediaQuery.of(context).viewPadding;
    final color = _colorFor(widget.state, context.dc);

    return IgnorePointer(
      child: TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: color),
        duration:
            disableAnim ? Duration.zero : const Duration(milliseconds: 240),
        builder: (context, animatedColor, _) {
          final tweened = animatedColor ?? color;
          return AnimatedBuilder(
            animation: _pulseCtl,
            builder: (context, _) {
              final glowOpacity = _shouldPulse(widget.state) && !disableAnim
                  ? 0.25 + (0.45 - 0.25) * _pulseCtl.value
                  : 0.35;
              return CustomPaint(
                size: Size.infinite,
                painter: _BorderPainter(
                  color: tweened,
                  glowOpacity: glowOpacity,
                  safeArea: padding,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _BorderPainter extends CustomPainter {
  final Color color;
  final double glowOpacity;
  final EdgeInsets safeArea;

  static const double _insetFromSafeArea = 6.0;
  static const double _radius = 24.0;
  static const double _strokeWidth = 3.0;
  static const double _glowBlur = 16.0;

  _BorderPainter({
    required this.color,
    required this.glowOpacity,
    required this.safeArea,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTRB(
      safeArea.left + _insetFromSafeArea,
      safeArea.top + _insetFromSafeArea,
      size.width - safeArea.right - _insetFromSafeArea,
      size.height - safeArea.bottom - _insetFromSafeArea,
    );
    if (rect.width <= 0 || rect.height <= 0) return;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(_radius));

    final glowPaint = Paint()
      ..color = color.withValues(alpha: glowOpacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, _glowBlur);
    canvas.drawRRect(rrect, glowPaint);

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth;
    canvas.drawRRect(rrect, strokePaint);
  }

  @override
  bool shouldRepaint(_BorderPainter old) =>
      old.color != color ||
      old.glowOpacity != glowOpacity ||
      old.safeArea != safeArea;
}
