import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens ported from the React/Tailwind design (theme.css, ui.tsx).
class T {
  T._();

  // ── Base colors
  static const bg = Color(0xFF0A0E17);
  static const bgDeep = Color(0xFF02050D); // outer page behind phone frame
  static const fg = Color(0xFFF1F5F9);
  static const card = Color(0xFF070D1A);
  static const destructive = Color(0xFFD4183D);
  static const black = Color(0xFF000000);

  // ── Accent palette (Tailwind)
  static const cyan200 = Color(0xFFA5F3FC);
  static const cyan300 = Color(0xFF67E8F9);
  static const cyan400 = Color(0xFF22D3EE);
  static const cyan500 = Color(0xFF06B6D4);
  static const cyan600 = Color(0xFF0891B2);
  static const indigo500 = Color(0xFF6366F1);
  static const emerald = Color(0xFF10B981);
  static const emerald300 = Color(0xFF6EE7B7);
  static const emerald400 = Color(0xFF34D399);
  static const red400 = Color(0xFFF87171);
  static const red300 = Color(0xFFFCA5A5);
  static const red500 = Color(0xFFEF4444);
  static const amber500 = Color(0xFFF59E0B);
  static const amber300 = Color(0xFFFCD34D);
  static const sky = Color(0xFF0A84FF);
  static const slate900 = Color(0xFF0F172A);

  /// White with opacity: T.white(.5) == Tailwind `white/50`.
  static Color white([double o = 1]) => Color.fromRGBO(255, 255, 255, o);
  static Color blk([double o = 1]) => Color.fromRGBO(0, 0, 0, o);
  static Color op(Color c, double o) => c.withValues(alpha: o);

  // ── Brand teal (solid, used for every button) & flat surfaces
  static const teal = Color(0xFF0D9488);
  static const tealPressed = Color(0xFF0F766E);
  static const surface = Color(0xFF121A2A);
  static const surfaceStrong = Color(0xFF172033);
  static const surfaceTint = Color(0xFF12202B);
  static const surfacePill = Color(0xFF1B2538);
  static final surfaceBorder = white(.08);

  // ── Glass fills (legacy names, kept for compatibility)
  static final glassTop = white(.14);
  static final glassBottom = white(.04);
  static final glassBorder = white(.22);
  static const glassStrongFill = Color.fromRGBO(28, 36, 64, .72);
  static final glassStrongBorder = white(.25);
  static final glassPillFill = white(.12);
  static final glassPillBorder = white(.28);
  static const navFill = Color.fromRGBO(14, 22, 42, .6);
  static final inputFill = white(.07);
  static final inputFillFocus = white(.10);
  static final inputBorder = white(.10);
  static final inputBorderFocus = cyan400.withValues(alpha: .7);

  // ── Gradients
  static const glassGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color.fromRGBO(255, 255, 255, .14), Color.fromRGBO(255, 255, 255, .04)],
  );
  static const tintGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color.fromRGBO(6, 182, 212, .26), Color.fromRGBO(99, 102, 241, .16)],
  );
  // Buttons are solid teal now; kept as a flat 2-stop "gradient" of one color
  // so legacy call sites render solid.
  static const btnLiquidGradient = LinearGradient(colors: [teal, teal]);

  // ── Radii
  static const rGlass = 26.0;
  static const rStrong = 16.0;
  static const rSheet = 32.0;
  static const rBtn = 18.0;
  static const rField = 14.0;
  static const rKey = 20.0;
  static const rNav = 34.0;
  static const rNavItem = 28.0;
  static const rCard = 22.0;

  // ── Spacing
  static const s1 = 4.0, s2 = 8.0, s3 = 12.0, s4 = 16.0, s5 = 20.0, s6 = 24.0, s8 = 32.0;
  static const screenPad = 20.0; // px-5
  static const navBottomPad = 112.0; // pb-28 reserved under scroll content
  static const btnH = 48.0, fieldH = 44.0, keyH = 56.0;

  // ── Shadows
  // Glow / highlight effects are removed app-wide: all shadow tokens are empty.
  static final glassShadow = <BoxShadow>[];
  static final strongShadow = <BoxShadow>[];
  static final tintShadow = <BoxShadow>[];
  static final btnShadow = <BoxShadow>[];
  static final lensShadow = <BoxShadow>[];
  static List<BoxShadow> glow(Color c, [double blur = 12]) => const <BoxShadow>[];

  // ── Typography (Plus Jakarta Sans / JetBrains Mono, cached family to avoid per-build GoogleFonts overhead)
  static final String? _sansFamily = _resolveFontFamily(GoogleFonts.plusJakartaSans);
  static final String? _monoFamily = _resolveFontFamily(GoogleFonts.jetBrainsMono);

  static String? _resolveFontFamily(TextStyle Function() fn) {
    try {
      return fn().fontFamily;
    } catch (_) {
      return null;
    }
  }

  static TextStyle text(double size, {FontWeight w = FontWeight.w400, Color? color, double? height, double? ls, List<Shadow>? shadows}) =>
      TextStyle(
        fontFamily: _sansFamily,
        fontSize: size,
        fontWeight: w,
        color: color ?? Colors.white,
        height: height,
        letterSpacing: ls ?? size * -0.01,
        shadows: shadows,
      );

  /// `font-mono-ui` (letter-spacing 0 unless [ls] given; Tailwind tracking-widest = .1em → ls: size*.1)
  static TextStyle mono(double size, {FontWeight w = FontWeight.w400, Color? color, double? height, double ls = 0}) =>
      TextStyle(
        fontFamily: _monoFamily,
        fontSize: size,
        fontWeight: w,
        color: color ?? Colors.white,
        height: height,
        letterSpacing: ls,
      );

  static const w500 = FontWeight.w500, w600 = FontWeight.w600, w700 = FontWeight.w700, w800 = FontWeight.w800;

  // Common presets
  static TextStyle get h1 => text(24, w: w800);
  static TextStyle get h2 => text(22, w: w800);
  static TextStyle get h3 => text(17, w: w700);
  static TextStyle get body => text(14);
  static TextStyle get label => text(11, w: w600, color: white(.5));
  static TextStyle get caption => text(11, color: white(.45));
  static TextStyle get btn => text(14, w: w700);
}
