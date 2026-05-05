import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/text_styles.dart';

/// Onboarding overlay shown over the live camera preview before recording
/// starts. Replaces the standalone mount instructions screen so the user
/// can already see (dimmed) what the camera sees while reading the
/// orient-and-mount cues, and a 6-second countdown removes ambiguity
/// about when recording will actually begin.
///
/// Calls [onComplete] when the second illustration finishes (or the user
/// taps SKIP). The owner is then expected to start recording.
class MountInstructionsOverlay extends StatefulWidget {
  final VoidCallback onComplete;

  /// Quarter-turn count, in the same convention used by the rest of the
  /// record screen's HUD: portrait = 0, landscape CW = -0.25, etc.
  /// Drives an [AnimatedRotation] around the centered illustration +
  /// caption so they stay readable when the user has the phone in
  /// landscape (e.g. mid-mount). The SKIP and countdown banner are
  /// deliberately not rotated — they're only relevant while the user is
  /// still holding the phone before donning the headband.
  final double turns;

  const MountInstructionsOverlay({
    super.key,
    required this.onComplete,
    this.turns = 0.0,
  });

  @override
  State<MountInstructionsOverlay> createState() =>
      _MountInstructionsOverlayState();
}

class _MountInstructionsOverlayState extends State<MountInstructionsOverlay> {
  // Each step lasts ~3 s total: 350 ms fade-in, 2200 ms hold, 450 ms fade-out.
  static const _fadeIn = Duration(milliseconds: 350);
  static const _hold = Duration(milliseconds: 2200);
  static const _fadeOut = Duration(milliseconds: 450);

  int _step = 0;
  bool _visible = false;
  Timer? _inTimer;
  Timer? _outTimer;
  Timer? _nextTimer;

  // 6-second countdown to align with the 2-step animation (~6.16 s total).
  static const _countdownStart = 6;
  int _secondsLeft = _countdownStart;
  Timer? _secondTicker;

  @override
  void initState() {
    super.initState();
    _runStep();
    _secondTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_secondsLeft > 1) {
        setState(() => _secondsLeft -= 1);
      }
    });
  }

  void _runStep() {
    _inTimer?.cancel();
    _outTimer?.cancel();
    _nextTimer?.cancel();
    setState(() => _visible = false);
    _inTimer = Timer(const Duration(milliseconds: 80), () {
      if (!mounted) return;
      setState(() => _visible = true);
    });
    _outTimer = Timer(const Duration(milliseconds: 80) + _fadeIn + _hold, () {
      if (!mounted) return;
      setState(() => _visible = false);
    });
    _nextTimer = Timer(
      const Duration(milliseconds: 80) + _fadeIn + _hold + _fadeOut,
      () {
        if (!mounted) return;
        if (_step < 1) {
          setState(() => _step += 1);
          _runStep();
        } else {
          widget.onComplete();
        }
      },
    );
  }

  @override
  void dispose() {
    _inTimer?.cancel();
    _outTimer?.cancel();
    _nextTimer?.cancel();
    _secondTicker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final caption = _step == 0
        ? 'Place your phone horizontally with arrow pointing upward'
        : 'Mount on headband for data collection';

    return Stack(
      children: [
        // Semi-transparent scrim over the live preview. ~55 % black keeps the
        // preview visible enough for the user to spot framing problems
        // (something blocking the lens, the strap dangling) while keeping
        // illustrations and caption readable.
        Positioned.fill(
          child: IgnorePointer(
            child: Container(color: Colors.black.withValues(alpha: 0.55)),
          ),
        ),
        SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: 12,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF14C9A8).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFF14C9A8).withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Color(0xFF14C9A8),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'INSTRUCTIONS END IN ${_secondsLeft}s',
                          style: DCText.mono(
                            size: 11,
                            weight: FontWeight.w600,
                            color: const Color(0xFF14C9A8),
                            letterSpacing: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // SKIP sits in the upper-LEFT so it doesn't overlap the
              // record screen's top-right close (X) button, which is
              // visible behind this overlay.
              Positioned(
                top: 12,
                left: 16,
                child: GestureDetector(
                  onTap: widget.onComplete,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                    ),
                    child: Text(
                      'SKIP',
                      style: DCText.mono(size: 11, weight: FontWeight.w500, color: Colors.white70, letterSpacing: 1.4),
                    ),
                  ),
                ),
              ),
              Center(
                child: AnimatedRotation(
                  turns: widget.turns,
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutCubic,
                  child: AnimatedSlide(
                    duration: _fadeIn,
                    curve: Curves.easeOut,
                    offset: _visible ? Offset.zero : const Offset(0, 0.04),
                    child: AnimatedOpacity(
                      duration: _fadeIn,
                      curve: Curves.easeOut,
                      opacity: _visible ? 1.0 : 0.0,
                      child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            height: 220,
                            width: 280,
                            child: _step == 0
                                ? const _PhoneArrowIllustration()
                                : const _HeadbandIllustration(),
                          ),
                          const SizedBox(height: 36),
                          // Subtle scrim under the caption so it stays
                          // legible even when the preview behind happens
                          // to be bright (e.g. pointed at a window).
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              caption,
                              textAlign: TextAlign.center,
                              style: DCText.inter(
                                size: 22,
                                weight: FontWeight.w600,
                                color: Colors.white,
                                height: 1.35,
                                letterSpacing: -0.44,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                ),
              ),
              Positioned(
                bottom: 36,
                left: 0,
                right: 0,
                child: Center(
                  child: AnimatedRotation(
                    turns: widget.turns,
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutCubic,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(2, (i) {
                        final active = i == _step;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          height: 5,
                          width: active ? 18 : 5,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: active ? 0.95 : 0.25),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PhoneArrowIllustration extends StatefulWidget {
  const _PhoneArrowIllustration();

  @override
  State<_PhoneArrowIllustration> createState() => _PhoneArrowIllustrationState();
}

class _PhoneArrowIllustrationState extends State<_PhoneArrowIllustration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctl,
      builder: (_, __) => CustomPaint(
        painter: _PhoneArrowPainter(arrowOffsetY: _ctl.value * -6),
      ),
    );
  }
}

class _PhoneArrowPainter extends CustomPainter {
  final double arrowOffsetY;
  _PhoneArrowPainter({required this.arrowOffsetY});

  // Maps mockup 280×220 viewBox onto provided canvas size.
  Offset _m(double x, double y, Size size) =>
      Offset(x / 280 * size.width, y / 220 * size.height);
  double _ms(double v, Size size) => v / 280 * size.width;

  @override
  void paint(Canvas canvas, Size size) {
    final accent = const Color(0xFF14C9A8);
    final whiteFaint = Colors.white.withValues(alpha: 0.18);

    final accentStroke = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final whiteStroke = Paint()
      ..color = whiteFaint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Up arrow + chevron above phone (animated float)
    final shaftTop = _m(140, 20 + arrowOffsetY, size);
    final shaftBottom = _m(140, 62 + arrowOffsetY, size);
    canvas.drawLine(shaftTop, shaftBottom, accentStroke);
    final chevron = Path()
      ..moveTo(_m(130, 32 + arrowOffsetY, size).dx, _m(130, 32 + arrowOffsetY, size).dy)
      ..lineTo(shaftTop.dx, shaftTop.dy)
      ..lineTo(_m(150, 32 + arrowOffsetY, size).dx, _m(150, 32 + arrowOffsetY, size).dy);
    canvas.drawPath(chevron, accentStroke);

    // "THIS SIDE UP" label
    final tp = TextPainter(
      text: TextSpan(
        text: 'THIS SIDE UP',
        style: DCText.mono(
          size: _ms(10, size),
          weight: FontWeight.w500,
          color: Colors.white.withValues(alpha: 0.55),
          letterSpacing: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, _m(170, 38, size));

    // Phone in landscape (translate(40, 80), 200×100)
    final phoneOrigin = _m(40, 80, size);
    final phoneRect = Rect.fromLTWH(phoneOrigin.dx, phoneOrigin.dy, _ms(200, size), _ms(100, size));
    final phoneRRect = RRect.fromRectAndRadius(phoneRect, Radius.circular(_ms(14, size)));
    canvas.drawRRect(phoneRRect, Paint()..color = const Color(0xFF1C1C20));
    canvas.drawRRect(phoneRRect, whiteStroke);

    // Inner screen
    final screenRect = Rect.fromLTWH(
      phoneOrigin.dx + _ms(6, size),
      phoneOrigin.dy + _ms(6, size),
      _ms(188, size),
      _ms(88, size),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(screenRect, Radius.circular(_ms(10, size))),
      Paint()..color = const Color(0xFF0A0A0A),
    );

    // Dynamic island (centered along the long edge that faces up)
    final islandRect = Rect.fromLTWH(
      phoneOrigin.dx + _ms(92, size),
      phoneOrigin.dy + _ms(10, size),
      _ms(36, size),
      _ms(9, size),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(islandRect, Radius.circular(_ms(4.5, size))),
      Paint()..color = Colors.black,
    );

    // Rear camera bump on LEFT short edge
    final bumpOrigin = Offset(phoneOrigin.dx + _ms(14, size), phoneOrigin.dy + _ms(30, size));
    final bumpRect = Rect.fromLTWH(bumpOrigin.dx, bumpOrigin.dy, _ms(28, size), _ms(40, size));
    canvas.drawRRect(
      RRect.fromRectAndRadius(bumpRect, Radius.circular(_ms(6, size))),
      Paint()..color = const Color(0xFF0A0A0A),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bumpRect, Radius.circular(_ms(6, size))),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    // Lens 1 (top)
    final lens1Center = Offset(bumpOrigin.dx + _ms(14, size), bumpOrigin.dy + _ms(13, size));
    canvas.drawCircle(lens1Center, _ms(6, size), Paint()..color = const Color(0xFF1C1C20));
    canvas.drawCircle(
      lens1Center,
      _ms(6, size),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
    canvas.drawCircle(lens1Center, _ms(3.5, size), Paint()..color = accent.withValues(alpha: 0.3));

    // Lens 2 (bottom)
    final lens2Center = Offset(bumpOrigin.dx + _ms(14, size), bumpOrigin.dy + _ms(28, size));
    canvas.drawCircle(lens2Center, _ms(4, size), Paint()..color = const Color(0xFF1C1C20));
    canvas.drawCircle(
      lens2Center,
      _ms(4, size),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    // Dashed gravity line at bottom
    final dashPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = 0.5;
    final yLine = _m(20, 195, size).dy;
    final xStart = _m(20, 195, size).dx;
    final xEnd = xStart + _ms(240, size);
    final dash = _ms(3, size);
    final gap = _ms(3, size);
    double x = xStart;
    while (x < xEnd) {
      final next = min(x + dash, xEnd);
      canvas.drawLine(Offset(x, yLine), Offset(next, yLine), dashPaint);
      x = next + gap;
    }
  }

  @override
  bool shouldRepaint(_PhoneArrowPainter old) => old.arrowOffsetY != arrowOffsetY;
}

class _HeadbandIllustration extends StatefulWidget {
  const _HeadbandIllustration();

  @override
  State<_HeadbandIllustration> createState() => _HeadbandIllustrationState();
}

class _HeadbandIllustrationState extends State<_HeadbandIllustration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctl,
      builder: (_, __) => CustomPaint(painter: _HeadbandPainter(blink: 1.0 - 0.7 * _ctl.value)),
    );
  }
}

class _HeadbandPainter extends CustomPainter {
  final double blink;
  _HeadbandPainter({required this.blink});

  Offset _m(double x, double y, Size size) =>
      Offset(x / 280 * size.width, y / 220 * size.height);
  double _ms(double v, Size size) => v / 280 * size.width;

  @override
  void paint(Canvas canvas, Size size) {
    final accent = const Color(0xFF14C9A8);
    final whiteFaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Head silhouette (ellipse cx=140, cy=135, rx=62, ry=74)
    final headRect = Rect.fromCenter(
      center: _m(140, 135, size),
      width: _ms(124, size),
      height: _ms(148, size),
    );
    canvas.drawOval(headRect, Paint()..color = const Color(0xFF1C1C20));
    canvas.drawOval(headRect, whiteFaint);

    // Ear
    final earRect = Rect.fromCenter(
      center: _m(78, 138, size),
      width: _ms(16, size),
      height: _ms(28, size),
    );
    canvas.drawOval(earRect, Paint()..color = const Color(0xFF1C1C20));
    canvas.drawOval(earRect, whiteFaint);

    // Headband strap (curve from 78,110 through 140,85 to 202,110)
    final strapPath = Path()
      ..moveTo(_m(78, 110, size).dx, _m(78, 110, size).dy)
      ..quadraticBezierTo(_m(140, 85, size).dx, _m(140, 85, size).dy, _m(202, 110, size).dx, _m(202, 110, size).dy);
    canvas.drawPath(
      strapPath,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _ms(14, size)
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      strapPath,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.95)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Stitching (subtle inner curve)
    final stitchPath = Path()
      ..moveTo(_m(90, 102, size).dx, _m(90, 102, size).dy)
      ..quadraticBezierTo(_m(140, 81, size).dx, _m(140, 81, size).dy, _m(190, 102, size).dx, _m(190, 102, size).dy);
    final dashPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    final dashedStitch = _dashPath(stitchPath, _ms(3, size), _ms(2, size));
    canvas.drawPath(dashedStitch, dashPaint);

    // Phone mounted on forehead (translate(102, 75), 76×38)
    final phoneOrigin = _m(102, 75, size);
    final phoneRect = Rect.fromLTWH(phoneOrigin.dx, phoneOrigin.dy, _ms(76, size), _ms(38, size));
    canvas.drawRRect(
      RRect.fromRectAndRadius(phoneRect, Radius.circular(_ms(6, size))),
      Paint()..color = const Color(0xFF0A0A0A),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(phoneRect, Radius.circular(_ms(6, size))),
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Inner screen
    final innerRect = Rect.fromLTWH(
      phoneOrigin.dx + _ms(3, size),
      phoneOrigin.dy + _ms(3, size),
      _ms(70, size),
      _ms(32, size),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(innerRect, Radius.circular(_ms(4, size))),
      Paint()..color = const Color(0xFF0D0D10),
    );

    // Camera bump on phone (translate +8, +10): 14×18 rect, then concentric circles
    final bumpOrigin = Offset(phoneOrigin.dx + _ms(8, size), phoneOrigin.dy + _ms(10, size));
    final bumpRect = Rect.fromLTWH(bumpOrigin.dx, bumpOrigin.dy, _ms(14, size), _ms(18, size));
    canvas.drawRRect(
      RRect.fromRectAndRadius(bumpRect, Radius.circular(_ms(3, size))),
      Paint()..color = const Color(0xFF1C1C20),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bumpRect, Radius.circular(_ms(3, size))),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5,
    );
    final lensCenter = Offset(bumpOrigin.dx + _ms(7, size), bumpOrigin.dy + _ms(6, size));
    canvas.drawCircle(lensCenter, _ms(3, size), Paint()..color = const Color(0xFF0A0A0A));
    canvas.drawCircle(
      lensCenter,
      _ms(3, size),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5,
    );
    canvas.drawCircle(lensCenter, _ms(1.5, size), Paint()..color = accent);

    // Recording indicator (blinking)
    final recCenter = Offset(phoneOrigin.dx + _ms(62, size), phoneOrigin.dy + _ms(8, size));
    canvas.drawCircle(recCenter, _ms(2.5, size), Paint()..color = accent.withValues(alpha: blink));

    // Subtle eyes peek
    final eyePaint = Paint()..color = Colors.white.withValues(alpha: 0.08);
    final eye1 = Rect.fromCenter(center: _m(118, 140, size), width: _ms(10, size), height: _ms(6, size));
    final eye2 = Rect.fromCenter(center: _m(162, 140, size), width: _ms(10, size), height: _ms(6, size));
    canvas.drawOval(eye1, eyePaint);
    canvas.drawOval(eye2, eyePaint);
  }

  Path _dashPath(Path source, double dashLen, double gapLen) {
    final dest = Path();
    for (final metric in source.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final next = min(distance + dashLen, metric.length);
        dest.addPath(metric.extractPath(distance, next), Offset.zero);
        distance = next + gapLen;
      }
    }
    return dest;
  }

  @override
  bool shouldRepaint(_HeadbandPainter old) => old.blink != blink;
}
