import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../theme/text_styles.dart';

class DCCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color? color;
  final Border? border;
  final VoidCallback? onTap;

  const DCCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.radius = 14,
    this.color,
    this.border,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dc;
    final widget = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? c.surface,
        borderRadius: BorderRadius.circular(radius),
        border: border ?? Border.all(color: c.border),
      ),
      child: child,
    );
    if (onTap == null) return widget;
    return GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: widget);
  }
}

class DCKVTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  const DCKVTile({super.key, required this.label, required this.value, this.icon});

  @override
  Widget build(BuildContext context) {
    final c = context.dc;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 12, color: c.textDim),
                const SizedBox(width: 4),
              ],
              Text(
                label.toUpperCase(),
                style: DCText.eyebrow(color: c.textDim, size: 10),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: DCText.inter(size: 14, weight: FontWeight.w500, color: c.text),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class DCImagePlaceholder extends StatelessWidget {
  final double? height;
  final String caption;
  final double radius;
  final List<Widget> overlays;
  const DCImagePlaceholder({
    super.key,
    this.height,
    this.caption = 'IMAGE',
    this.radius = 12,
    this.overlays = const [],
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dc;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Stack(
        children: [
          Container(
            height: height,
            width: double.infinity,
            color: c.surface2,
            child: CustomPaint(
              painter: _StripePainter(
                color: c.text.withValues(alpha: 0.04),
              ),
              child: Center(
                child: Text(
                  caption.toUpperCase(),
                  style: DCText.mono(
                    size: 10,
                    weight: FontWeight.w500,
                    color: c.textFaint,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
          ),
          ...overlays,
        ],
      ),
    );
  }
}

class _StripePainter extends CustomPainter {
  final Color color;
  _StripePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = 12;
    const spacing = 24.0;
    final diagonal = size.width + size.height;
    for (double offset = -diagonal; offset < diagonal; offset += spacing) {
      canvas.drawLine(
        Offset(offset, 0),
        Offset(offset + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_StripePainter oldDelegate) => oldDelegate.color != color;
}
