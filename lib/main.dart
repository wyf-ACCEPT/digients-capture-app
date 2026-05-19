import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'l10n/app_localizations.dart';
import 'router.dart';
import 'services/auth_service.dart';
import 'services/compression_queue.dart';
import 'services/device_id_service.dart';
import 'services/recording_manager.dart';
import 'services/token_storage.dart';
import 'services/upload_service.dart';
import 'state/auth_controller.dart';
import 'state/hand_presence_settings_controller.dart';
import 'state/locale_controller.dart';
import 'state/theme_controller.dart';
import 'state/upload_controller.dart';
import 'theme/app_theme.dart';
import 'theme/tokens.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final themeController = ThemeController();
  await themeController.load();

  final localeController = LocaleController();
  await localeController.load();

  final handPresenceSettings = HandPresenceSettingsController();
  await handPresenceSettings.load();

  // Default to the AWS Lambda prod backend behind api.digients.tech. The
  // legacy Cloudflare Workers deployment (digients-api.digients.workers.dev)
  // is in retirement (handoff 6e15 §5.4 / Phase 6) and its D1 no longer
  // tracks new invite codes minted in Aurora, so falling back to it silently
  // bites local builds. Override the base for mock / local dev:
  //   flutter run --dart-define=AUTH_BACKEND=mock
  //   flutter run --dart-define=API_BASE=http://localhost:8787
  const backend = String.fromEnvironment('AUTH_BACKEND', defaultValue: 'http');
  const apiBase = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'https://api.digients.tech',
  );
  final AuthService authService = backend == 'mock'
      ? MockAuthService()
      : HttpAuthService(baseUrl: apiBase);

  final authController = AuthController(
    service: authService,
    tokens: TokenStorage(),
  );
  // Restore session from a stored refresh token if one exists. Blocks first
  // frame so the router never flashes the auth screen for a logged-in user.
  await authController.bootstrap();

  // Background compressor for recordings. Compression now runs on demand
  // when the user presses "Upload" (via UploadController), not on app
  // startup or end-of-recording. Recordings stay as raw files in
  // recording_<sid>/ until first upload, which trades a bit of disk for
  // (a) eliminating the "user clicked upload mid-compression and got a
  // corrupt archive" race that hit the factory pilot, and (b) avoiding
  // the worker isolate competing with the camera for CPU.
  final recordingManager = RecordingManager();
  final compressionQueue = CompressionQueue(recordingManager);

  // Cloud-upload pipeline. HTTP against digients-api by default; flip to the
  // mock with `flutter run --dart-define=UPLOAD_BACKEND=mock` for UX work
  // without burning real S3 bytes.
  const uploadBackend = String.fromEnvironment(
    'UPLOAD_BACKEND',
    defaultValue: 'http',
  );
  final deviceIdService = DeviceIdService();
  final UploadService uploadService = uploadBackend == 'mock'
      ? MockUploadService()
      : HttpUploadService(baseUrl: apiBase, deviceId: deviceIdService);
  final uploadController = UploadController(
    service: uploadService,
    manager: recordingManager,
    auth: authController,
  );
  await uploadController.hydrate();

  runApp(DigientsApp(
    themeController: themeController,
    localeController: localeController,
    authController: authController,
    handPresenceSettings: handPresenceSettings,
    compressionQueue: compressionQueue,
    uploadController: uploadController,
  ));
}

class DigientsApp extends StatelessWidget {
  final ThemeController themeController;
  final LocaleController localeController;
  final AuthController authController;
  final HandPresenceSettingsController handPresenceSettings;
  final CompressionQueue compressionQueue;
  final UploadController uploadController;

  const DigientsApp({
    super.key,
    required this.themeController,
    required this.localeController,
    required this.authController,
    required this.handPresenceSettings,
    required this.compressionQueue,
    required this.uploadController,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeController>.value(value: themeController),
        ChangeNotifierProvider<LocaleController>.value(value: localeController),
        ChangeNotifierProvider<AuthController>.value(value: authController),
        ChangeNotifierProvider<HandPresenceSettingsController>.value(
            value: handPresenceSettings),
        ChangeNotifierProvider<CompressionQueue>.value(value: compressionQueue),
        ChangeNotifierProvider<UploadController>.value(value: uploadController),
      ],
      child: Consumer2<ThemeController, LocaleController>(
        builder: (context, themeCtl, localeCtl, _) {
          final router = buildRouter(authController);
          return MaterialApp.router(
            onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
            debugShowCheckedModeBanner: false,
            locale: localeCtl.locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            theme: buildTheme(DCColors.light, Brightness.light),
            darkTheme: buildTheme(DCColors.dark, Brightness.dark),
            themeMode: themeCtl.mode,
            routerConfig: router,
          );
        },
      ),
    );
  }
}
