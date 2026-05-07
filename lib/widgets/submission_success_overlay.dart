import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/text_styles.dart';

/// Lightweight overlay shown after a vol-button stop saves a submission.
/// Replaces the dedicated `/success` route on the vol-btn-ctrl flow so the
/// user can keep capturing back-to-back takes without leaving the record
/// screen. Auto-dismisses after a short hold, and any tap on the backdrop
/// also dismisses early.
///
/// The backdrop deliberately does **not** rotate with the device — only
/// the inner card does. Rotating a screen-sized container leaves visible
/// strips of the camera preview at the corners in landscape, since a
/// portrait-shaped rectangle rotated 90° doesn't tile a portrait window.
/// The card is centered so rotating it in place keeps it readable.
///
/// Owners are responsible for triggering the success chime and any
/// follow-up state transitions — this widget is purely visual.
class SubmissionSuccessOverlay extends StatelessWidget {
  final int points;
  final int takeNumber;
  final VoidCallback onDismiss;

  /// Quarter-turn count, matching the record screen's HUD rotation.
  final double turns;

  const SubmissionSuccessOverlay({
    super.key,
    required this.points,
    required this.takeNumber,
    required this.onDismiss,
    this.turns = 0.0,
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
          child: AnimatedRotation(
            turns: turns,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: _Card(points: points, takeNumber: takeNumber),
            ),
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
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      decoration: BoxDecoration(
        color: const Color(0xFF111114),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: const Color(0xFF14C9A8).withValues(alpha: 0.5)),
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
            child:
                const Icon(Icons.check_rounded, color: Colors.black, size: 32),
          ),
          const SizedBox(height: 18),
          Text(
            l10n.submissionSaved,
            style: DCText.inter(
              size: 18,
              weight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: -0.36,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.takePoints(takeNumber, points),
            style: DCText.mono(
              size: 12,
              weight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.65),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 22),
          Text(
            l10n.pressVolumeAnotherTake,
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
