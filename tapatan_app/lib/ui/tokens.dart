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

  // ── Glass fills
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
  static const btnLiquidGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0, .55, 1],
    colors: [Color.fromRGBO(103, 232, 249, .95), Color.fromRGBO(6, 182, 212, .92), Color.fromRGBO(16, 185, 129, .92)],
  );

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
  static final glassShadow = <BoxShadow>[
    BoxShadow(color: blk(.45), blurRadius: 32, spreadRadius: -8, offset: const Offset(0, 12)),
  ];
  static final strongShadow = <BoxShadow>[
    BoxShadow(color: blk(.5), blurRadius: 30, offset: const Offset(0, 10)),
  ];
  static final tintShadow = <BoxShadow>[
    BoxShadow(color: sky.withValues(alpha: .35), blurRadius: 28, spreadRadius: -8, offset: const Offset(0, 10)),
  ];
  static final btnShadow = <BoxShadow>[
    BoxShadow(color: cyan500.withValues(alpha: .6), blurRadius: 24, spreadRadius: -6, offset: const Offset(0, 10)),
  ];
  static final lensShadow = <BoxShadow>[
    BoxShadow(color: cyan500.withValues(alpha: .35), blurRadius: 14, offset: const Offset(0, 4)),
  ];
  static List<BoxShadow> glow(Color c, [double blur = 12]) => [BoxShadow(color: c, blurRadius: blur)];

  // ── Typography (Plus Jakarta Sans / JetBrains Mono, letter-spacing -0.01em)
  static TextStyle text(double size, {FontWeight w = FontWeight.w400, Color? color, double? height, double? ls, List<Shadow>? shadows}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: size,
        fontWeight: w,
        color: color ?? Colors.white,
        height: height,
        letterSpacing: ls ?? size * -0.01,
        shadows: shadows,
      );

  /// `font-mono-ui` (letter-spacing 0 unless [ls] given; Tailwind tracking-widest = .1em → ls: size*.1)
  static TextStyle mono(double size, {FontWeight w = FontWeight.w400, Color? color, double? height, double ls = 0}) =>
      GoogleFonts.jetBrainsMono(fontSize: size, fontWeight: w, color: color ?? Colors.white, height: height, letterSpacing: ls);

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
