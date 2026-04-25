import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/tokens.dart';
import '../../theme/text_styles.dart';
import '../../widgets/cards.dart';
import '../../fixtures/data.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.dc;
    final p = fixtureProfile;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [c.accent, c.accentStrong],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    _initials(p.displayName),
                    style: DCText.inter(size: 22, weight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.displayName,
                      style: DCText.inter(size: 22, weight: FontWeight.w700, color: c.text, letterSpacing: -0.44),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      p.uid,
                      style: DCText.mono(size: 11, weight: FontWeight.w500, color: c.textDim),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => context.push('/me/settings'),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: c.border),
                  ),
                  child: Icon(Icons.settings, color: c.text, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _StatTile(label: 'BALANCE', value: _format(p.balancePoints), suffix: 'pts')),
              const SizedBox(width: 10),
              Expanded(child: _StatTile(label: 'PENDING', value: _format(p.pendingPoints), suffix: 'pts', color: c.warning)),
            ],
          ),
          const SizedBox(height: 12),
          DCCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Expanded(child: _MiniStat(label: 'HOURS', value: p.hoursLogged.toStringAsFixed(1))),
                Container(width: 1, height: 32, color: c.border),
                Expanded(child: _MiniStat(label: 'SUBMITTED', value: '${p.submittedCount}')),
                Container(width: 1, height: 32, color: c.border),
                Expanded(child: _MiniStat(label: 'APPROVAL', value: '${(p.approvalRate * 100).round()}%')),
              ],
            ),
          ),
          const SizedBox(height: 16),
          DCCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CAPABILITY', style: DCText.eyebrow(color: c.textDim, size: 10)),
                const SizedBox(height: 12),
                AspectRatio(
                  aspectRatio: 1,
                  child: CustomPaint(
                    painter: _RadarPainter(
                      values: p.capabilities,
                      labels: const ['Household', 'Industrial', 'Sports', 'Variety', 'Speed', 'Approval'],
                      colors: c,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          DCCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                  child: Row(
                    children: [
                      Text('LEADERBOARD · GLOBAL', style: DCText.eyebrow(color: c.textDim, size: 10)),
                      const Spacer(),
                      Text('Rank #27', style: DCText.mono(size: 11, weight: FontWeight.w600, color: c.text)),
                    ],
                  ),
                ),
                ...List.generate(fixtureLeaderboard.length, (i) {
                  final row = fixtureLeaderboard[i];
                  final isLast = i == fixtureLeaderboard.length - 1;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: row.isYou ? c.accentTint : null,
                      border: Border(bottom: BorderSide(color: isLast ? Colors.transparent : c.border)),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 36,
                          child: Text(
                            row.rank <= 3 ? '0${row.rank}' : '#${row.rank}',
                            style: DCText.mono(
                              size: 13,
                              weight: FontWeight.w600,
                              color: row.rank <= 3 ? c.accent : c.text,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            row.name,
                            style: DCText.inter(
                              size: 14,
                              weight: row.isYou ? FontWeight.w600 : FontWeight.w500,
                              color: c.text,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 60,
                          child: Text(
                            '${row.hours.toStringAsFixed(1)}h',
                            textAlign: TextAlign.right,
                            style: DCText.mono(size: 11, weight: FontWeight.w500, color: c.textDim),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 70,
                          child: Text(
                            _format(row.points),
                            textAlign: TextAlign.right,
                            style: DCText.mono(size: 12, weight: FontWeight.w600, color: c.accent),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.split(' ');
    return parts.map((p) => p.isNotEmpty ? p[0] : '').take(2).join().toUpperCase();
  }

  String _format(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String suffix;
  final Color? color;
  const _StatTile({required this.label, required this.value, required this.suffix, this.color});

  @override
  Widget build(BuildContext context) {
    final c = context.dc;
    return DCCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: DCText.eyebrow(color: c.textDim, size: 10)),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: DCText.mono(size: 26, weight: FontWeight.w700, color: color ?? c.text, letterSpacing: -0.52)),
              const SizedBox(width: 4),
              Text(suffix, style: DCText.mono(size: 11, weight: FontWeight.w500, color: c.textDim)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final c = context.dc;
    return Column(
      children: [
        Text(value, style: DCText.mono(size: 18, weight: FontWeight.w700, color: c.text)),
        const SizedBox(height: 4),
        Text(label, style: DCText.eyebrow(color: c.textDim, size: 9)),
      ],
    );
  }
}

class _RadarPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final DCColors colors;
  _RadarPainter({required this.values, required this.labels, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 30;
    final n = values.length;

    final ringPaint = Paint()
      ..color = colors.borderStrong.withValues(alpha: 0.5)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    for (int r = 1; r <= 4; r++) {
      final ratio = r / 4;
      final path = Path();
      for (int i = 0; i < n; i++) {
        final angle = -pi / 2 + i * 2 * pi / n;
        final p = Offset(center.dx + cos(angle) * radius * ratio, center.dy + sin(angle) * radius * ratio);
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();
      canvas.drawPath(path, ringPaint);
    }

    final axisPaint = Paint()..color = colors.border..strokeWidth = 1;
    for (int i = 0; i < n; i++) {
      final angle = -pi / 2 + i * 2 * pi / n;
      canvas.drawLine(center, Offset(center.dx + cos(angle) * radius, center.dy + sin(angle) * radius), axisPaint);
    }

    final valuePath = Path();
    for (int i = 0; i < n; i++) {
      final angle = -pi / 2 + i * 2 * pi / n;
      final p = Offset(center.dx + cos(angle) * radius * values[i], center.dy + sin(angle) * radius * values[i]);
      if (i == 0) {
        valuePath.moveTo(p.dx, p.dy);
      } else {
        valuePath.lineTo(p.dx, p.dy);
      }
    }
    valuePath.close();
    canvas.drawPath(valuePath, Paint()..color = colors.accent.withValues(alpha: 0.2));
    canvas.drawPath(valuePath, Paint()
      ..color = colors.accent
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke);

    for (int i = 0; i < n; i++) {
      final angle = -pi / 2 + i * 2 * pi / n;
      final p = Offset(center.dx + cos(angle) * radius * values[i], center.dy + sin(angle) * radius * values[i]);
      canvas.drawCircle(p, 3, Paint()..color = colors.accent);
    }

    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    for (int i = 0; i < labels.length; i++) {
      final angle = -pi / 2 + i * 2 * pi / n;
      final lp = Offset(center.dx + cos(angle) * (radius + 16), center.dy + sin(angle) * (radius + 16));
      textPainter.text = TextSpan(
        text: labels[i],
        style: DCText.mono(size: 11, weight: FontWeight.w500, color: colors.text),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(lp.dx - textPainter.width / 2, lp.dy - textPainter.height / 2));
    }
  }

  @override
  bool shouldRepaint(_RadarPainter old) => false;
}
