import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Design tokens — a calm, monochrome palette matching the So Lock mark.
class C {
  C._();
  static const bg = Color(0xFF0A0A0C);
  static const card = Color(0xFF161618);
  static const card2 = Color(0xFF1F1F23);
  static const pressed = Color(0xFF2A2A2F);
  static const sep = Color(0xFF2C2C31);
  static const text = Color(0xFFF5F5F7);
  static const text2 = Color(0xFF8E8E93);
  static const text3 = Color(0xFF5C5C63);
  static const silver = Color(0xFFE5E5EA);
  static const green = Color(0xFF30D158);
  static const red = Color(0xFFFF453A);
  static const orange = Color(0xFFFF9F0A);
  static const blue = Color(0xFF0A84FF);
  static const purple = Color(0xFFBF5AF2);
  static const teal = Color(0xFF40C8E0);
  static const indigo = Color(0xFF5E5CE6);
  static const pink = Color(0xFFFF375F);
}

class T {
  T._();
  static const title = TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: C.text, letterSpacing: -0.4);
  static const body = TextStyle(fontSize: 16, color: C.text, letterSpacing: -0.3);
  static const sub = TextStyle(fontSize: 13, color: C.text2, letterSpacing: -0.1, height: 1.3);
  static const caption = TextStyle(fontSize: 12.5, color: C.text2, letterSpacing: 0, height: 1.35);
  static const header = TextStyle(fontSize: 12.5, color: C.text2, letterSpacing: 0.3, fontWeight: FontWeight.w500);
  static const big = TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: C.text, letterSpacing: -0.8);
}

/// Lock screen backgrounds.
class LockBg {
  const LockBg(this.name, this.colors);
  final String name;
  final List<Color> colors;

  static const presets = <LockBg>[
    LockBg('Obsidian', [Color(0xFF1C1C21), Color(0xFF0A0A0C), Color(0xFF050506)]),
    LockBg('Graphite', [Color(0xFF3A3A40), Color(0xFF17171A), Color(0xFF0B0B0D)]),
    LockBg('Night', [Color(0xFF1B2140), Color(0xFF0C0F22), Color(0xFF05060E)]),
    LockBg('Aurora', [Color(0xFF0F3B3A), Color(0xFF0D1D2E), Color(0xFF07070F)]),
    LockBg('Dusk', [Color(0xFF4A1D2E), Color(0xFF1E0F1E), Color(0xFF09060B)]),
    LockBg('Ocean', [Color(0xFF0B3A5C), Color(0xFF0A1A2C), Color(0xFF05080F)]),
    LockBg('Violet', [Color(0xFF34205C), Color(0xFF15102A), Color(0xFF07060E)]),
    LockBg('Black', [Color(0xFF000000), Color(0xFF000000), Color(0xFF000000)]),
  ];

  static const accents = <int>[0xFFF2F2F7, 0xFF0A84FF, 0xFF30D158, 0xFFBF5AF2, 0xFFFF375F, 0xFFFF9F0A, 0xFF40C8E0, 0xFFFFD60A];
}

ThemeData buildTheme() {
  const cupertino = CupertinoThemeData(
    brightness: Brightness.dark,
    primaryColor: C.silver,
    scaffoldBackgroundColor: C.bg,
    barBackgroundColor: C.bg,
    textTheme: CupertinoTextThemeData(primaryColor: C.silver),
  );
  return ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    scaffoldBackgroundColor: C.bg,
    canvasColor: C.bg,
    colorScheme: const ColorScheme.dark(primary: C.silver, surface: C.card, error: C.red),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    cupertinoOverrideTheme: cupertino,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    textSelectionTheme: const TextSelectionThemeData(cursorColor: C.silver, selectionColor: Color(0x55FFFFFF)),
    sliderTheme: const SliderThemeData(
      activeTrackColor: C.silver,
      inactiveTrackColor: C.sep,
      thumbColor: Colors.white,
      overlayShape: RoundSliderOverlayShape(overlayRadius: 0),
      trackHeight: 3,
    ),
  );
}

const overlayStyle = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
  systemNavigationBarColor: C.bg,
  systemNavigationBarIconBrightness: Brightness.light,
);
