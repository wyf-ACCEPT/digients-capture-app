import 'package:flutter_test/flutter_test.dart';

import 'package:digients_app/main.dart';
import 'package:digients_app/services/auth_service.dart';
import 'package:digients_app/services/compression_queue.dart';
import 'package:digients_app/services/recording_manager.dart';
import 'package:digients_app/services/token_storage.dart';
import 'package:digients_app/services/upload_service.dart';
import 'package:digients_app/state/auth_controller.dart';
import 'package:digients_app/state/hand_presence_settings_controller.dart';
import 'package:digients_app/state/locale_controller.dart';
import 'package:digients_app/state/theme_controller.dart';
import 'package:digients_app/state/upload_controller.dart';

void main() {
  testWidgets('App constructs without throwing', (tester) async {
    final theme = ThemeController();
    final auth = AuthController(
      service: MockAuthService(),
      tokens: TokenStorage(),
    );
    final handPresence = HandPresenceSettingsController();
    final recordings = RecordingManager();
    final compressionQueue = CompressionQueue(recordings);
    final locale = LocaleController();
    final upload = UploadController(
      service: MockUploadService(),
      compression: compressionQueue,
      auth: auth,
    );
    await tester.pumpWidget(DigientsApp(
      themeController: theme,
      localeController: locale,
      authController: auth,
      handPresenceSettings: handPresence,
      compressionQueue: compressionQueue,
      uploadController: upload,
    ));
  });
}
