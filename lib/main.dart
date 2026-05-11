import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'l10n/app_localizations.dart';
import 'router.dart';
import 'services/auth_service.dart';
import 'services/compression_queue.dart';
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

  // Default to the deployed prod backend; override via:
  //   flutter run --dart-define=AUTH_BACKEND=mock
  //   flutter run --dart-define=API_BASE=http://localhost:8787
  // The prod URL is the team's Cloudflare Workers deployment (root CLAUDE.md
  // §5.1). M3-M5 server endpoints aren't live yet, so refresh / logout / OAuth
  // throw `not_implemented`; AuthController already swallows refresh/logout
  // failures as best-effort.
  const backend = String.fromEnvironment('AUTH_BACKEND', defaultValue: 'http');
  const apiBase = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'https://digients-api.digients.workers.dev',
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

  // Background compressor for recordings. We construct it up front + scan
  // for legacy recordings without an archive *after* the first frame ships
  // (don't block app startup on it — large legacy backlogs would delay
  // launch otherwise).
  final recordingManager = RecordingManager();
  final compressionQueue = CompressionQueue(recordingManager);
  // Fire-and-forget: enqueueAllMissing only walks the recordings list; the
  // actual compression happens on a worker isolate.
  // ignore: unawaited_futures
  Future<void>.delayed(const Duration(seconds: 1))
      .then((_) => compressionQueue.enqueueAllMissing());

  // Cloud-upload pipeline. Mock by default while Phase C UX is being shaped;
  // switch to the real digients-api backend with
  //   flutter run --dart-define=UPLOAD_BACKEND=http
  // once the HTTP implementation is wired (Phase C, step "wire real backend").
  const uploadBackend = String.fromEnvironment(
    'UPLOAD_BACKEND',
    defaultValue: 'mock',
  );
  final UploadService uploadService = uploadBackend == 'http'
      ? HttpUploadService(baseUrl: apiBase)
      : MockUploadService();
  final uploadController = UploadController(
    service: uploadService,
    recordings: recordingManager,
    compression: compressionQueue,
    auth: authController,
  );

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
