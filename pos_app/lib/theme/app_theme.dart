
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Brand colors ─────────────────────────────────────────────────────────────
const Color _brandSeed = Color(0xFFE8473F); // vibrant red
const Color _glassNeon = Color(0xFFFF5B5B); // neon red accent
const Color _glassCyan = Color(0xFFFF9F43); // warm orange glow accent instead of cyan
const Color _glassGold = Color(0xFFFFD700); // gold accent for AI

// ─── Dark glass color palette ─────────────────────────────────────────────────
class GlassColors {
  static const Color bg1 = Color(0xFF0F0A0A); // Very deep warm dark red-black
  static const Color bg2 = Color(0xFF1C1212); // Deep warm dark red-brown
  static const Color bg3 = Color(0xFF2A1A1A); // Deep warm dark red
  static const Color surface = Color(0x1AFFFFFF); // white 10%
  static const Color surfaceHigh = Color(0x26FFFFFF); // white 15%
  static const Color border = Color(0x33FFFFFF); // white 20%
  static const Color borderHigh = Color(0x4DFFFFFF); // white 30%
  static const Color text = Color(0xFFFFF0F0); // Warm text
  static const Color textSub = Color(0xAAD0B8B8); // Warm secondary text
  static const Color textMuted = Color(0x88888080); // Warm muted text
  static const Color primary = Color(0xFFE8473F); // Vibrant red
  static const Color primaryGlow = Color(0xFFFF5B5B); // Red glow
  static const Color accent = Color(0xFFFF9F43); // Orange accent
  static const Color accentGlow = Color(0xFFFFB86C); // Orange glow
  static const Color gold = Color(0xFFFFD700); // Yellow/gold
  static const Color goldGlow = Color(0xFFFFE851); // Yellow glow
  static const Color success = Color(0xFFFFB800); // Golden yellow success
  static const Color warning = Color(0xFFFF9F43); // Orange warning
  static const Color error = Color(0xFFE8473F); // Red error
  static const Color info = Color(0xFFFFD700); // Yellow info
}

// ─── AppColors façade ─────────────────────────────────────────────────────────
class AppColors {
  const AppColors({
    required this.background,
    required this.backgroundSecondary,
    required this.surface,
    required this.surfaceMuted,
    required this.text,
    required this.textSecondary,
    required this.textTertiary,
    required this.primary,
    required this.primaryDark,
    required this.accent,
    required this.error,
    required this.warning,
    required this.info,
    required this.success,
    required this.border,
    required this.borderSubtle,
    // New glass tokens
    required this.glassNeon,
    required this.glassCyan,
    required this.glassGold,
  });

  final Color background;
  final Color backgroundSecondary;
  final Color surface;
  final Color surfaceMuted;
  final Color text;
  final Color textSecondary;
  final Color textTertiary;
  final Color primary;
  final Color primaryDark;
  final Color accent;
  final Color error;
  final Color warning;
  final Color info;
  final Color success;
  final Color border;
  final Color borderSubtle;
  final Color glassNeon;
  final Color glassCyan;
  final Color glassGold;

  factory AppColors.fromScheme(ColorScheme scheme) {
    final bool dark = scheme.brightness == Brightness.dark;
    if (dark) {
      return const AppColors(
        background: GlassColors.bg1,
        backgroundSecondary: GlassColors.bg2,
        surface: GlassColors.surface,
        surfaceMuted: GlassColors.surfaceHigh,
        text: GlassColors.text,
        textSecondary: GlassColors.textSub,
        textTertiary: GlassColors.textMuted,
        primary: GlassColors.primary,
        primaryDark: Color(0xFFB03028),
        accent: GlassColors.accent,
        error: GlassColors.error,
        warning: GlassColors.warning,
        info: GlassColors.info,
        success: GlassColors.success,
        border: GlassColors.border,
        borderSubtle: Color(0x1AFFFFFF),
        glassNeon: GlassColors.primaryGlow,
        glassCyan: GlassColors.accentGlow,
        glassGold: GlassColors.goldGlow,
      );
    }
    // Light fallback (unchanged logic for light mode)
    final Color background = Color.lerp(
      scheme.surface,
      scheme.primary,
      0.02,
    )!;
    final Color surface = Color.lerp(scheme.surface, scheme.primary, 0.04)!;
    final Color surfaceMuted =
        Color.lerp(scheme.surface, scheme.primary, 0.08)!;
    return AppColors(
      background: background,
      backgroundSecondary: scheme.surface,
      surface: surface,
      surfaceMuted: surfaceMuted,
      text: scheme.onSurface,
      textSecondary: scheme.onSurfaceVariant,
      textTertiary: scheme.onSurfaceVariant.withValues(alpha: 0.64),
      primary: scheme.primary,
      primaryDark: Color.lerp(scheme.primary, Colors.black, 0.22)!,
      accent: scheme.secondary,
      error: scheme.error,
      warning: const Color(0xFFF59E0B),
      info: scheme.tertiary,
      success: const Color(0xFFFFB800),
      border: scheme.outline.withValues(alpha: 0.40),
      borderSubtle: scheme.outline.withValues(alpha: 0.22),
      glassNeon: scheme.primary,
      glassCyan: scheme.secondary,
      glassGold: const Color(0xFFFFD700),
    );
  }
}

// ─── Glass decoration helpers ─────────────────────────────────────────────────

/// A frosted glass container decoration.
BoxDecoration glassDecoration({
  Color tint = GlassColors.surface,
  Color border = GlassColors.border,
  double radius = 24,
  List<Color>? glowColors,
}) {
  return BoxDecoration(
    color: tint,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: border, width: 1.2),
    boxShadow: glowColors != null
        ? glowColors
            .map((c) => BoxShadow(
                  color: c.withValues(alpha: 0.22),
                  blurRadius: 32,
                  spreadRadius: -4,
                ))
            .toList()
        : const [],
  );
}

// ─── Theme builder ────────────────────────────────────────────────────────────

ThemeData buildTheme(Brightness brightness, {ColorScheme? dynamicScheme}) {
  final ColorScheme scheme = dynamicScheme ??
      ColorScheme.fromSeed(
        seedColor: _brandSeed,
        brightness: brightness,
        dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
      );
  final AppColors c = AppColors.fromScheme(scheme);
  final bool dark = brightness == Brightness.dark;

  // For dark mode we use a completely custom scheme to ensure the glass look
  final ColorScheme effectiveScheme = dark
      ? scheme.copyWith(
          surface: GlassColors.bg2,
          onSurface: GlassColors.text,
          primary: GlassColors.primary,
          onPrimary: Colors.white,
          secondary: GlassColors.accent,
          onSecondary: Colors.black,
          outline: GlassColors.border,
        )
      : scheme;

  final ThemeData base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: dark ? GlassColors.bg1 : c.background,
    colorScheme: effectiveScheme,
    appBarTheme: AppBarTheme(
      backgroundColor: dark
          ? GlassColors.bg1.withValues(alpha: 0.85)
          : c.background.withValues(alpha: 0.92),
      foregroundColor: c.text,
      toolbarHeight: 72,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleSpacing: 16,
      shape: Border(
          bottom: BorderSide(
              color: dark ? GlassColors.border : c.borderSubtle,
              width: 0.8)),
    ),
    cardTheme: CardThemeData(
      color: dark ? GlassColors.surface : c.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
            color: dark ? GlassColors.border : c.borderSubtle, width: 0.8),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: dark ? GlassColors.bg2 : c.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: dark ? GlassColors.bg2 : c.surface,
      modalBackgroundColor: dark ? GlassColors.bg2 : c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark
          ? GlassColors.surface
          : c.surfaceMuted,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
            color: dark ? GlassColors.border : c.border, width: 0.8),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
            color: dark ? GlassColors.border : c.border, width: 0.8),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
            color: dark ? GlassColors.primary : c.primary, width: 1.5),
      ),
      hintStyle: TextStyle(
          color: dark ? GlassColors.textMuted : c.textTertiary),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.primary,
        foregroundColor: Colors.white,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: c.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.primary,
        side: BorderSide(color: dark ? GlassColors.border : c.border),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: dark ? GlassColors.primaryGlow : c.primary,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: dark ? GlassColors.text : c.primary,
        backgroundColor: dark ? GlassColors.surface : c.surfaceMuted,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: dark ? GlassColors.surface : c.surfaceMuted,
      selectedColor: dark
          ? GlassColors.primary.withValues(alpha: 0.25)
          : c.primary.withValues(alpha: 0.14),
      side: BorderSide(
          color: dark ? GlassColors.border : c.border, width: 0.8),
      labelStyle: TextStyle(
          color: dark ? GlassColors.text : c.text,
          fontWeight: FontWeight.w600),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    ),
    dividerTheme: DividerThemeData(
        color: dark ? GlassColors.border : c.borderSubtle,
        thickness: 0.8),
    progressIndicatorTheme: ProgressIndicatorThemeData(
        color: dark ? GlassColors.primaryGlow : c.primary),
    textTheme: TextTheme(
      displayLarge: GoogleFonts.sora(
          color: dark ? GlassColors.text : c.text,
          fontWeight: FontWeight.w800),
      displayMedium: GoogleFonts.sora(
          color: dark ? GlassColors.text : c.text,
          fontWeight: FontWeight.w800),
      displaySmall: GoogleFonts.sora(
          color: dark ? GlassColors.text : c.text,
          fontWeight: FontWeight.w800),
      headlineLarge: GoogleFonts.sora(
          color: dark ? GlassColors.text : c.text,
          fontWeight: FontWeight.w800),
      headlineMedium: GoogleFonts.sora(
          color: dark ? GlassColors.text : c.text,
          fontWeight: FontWeight.w700),
      headlineSmall: GoogleFonts.sora(
          color: dark ? GlassColors.text : c.text,
          fontWeight: FontWeight.w700),
      titleLarge: GoogleFonts.sora(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: dark ? GlassColors.text : c.text),
      titleMedium: GoogleFonts.sora(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: dark ? GlassColors.text : c.text),
      titleSmall: GoogleFonts.sora(
          color: dark ? GlassColors.text : c.text,
          fontWeight: FontWeight.w600),
      bodyLarge: GoogleFonts.inter(
          color: dark ? GlassColors.text : c.text,
          fontWeight: FontWeight.w500),
      bodyMedium: GoogleFonts.inter(
          color: dark ? GlassColors.text : c.text,
          fontWeight: FontWeight.w400),
      bodySmall: GoogleFonts.inter(
          color: dark ? GlassColors.textSub : c.textSecondary,
          fontWeight: FontWeight.w400),
      labelLarge: GoogleFonts.inter(fontWeight: FontWeight.w700),
      labelMedium: GoogleFonts.inter(fontWeight: FontWeight.w600),
      labelSmall: GoogleFonts.inter(fontWeight: FontWeight.w600),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? GlassColors.bg2 : c.surface,
      contentTextStyle: TextStyle(
          color: dark ? GlassColors.text : c.text),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: dark
          ? GlassColors.bg1.withValues(alpha: 0.90)
          : c.surface.withValues(alpha: 0.94),
      indicatorColor: dark
          ? GlassColors.primary.withValues(alpha: 0.20)
          : c.primary.withValues(alpha: 0.16),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStatePropertyAll<TextStyle>(
        GoogleFonts.inter(
          color: dark ? GlassColors.textSub : c.textSecondary,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
      iconTheme: WidgetStatePropertyAll<IconThemeData>(
        IconThemeData(
            color: dark ? GlassColors.textSub : c.textSecondary,
            size: 22),
      ),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: ZoomPageTransitionsBuilder(),
        TargetPlatform.fuchsia: ZoomPageTransitionsBuilder(),
        TargetPlatform.linux: ZoomPageTransitionsBuilder(),
        TargetPlatform.macOS: ZoomPageTransitionsBuilder(),
        TargetPlatform.windows: ZoomPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(
      fontFamily: GoogleFonts.inter().fontFamily,
    ),
    appBarTheme: base.appBarTheme.copyWith(
      titleTextStyle: GoogleFonts.sora(
        color: dark ? GlassColors.text : c.text,
        fontSize: 20,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

AppColors appColors(BuildContext context) {
  return AppColors.fromScheme(Theme.of(context).colorScheme);
}

bool isDark(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;
