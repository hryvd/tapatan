import 'dart:ui';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'application/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'screens/setup_screen.dart';
import 'theme/app_theme.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Force dark status bar icons for the glass look
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization failed: $e\n'
        'Run `flutterfire configure` to generate firebase_options.dart.');
  }
  runApp(const ProviderScope(child: SarEApp()));
}

class SarEApp extends StatelessWidget {
  const SarEApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Sar-E',
          // Always dark — liquid glass is a dark-mode design
          themeMode: ThemeMode.dark,
          theme: buildTheme(Brightness.light, dynamicScheme: lightDynamic),
          darkTheme: buildTheme(Brightness.dark, dynamicScheme: darkDynamic),
          home: const _AppEntry(),
        );
      },
    );
  }
}

/// Root widget that decides which screen to show based on auth state.
class _AppEntry extends ConsumerWidget {
  const _AppEntry();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AuthState> authAsync = ref.watch(authProvider);

    return authAsync.when(
      loading: () => const _SplashScreen(),
      error: (Object e, _) => Center(child: Text('Error: $e')),
      data: (AuthState auth) {
        if (auth.isFirstRun) {
          return const SetupScreen();
        }
        if (auth.isLoggedIn) {
          return const MainShell();
        }
        return const LoginScreen();
      },
    );
  }
}

class _SplashScreen extends StatefulWidget {
  const _SplashScreen();

  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<double> _scale;
  late Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600));
    _fade = CurvedAnimation(parent: _ctrl, curve: const Interval(0, 0.5));
    _scale = Tween<double>(begin: 0.8, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: const Interval(0, 0.5, curve: Curves.easeOut)));
    _progress = CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.3, 1.0, curve: Curves.easeInOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GlassColors.bg1,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background orbs
          Positioned(
            left: -80,
            top: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: Color(0x44E8473F),
                      blurRadius: 120,
                      spreadRadius: 40),
                ],
              ),
            ),
          ),
          Positioned(
            right: -60,
            bottom: -60,
            child: Container(
              width: 240,
              height: 240,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: Color(0x2200D4FF),
                      blurRadius: 100,
                      spreadRadius: 30),
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: const SizedBox.expand(),
            ),
          ),
          // Content
          Center(
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (context, _) => FadeTransition(
                opacity: _fade,
                child: ScaleTransition(
                  scale: _scale,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      // Logo glass card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.18),
                              width: 1),
                          boxShadow: [
                            BoxShadow(
                                color: GlassColors.primary.withValues(alpha: 0.30),
                                blurRadius: 40,
                                spreadRadius: -4),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.asset(
                            'assets/images/sare_logo.png',
                            height: 90,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      // Title
                      const Text(
                        'Sar-E',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 38,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Smart Point of Sale',
                        style: TextStyle(
                          color: GlassColors.accent,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 48),
                      // Animated progress bar
                      SizedBox(
                        width: 180,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: _progress.value,
                            minHeight: 3,
                            color: GlassColors.primary,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
