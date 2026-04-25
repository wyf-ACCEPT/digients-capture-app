import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/tokens.dart';
import '../../theme/text_styles.dart';
import '../../widgets/buttons.dart';

class SuccessScreen extends StatefulWidget {
  final int points;
  const SuccessScreen({super.key, this.points = 0});

  @override
  State<SuccessScreen> createState() => _SuccessScreenState();
}

class _SuccessScreenState extends State<SuccessScreen> with TickerProviderStateMixin {
  late final AnimationController _checkCtl;
  Timer? _copyTimer;
  int _copyIndex = 0;
  static const _copy = [
    'Data is uploading and will be under review.',
    'Please keep internet connection.',
    'Points will be credited within approximately 48 hours.',
  ];

  @override
  void initState() {
    super.initState();
    _checkCtl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))..forward();
    _copyTimer = Timer.periodic(const Duration(milliseconds: 2400), (_) {
      if (!mounted) return;
      setState(() => _copyIndex = (_copyIndex + 1) % _copy.length);
    });
  }

  @override
  void dispose() {
    _checkCtl.dispose();
    _copyTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dc;
    return Scaffold(
      backgroundColor: c.bg,
      body: Stack(
        children: [
          const Positioned.fill(child: _Confetti()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ScaleTransition(
                    scale: CurvedAnimation(parent: _checkCtl, curve: Curves.elasticOut),
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
                      child: const Icon(Icons.check, color: Colors.white, size: 60),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Submitted!',
                    style: DCText.inter(size: 32, weight: FontWeight.w700, color: c.text, letterSpacing: -0.96),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 72,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 550),
                      child: Padding(
                        key: ValueKey(_copyIndex),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          _copy[_copyIndex],
                          textAlign: TextAlign.center,
                          style: DCText.inter(size: 15, weight: FontWeight.w500, color: c.textDim, height: 1.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (widget.points > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: c.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bolt, size: 16, color: c.accent),
                          const SizedBox(width: 4),
                          Text('+${widget.points}',
                              style: DCText.mono(size: 16, weight: FontWeight.w600, color: c.accent)),
                          const SizedBox(width: 8),
                          Text('pending review',
                              style: DCText.inter(size: 13, weight: FontWeight.w500, color: c.textDim)),
                        ],
                      ),
                    ),
                  const SizedBox(height: 32),
                  DCButton(
                    label: 'Go To Submissions',
                    trailingIcon: Icons.chevron_right,
                    onPressed: () => context.go('/submissions'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Confetti extends StatefulWidget {
  const _Confetti();

  @override
  State<_Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<_Confetti> with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;
  late final List<_Particle> _particles;
  static const _colors = [
    Color(0xFF14C9A8),
    Color(0xFFFFD60A),
    Color(0xFF45E0BA),
    Color(0xFFFAFAF7),
  ];

  @override
  void initState() {
    super.initState();
    final rng = Random();
    _particles = List.generate(26, (i) {
      return _Particle(
        x: rng.nextDouble(),
        size: 4 + rng.nextDouble() * 6,
        color: _colors[i % _colors.length],
        delay: rng.nextDouble() * 0.4,
        duration: 0.6 + rng.nextDouble() * 0.4,
      );
    });
    _ctl = AnimationController(vsync: this, duration: const Duration(milliseconds: 3500))..forward();
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
      builder: (_, __) => CustomPaint(painter: _ConfettiPainter(_particles, _ctl.value)),
    );
  }
}

class _Particle {
  final double x;
  final double size;
  final Color color;
  final double delay;
  final double duration;
  _Particle({required this.x, required this.size, required this.color, required this.delay, required this.duration});
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;
  final double t;
  _ConfettiPainter(this.particles, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final localT = ((t - p.delay) / p.duration).clamp(0.0, 1.0);
      if (localT <= 0) continue;
      final y = size.height - localT * (size.height + 100);
      final opacity = 1.0 - localT;
      final paint = Paint()..color = p.color.withValues(alpha: opacity);
      final rect = Rect.fromCenter(center: Offset(p.x * size.width, y), width: p.size, height: p.size);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(2)), paint);
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
