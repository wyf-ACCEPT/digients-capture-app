import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../theme/text_styles.dart';

class DCButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final bool primary;
  final Color? danger;
  final bool fullWidth;

  const DCButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.leadingIcon,
    this.trailingIcon,
    this.primary = true,
    this.danger,
    this.fullWidth = true,
  });

  factory DCButton.secondary({
    Key? key,
    required String label,
    required VoidCallback? onPressed,
    IconData? leadingIcon,
    IconData? trailingIcon,
    Color? danger,
    bool fullWidth = true,
  }) =>
      DCButton(
        key: key,
        label: label,
        onPressed: onPressed,
        leadingIcon: leadingIcon,
        trailingIcon: trailingIcon,
        primary: false,
        danger: danger,
        fullWidth: fullWidth,
      );

  @override
  Widget build(BuildContext context) {
    final c = context.dc;
    final bg = primary ? c.accent : c.surface;
    final fg = primary
        ? Colors.white
        : (danger ?? c.text);
    final border = primary
        ? null
        : Border.all(color: c.borderStrong);

    final children = <Widget>[
      if (leadingIcon != null) ...[
        Icon(leadingIcon, size: 18, color: fg),
        const SizedBox(width: 8),
      ],
      Text(label, style: DCText.inter(size: 17, weight: FontWeight.w600, color: fg)),
      if (trailingIcon != null) ...[
        const SizedBox(width: 8),
        Icon(trailingIcon, size: 18, color: fg),
      ],
    ];

    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: onPressed == null ? bg.withValues(alpha: 0.5) : bg,
        borderRadius: BorderRadius.circular(999),
        border: border,
        boxShadow: primary && onPressed != null
            ? [BoxShadow(color: c.accentGlow, blurRadius: 24, offset: const Offset(0, 8))]
            : null,
      ),
      child: Row(
        mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: children,
      ),
    );

    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: fullWidth ? SizedBox(width: double.infinity, child: content) : content,
      ),
    );
  }
}

class DCIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;
  final Color? bg;
  final double size;
  final String? semanticLabel;

  const DCIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.color,
    this.bg,
    this.size = 38,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dc;
    return Semantics(
      button: true,
      label: semanticLabel ?? '',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: bg ?? c.surface2,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: color ?? c.text),
        ),
      ),
    );
  }
}
