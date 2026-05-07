import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../l10n/l10n.dart';
import '../theme/tokens.dart';
import '../theme/text_styles.dart';

class DCChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback? onTap;

  const DCChip(
      {super.key, required this.label, this.active = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.dc;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? c.text : c.surface2,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? c.text : c.border),
        ),
        child: Text(
          label,
          style: DCText.inter(
            size: 12,
            weight: FontWeight.w500,
            color: active ? c.bg : c.textDim,
          ),
        ),
      ),
    );
  }
}

class DCPointsPill extends StatelessWidget {
  final int points;
  final bool small;
  const DCPointsPill({super.key, required this.points, this.small = false});

  @override
  Widget build(BuildContext context) {
    final c = context.dc;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 8 : 10,
        vertical: small ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: c.accent,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt, size: small ? 10 : 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            '+$points',
            style: DCText.mono(
              size: small ? 11 : 12,
              weight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

enum SubmissionStatus { ondevice, uploading, review, approved, rejected }

extension SubmissionStatusLabel on SubmissionStatus {
  String label(AppLocalizations l10n) {
    switch (this) {
      case SubmissionStatus.ondevice:
        return l10n.statusOnDevice;
      case SubmissionStatus.uploading:
        return l10n.statusUploading;
      case SubmissionStatus.review:
        return l10n.statusInReview;
      case SubmissionStatus.approved:
        return l10n.statusApproved;
      case SubmissionStatus.rejected:
        return l10n.statusRejected;
    }
  }
}

class DCStatusBadge extends StatelessWidget {
  final SubmissionStatus status;
  const DCStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final c = context.dc;
    final l10n = context.l10n;
    Color fg;
    Color bg;
    switch (status) {
      case SubmissionStatus.ondevice:
        fg = c.textDim;
        bg = c.surface2;
        break;
      case SubmissionStatus.uploading:
        fg = c.accent;
        bg = c.accentTint;
        break;
      case SubmissionStatus.review:
        fg = c.warning;
        bg = c.warning.withValues(alpha: 0.12);
        break;
      case SubmissionStatus.approved:
        fg = c.success;
        bg = c.success.withValues(alpha: 0.12);
        break;
      case SubmissionStatus.rejected:
        fg = c.danger;
        bg = c.danger.withValues(alpha: 0.12);
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            status.label(l10n).toUpperCase(),
            style: DCText.mono(
                size: 10,
                weight: FontWeight.w500,
                color: fg,
                letterSpacing: 1.4),
          ),
        ],
      ),
    );
  }
}
