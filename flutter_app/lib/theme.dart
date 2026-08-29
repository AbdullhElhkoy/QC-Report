import 'package:flutter/material.dart';

/// الهوية البصرية المشتركة (ويب + فلاتر): هادي، بسيط، أخضر هادي.
class AppColors {
  AppColors._();

  static const Color bg = Color(0xFFF3F6F4);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surface2 = Color(0xFFF7FAF8);
  static const Color primary = Color(0xFF2E7D32);
  static const Color primaryStrong = Color(0xFF1B5E20);
  static const Color primarySoft = Color(0xFFE8F5E9);
  static const Color text = Color(0xFF1F2933);
  static const Color textMuted = Color(0xFF5F6B64);
  static const Color border = Color(0xFFDCE3DD);
  static const Color danger = Color(0xFFC62828);
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      secondary: AppColors.primaryStrong,
      surface: AppColors.surface,
      error: AppColors.danger,
    ),
    scaffoldBackgroundColor: AppColors.bg,
    fontFamily: "Tajawal",
  );

  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.text,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
    ),
    cardTheme: const CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        side: BorderSide(color: AppColors.border),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: AppColors.primary, width: 1.6),
      ),
      isDense: true,
      labelStyle: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w700),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.text,
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.border),
    textTheme: (base.textTheme)
        .apply(bodyColor: AppColors.text, displayColor: AppColors.text)
        .copyWith(
          titleLarge: const TextStyle(
              fontWeight: FontWeight.w900, color: AppColors.text),
          titleMedium: const TextStyle(
              fontWeight: FontWeight.w700, color: AppColors.text),
        ),
  );
}

/// علامة QC المربعة الخضراء.
class BrandMark extends StatelessWidget {
  final double size;
  final double fontSize;
  const BrandMark({super.key, this.size = 26, this.fontSize = 12});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(size * .27),
      ),
      alignment: Alignment.center,
      child: Text(
        "QC",
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}