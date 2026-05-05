import 'package:flutter/material.dart';

import '../theme/text_styles.dart';

/// Lightweight overlay shown after a vol-button stop saves a submission.
/// Replaces the dedicated `/success` route on the vol-btn-ctrl flow so the
/// user can keep capturing back-to-back takes without leaving the record
/// screen. Auto-dismisses after [autoDismiss], and any tap on the backdrop
/// also dismisses early.
///
/// Owners are responsible for triggering the success chime and any
/// follow-up state transitions — this widget is purely visual.
class SubmissionSuccessOverlay extends StatelessWidget {
  final int points;
  final int takeNumber;
  final VoidCallback onDismiss;

  const SubmissionSuccessOverlay({
    super.key,
    required this.points,
    required this.takeNumber,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onDismiss,
        child: Container(
          color: Colors.black.withValues(alpha: 0.55),
          alignment: Alignment.center,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: _Card(points: points, takeNumber: takeNumber),
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final int points;
  final int takeNumber;
  const _Card({required this.points, required this.takeNumber});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      decoration: BoxDecoration(
        color: const Color(0xFF111114),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF14C9A8).withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF14C9A8).withValues(alpha: 0.18),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF14C9A8),
            ),
            child: const Icon(Icons.check_rounded, color: Colors.black, size: 32),
          ),
          const SizedBox(height: 18),
          Text(
            'Submission saved',
            style: DCText.inter(
              size: 18,
              weight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: -0.36,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Take $takeNumber · +$points points',
            style: DCText.mono(
              size: 12,
              weight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.65),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'PRESS VOLUME BUTTON\nFOR ANOTHER TAKE',
            textAlign: TextAlign.center,
            style: DCText.mono(
              size: 11,
              weight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.5),
              letterSpacing: 1.6,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
