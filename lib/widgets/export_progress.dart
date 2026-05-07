import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../theme/text_styles.dart';
import '../theme/tokens.dart';

/// Live message handle held by callers of [withExportProgress]. The dialog
/// rebuilds whenever [update] is called, so callers can drive a "Compressing
/// 3 of 5..." style readout from a tight loop.
class ExportProgressController {
  final ValueNotifier<String> _message;

  ExportProgressController(String initial)
      : _message = ValueNotifier<String>(initial);

  ValueListenable<String> get message => _message;

  void update(String msg) {
    _message.value = msg;
  }

  void dispose() {
    _message.dispose();
  }
}

/// Runs [work] while a non-dismissable progress modal is on screen, then
/// pops the modal and returns whatever [work] produced. Used to keep the UI
/// responsive during the multi-second tar.gz build for one or more
/// recordings.
///
/// The dialog stays up until [work] completes (or throws). We pop with the
/// root navigator so the caller's local Navigator stack stays intact.
Future<T> withExportProgress<T>(
  BuildContext context, {
  required String initialMessage,
  required Future<T> Function(ExportProgressController) work,
}) async {
  final controller = ExportProgressController(initialMessage);

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (_) => PopScope(
      canPop: false,
      child: _ExportProgressDialog(controller: controller),
    ),
  );

  try {
    return await work(controller);
  } finally {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    controller.dispose();
  }
}

class _ExportProgressDialog extends StatelessWidget {
  final ExportProgressController controller;
  const _ExportProgressDialog({required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = context.dc;
    final l10n = context.l10n;
    return Dialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: c.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(strokeWidth: 3, color: c.accent),
            ),
            const SizedBox(height: 18),
            ValueListenableBuilder<String>(
              valueListenable: controller.message,
              builder: (_, msg, __) => Text(
                msg,
                textAlign: TextAlign.center,
                style: DCText.inter(
                    size: 14, weight: FontWeight.w500, color: c.text),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.keepAppOpen,
              textAlign: TextAlign.center,
              style: DCText.mono(
                  size: 10,
                  weight: FontWeight.w500,
                  color: c.textDim,
                  letterSpacing: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
