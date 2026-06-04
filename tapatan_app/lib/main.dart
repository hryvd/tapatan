import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/auth_screen.dart';
import 'screens/main_shell.dart';

void main() {
  runApp(
    const ProviderScope(
      child: TapatanApp(),
    ),
  );
}

class TapatanApp extends StatelessWidget {
  const TapatanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'tap@tan',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF020B18), // deep navy-black
        primaryColor: const Color(0xFF0891B2), // teal primary
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF0891B2),   // teal
          secondary: Color(0xFF0369A1), // deep blue
          surface: Color(0xFF0C1A2E),
          error: Color(0xFFEF4444),
        ),
        textTheme: GoogleFonts.interTextTheme(Theme.of(context).textTheme).apply(
          bodyColor: const Color(0xFFFAFAFA),
          displayColor: const Color(0xFFFAFAFA),
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
      },
    );
  }
}
