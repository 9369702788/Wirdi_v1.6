import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/services/settings_service.dart';
import 'core/theme/app_theme.dart';
import 'features/splash/splash_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'shared/widgets/root_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await appSettings.load();
  await initializeDateFormatting('ar', null);
  runApp(const WirdiApp());
}

class WirdiApp extends StatelessWidget {
  const WirdiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appSettings,
      builder: (context, _) {
        return MaterialApp(
          title: 'وردي | Wirdi',
          debugShowCheckedModeBanner: false,

          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: appSettings.themeMode,

          locale: const Locale('ar'),

          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],

          supportedLocales: const [
            Locale('ar'),
            Locale('en'),
          ],

          builder: (context, child) {
            final mediaQuery = MediaQuery.of(context);
            return Directionality(
              textDirection: TextDirection.rtl,
              child: MediaQuery(
                data: mediaQuery.copyWith(textScaler: TextScaler.linear(appSettings.fontScale)),
                child: child ?? const SizedBox.shrink(),
              ),
            );
          },

          home: const AppStartup(),
        );
      },
    );
  }
}

class AppStartup extends StatefulWidget {
  const AppStartup({super.key});

  @override
  State<AppStartup> createState() => _AppStartupState();
}

class _AppStartupState extends State<AppStartup> {
  bool _splashDone = false;
  bool _onboardingDone = false;

  @override
  Widget build(BuildContext context) {
    if (!_splashDone) {
      return SplashScreen(
        onFinished: () {
          setState(() {
            _splashDone = true;
          });
        },
      );
    }

    if (!_onboardingDone) {
      return OnboardingScreen(
        onFinished: () {
          setState(() {
            _onboardingDone = true;
          });
        },
      );
    }

    return const RootShell();
  }
}
