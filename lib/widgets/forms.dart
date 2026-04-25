import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../theme/text_styles.dart';

class DCSegmented<T> extends StatelessWidget {
  final List<T> values;
  final List<String> labels;
  final T selected;
  final ValueChanged<T> onChanged;

  const DCSegmented({
    super.key,
    required this.values,
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dc;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(values.length, (i) {
          final isActive = values[i] == selected;
          return Padding(
            padding: EdgeInsets.only(right: i == values.length - 1 ? 0 : 2),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(values[i]),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isActive ? c.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                  boxShadow: isActive
                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 2, offset: const Offset(0, 1))]
                      : null,
                ),
                child: Text(
                  labels[i],
                  style: DCText.inter(
                    size: 12,
                    weight: FontWeight.w500,
                    color: isActive ? c.text : c.textDim,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class DCToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const DCToggle({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = context.dc;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 42,
        height: 26,
        decoration: BoxDecoration(
          color: value ? c.accent : c.borderStrong,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              left: value ? 19 : 3,
              top: 3,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 3, offset: const Offset(0, 1))],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DCInputField extends StatelessWidget {
  final TextEditingController? controller;
  final String? hint;
  final TextInputType? keyboardType;
  final int? maxLength;
  final bool mono;
  final String? prefix;

  const DCInputField({
    super.key,
    this.controller,
    this.hint,
    this.keyboardType,
    this.maxLength,
    this.mono = false,
    this.prefix,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dc;
    final style = mono
        ? DCText.mono(size: 16, weight: FontWeight.w500, color: c.text, letterSpacing: 0.3)
        : DCText.inter(size: 16, weight: FontWeight.w500, color: c.text);
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          if (prefix != null) ...[
            Text(prefix!, style: style.copyWith(color: c.textDim)),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              maxLength: maxLength,
              style: style,
              cursorColor: c.accent,
              decoration: InputDecoration(
                isDense: true,
                hintText: hint,
                hintStyle: style.copyWith(color: c.textFaint),
                border: InputBorder.none,
                counterText: '',
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
