import 'package:flutter/material.dart';

class AppTheme {
  // Cores do Manager Dashboard
  static const Color surfaceColor = Color(0xFF0b1326);
  static const Color surfaceContainerLowest = Color(0xFF060e20);
  static const Color surfaceContainerLow = Color(0xFF131b2e);
  static const Color surfaceContainer = Color(0xFF171f33);
  static const Color surfaceContainerHigh = Color(0xFF222a3d);
  static const Color surfaceContainerHighest = Color(0xFF2d3449);
  
  static const Color primaryColor = Color(0xFFadc6ff);
  static const Color onPrimaryColor = Color(0xFF002e6a);
  
  static const Color secondaryColor = Color(0xFF4edea3);
  static const Color onSecondaryColor = Color(0xFF003824);
  
  static const Color textColor = Color(0xFFdae2fd);
  static const Color textVariantColor = Color(0xFFc2c6d6);
  
  static const Color outlineColor = Color(0xFF424754);

  static ThemeData get managerTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: surfaceColor,
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        onPrimary: onPrimaryColor,
        secondary: secondaryColor,
        onSecondary: onSecondaryColor,
        surface: surfaceColor,
        onSurface: textColor,
        surfaceContainerHighest: surfaceContainerHighest,
        outline: outlineColor,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontFamily: 'Segoe UI', color: textColor, fontSize: 48, fontWeight: FontWeight.w700),
        titleLarge: TextStyle(fontFamily: 'Segoe UI', color: textColor, fontSize: 24, fontWeight: FontWeight.w600),
        bodyMedium: TextStyle(fontFamily: 'Segoe UI', color: textVariantColor, fontSize: 16),
        labelSmall: TextStyle(fontFamily: 'Consolas', color: textVariantColor, fontSize: 12),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceColor,
        elevation: 0,
        centerTitle: false,
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: surfaceContainerLow,
        indicatorColor: surfaceContainerHighest,
        unselectedIconTheme: IconThemeData(color: textVariantColor),
        selectedIconTheme: IconThemeData(color: primaryColor),
      ),
      dividerTheme: const DividerThemeData(
        color: outlineColor,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
