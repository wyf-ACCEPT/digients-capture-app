import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'l10n/app_localizations.dart';
import 'router.dart';
import 'services/auth_service.dart';
import 'services/token_storage.dart';
import 'state/auth_controller.dart';
import 'state/hand_presence_settings_controller.dart';
import 'state/locale_controller.dart';
import 'state/theme_controller.dart';
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

  final authController = AuthController(
    service: MockAuthService(),
    tokens: TokenStorage(),
  );
  // Restore session from a stored refresh token if one exists. Blocks first
  // frame so the router never flashes the auth screen for a logged-in user.
  await authController.bootstrap();

  runApp(DigientsApp(
    themeController: themeController,
    localeController: localeController,
    authController: authController,
    handPresenceSettings: handPresenceSettings,
  ));
}

class DigientsApp extends StatelessWidget {
  final ThemeController themeController;
  final LocaleController localeController;
  final AuthController authController;
  final HandPresenceSettingsController handPresenceSettings;

  const DigientsApp({
    super.key,
    required this.themeController,
    required this.localeController,
    required this.authController,
    required this.handPresenceSettings,
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
