import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/auth_screen.dart';
import 'screens/security_info_screen.dart';
import 'ui/tokens.dart';
import 'screens/main_shell.dart';

void main() {
  runApp(
    const ProviderScope(
      child: BantayApp(),
    ),
  );
}

class BantayApp extends StatelessWidget {
  const BantayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'tap@tan v2',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: T.bg,
        canvasColor: T.bg,
        primaryColor: T.cyan600,
        colorScheme: const ColorScheme.dark(
          primary: T.cyan400,
          secondary: T.indigo500,
          surface: T.card,
          error: T.red500,
        ),
        textTheme: GoogleFonts.plusJakartaSansTextTheme(ThemeData.dark().textTheme).apply(
          bodyColor: T.fg,
          displayColor: T.fg,
        ),
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        snackBarTheme: SnackBarThemeData(
          backgroundColor: T.glassStrongFill,
          contentTextStyle: T.text(12.5, w: T.w600, color: Colors.white),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: <TargetPlatform, PageTransitionsBuilder>{
            TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
          },
        ),
        useMaterial3: true,
      ),
      initialRoute: '/auth',
      routes: {
        '/auth': (context) => const AuthScreen(),
        '/main': (context) => const MainShell(),
        '/security': (context) => const SecurityInfoScreen(),
      },
    );
  }
}
