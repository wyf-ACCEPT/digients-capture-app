import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'router.dart';
import 'state/theme_controller.dart';
import 'theme/app_theme.dart';
import 'theme/tokens.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final themeController = ThemeController();
  await themeController.load();
  runApp(DigientsApp(themeController: themeController));
}

class DigientsApp extends StatelessWidget {
  final ThemeController themeController;
  const DigientsApp({super.key, required this.themeController});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ThemeController>.value(
      value: themeController,
      child: Consumer<ThemeController>(
        builder: (context, ctl, _) {
          final router = buildRouter();
          return MaterialApp.router(
            title: 'Digients Capture',
            debugShowCheckedModeBanner: false,
            theme: buildTheme(DCColors.light, Brightness.light),
            darkTheme: buildTheme(DCColors.dark, Brightness.dark),
            themeMode: ctl.mode,
            routerConfig: router,
          );
        },
      ),
    );
  }
}
