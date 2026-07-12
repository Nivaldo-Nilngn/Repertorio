import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum AppThemeType {
  managerDark,
  managerLight,
  cafeteriaModerna,
  graoGourmet,
  bistroVintage,
  custom,
}

extension AppThemeTypeLabel on AppThemeType {
  String get label {
    switch (this) {
      case AppThemeType.managerDark:
        return 'Manager (Escuro)';
      case AppThemeType.managerLight:
        return 'Manager (Claro)';
      case AppThemeType.cafeteriaModerna:
        return 'Cafeteria Moderna';
      case AppThemeType.graoGourmet:
        return 'Grão Gourmet';
      case AppThemeType.bistroVintage:
        return 'Bistrô Vintage';
      case AppThemeType.custom:
        return 'Personalizado';
    }
  }
}

class AppTheme {
  // ---------- Cores do Manager Dashboard ----------
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

  // ---------- Paleta Cafeteria (compartilhada pelos 3 combos) ----------
  static const Color espresso = Color(0xFF1A0F0A);
  static const Color cafeTorrado = Color(0xFF3D2314);
  static const Color caramelo = Color(0xFFA0522D);
  static const Color canela = Color(0xFFC08A58);
  static const Color latte = Color(0xFFD1B48C);
  static const Color creme = Color(0xFFF5F2EB);
  static const Color verdeMusgo = Color(0xFF4A5D4E);

  /// Resolve o ThemeData a partir do tipo selecionado.
  static ThemeData resolve(AppThemeType type) {
    switch (type) {
      case AppThemeType.managerDark:
        return managerTheme;
      case AppThemeType.managerLight:
        return lightTheme;
      case AppThemeType.cafeteriaModerna:
        return cafeteriaModernaTheme;
      case AppThemeType.graoGourmet:
        return graoGourmetTheme;
      case AppThemeType.bistroVintage:
        return bistroVintageTheme;
      case AppThemeType.custom:
        return managerTheme; // Fallback, override by resolving with customColor
    }
  }

  static ThemeData resolveWithCustomSettings(AppThemeType type, {
    String? primaryHex,
    String? bgHex,
    String? textHex,
    String? fontFamily,
  }) {
    ThemeData baseTheme;
    
    if (type == AppThemeType.custom) {
      baseTheme = buildCustomTheme(
        primaryHex: primaryHex,
        bgHex: bgHex,
        textHex: textHex,
        fontFamily: fontFamily, // customTheme already handles font internally
      );
      return baseTheme;
    }
    
    baseTheme = resolve(type);
    
    // Apply font to non-custom themes
    if (fontFamily != null && fontFamily.isNotEmpty) {
      try {
        baseTheme = baseTheme.copyWith(
          textTheme: GoogleFonts.getTextTheme(fontFamily, baseTheme.textTheme),
        );
      } catch (_) {}
    }
    
    return baseTheme;
  }

  static ThemeData buildCustomTheme({
    String? primaryHex,
    String? bgHex,
    String? textHex,
    String? fontFamily,
  }) {
    Color primary = Colors.blueGrey;
    if (primaryHex != null) {
      try { primary = Color(int.parse(primaryHex.replaceFirst('#', '0xFF'))); } catch (_) {}
    }

    Color bgColor = const Color(0xFF121212);
    if (bgHex != null) {
      try { bgColor = Color(int.parse(bgHex.replaceFirst('#', '0xFF'))); } catch (_) {}
    }

    Color textColor = Colors.white;
    if (textHex != null) {
      try { textColor = Color(int.parse(textHex.replaceFirst('#', '0xFF'))); } catch (_) {}
    }

    final baseTextTheme = TextTheme(
      displayLarge: TextStyle(fontSize: 48, fontWeight: FontWeight.w700, color: textColor),
      titleLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: textColor),
      bodyMedium: TextStyle(fontSize: 16, color: textColor),
      bodySmall: TextStyle(color: textColor.withOpacity(0.7)),
      labelSmall: TextStyle(fontSize: 12, color: textColor.withOpacity(0.6)),
    );

    TextTheme textTheme = baseTextTheme;
    if (fontFamily != null && fontFamily.isNotEmpty) {
      try {
        textTheme = GoogleFonts.getTextTheme(fontFamily, baseTextTheme);
      } catch (_) {
        // Fallback silently if GoogleFonts fails
      }
    }

    Color lighten(Color c, double amount) {
      final hsl = HSLColor.fromColor(c);
      final l = (hsl.lightness + amount).clamp(0.0, 1.0);
      return hsl.withLightness(l).toColor();
    }

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgColor,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary, // Force exact primary
        onPrimary: primary.computeLuminance() > 0.5 ? Colors.black : Colors.white, // Garantir contraste no botão
        brightness: Brightness.dark,
        surface: bgColor, // Force exact bg
        surfaceContainerLowest: lighten(bgColor, -0.05),
        surfaceContainerLow: lighten(bgColor, -0.02),
        surfaceContainer: lighten(bgColor, 0.05),
        surfaceContainerHigh: lighten(bgColor, 0.08),
        surfaceContainerHighest: lighten(bgColor, 0.12),
        onSurface: textColor, // Force exact text
        onSurfaceVariant: textColor.withOpacity(0.7),
      ).copyWith(
        surfaceTint: Colors.transparent, // Impede que o Material3 misture a cor primária no fundo
      ),
      textTheme: textTheme,
    );
  }

  // ==================================================
  // MANAGER DASHBOARD (Escuro)
  // ==================================================
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
        surfaceContainer: surfaceContainer,
        surfaceContainerLow: surfaceContainerLow,
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

  // ==================================================
  // MANAGER DASHBOARD (Claro)
  // ==================================================
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF0F4F8),
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF00499C),
        onPrimary: Colors.white,
        secondary: Color(0xFF006C48),
        onSecondary: Colors.white,
        surface: Color(0xFFF0F4F8),
        onSurface: Color(0xFF1A1C20),
        surfaceContainerHighest: Color(0xFFDDE3EA),
        outline: Color(0xFF74777F),
        surfaceContainer: Color(0xFFE2E8F0),
        surfaceContainerLow: Color(0xFFFFFFFF),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontFamily: 'Segoe UI', color: Color(0xFF1A1C20), fontSize: 48, fontWeight: FontWeight.w700),
        titleLarge: TextStyle(fontFamily: 'Segoe UI', color: Color(0xFF1A1C20), fontSize: 24, fontWeight: FontWeight.w600),
        bodyMedium: TextStyle(fontFamily: 'Segoe UI', color: Color(0xFF43474E), fontSize: 16),
        labelSmall: TextStyle(fontFamily: 'Consolas', color: Color(0xFF43474E), fontSize: 12),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF0F4F8),
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: Color(0xFF1A1C20)),
        titleTextStyle: TextStyle(color: Color(0xFF1A1C20), fontSize: 20, fontWeight: FontWeight.w600),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: Color(0xFFFFFFFF),
        indicatorColor: Color(0xFFDDE3EA),
        unselectedIconTheme: IconThemeData(color: Color(0xFF43474E)),
        selectedIconTheme: IconThemeData(color: Color(0xFF00499C)),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF74777F),
        thickness: 1,
        space: 1,
      ),
    );
  }

  // ==================================================
  // COMBO 1 — Cafeteria Moderna (Minimalista)
  // Montserrat + Lato / fundo creme / detalhe verde musgo
  // ==================================================
  static ThemeData get cafeteriaModernaTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: creme,
      colorScheme: const ColorScheme.light(
        primary: espresso,
        onPrimary: creme,
        secondary: verdeMusgo,
        onSecondary: creme,
        surface: creme,
        onSurface: cafeTorrado,
        surfaceContainerHighest: Color(0xFFE7E1D3),
        outline: verdeMusgo,
        surfaceContainer: Color(0xFFEFE9DD),
        surfaceContainerLow: Color(0xFFFAF8F3),
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.montserrat(color: espresso, fontSize: 48, fontWeight: FontWeight.w700),
        titleLarge: GoogleFonts.montserrat(color: espresso, fontSize: 24, fontWeight: FontWeight.w600),
        bodyMedium: GoogleFonts.lato(color: cafeTorrado, fontSize: 16),
        labelSmall: GoogleFonts.lato(color: cafeTorrado, fontSize: 12),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: creme,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: espresso),
        titleTextStyle: GoogleFonts.montserrat(color: espresso, fontSize: 20, fontWeight: FontWeight.w600),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: Color(0xFFFAF8F3),
        indicatorColor: Color(0xFFE7E1D3),
        unselectedIconTheme: IconThemeData(color: cafeTorrado),
        selectedIconTheme: IconThemeData(color: verdeMusgo),
      ),
      dividerTheme: const DividerThemeData(
        color: verdeMusgo,
        thickness: 1,
        space: 1,
      ),
    );
  }

  // ==================================================
  // COMBO 2 — Grão Gourmet (Clássico/Elegante)
  // Playfair Display + Georgia / fundo branco / detalhe canela
  // ==================================================
  static ThemeData get graoGourmetTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: Colors.white,
      colorScheme: const ColorScheme.light(
        primary: cafeTorrado,
        onPrimary: Colors.white,
        secondary: canela,
        onSecondary: espresso,
        surface: Colors.white,
        onSurface: espresso,
        surfaceContainerHighest: Color(0xFFF3EFE9),
        outline: canela,
        surfaceContainer: Color(0xFFFAF7F3),
        surfaceContainerLow: Colors.white,
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.playfairDisplay(color: cafeTorrado, fontSize: 48, fontWeight: FontWeight.w700),
        titleLarge: GoogleFonts.playfairDisplay(color: cafeTorrado, fontSize: 24, fontWeight: FontWeight.w600),
        // Georgia é fonte de sistema (não está no Google Fonts), então mantemos fontFamily direto
        bodyMedium: const TextStyle(fontFamily: 'Georgia', color: espresso, fontSize: 16),
        labelSmall: const TextStyle(fontFamily: 'Georgia', color: espresso, fontSize: 12),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: cafeTorrado),
        titleTextStyle: GoogleFonts.playfairDisplay(color: cafeTorrado, fontSize: 20, fontWeight: FontWeight.w600),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: Colors.white,
        indicatorColor: Color(0xFFF3EFE9),
        unselectedIconTheme: IconThemeData(color: espresso),
        selectedIconTheme: IconThemeData(color: canela),
      ),
      dividerTheme: const DividerThemeData(
        color: canela,
        thickness: 1,
        space: 1,
      ),
    );
  }

  // ==================================================
  // COMBO 3 — Bistrô Vintage (Artesanal)
  // Arvo/Amatic SC + Courier Prime / fundo latte
  // ==================================================
  static ThemeData get bistroVintageTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: latte,
      colorScheme: const ColorScheme.light(
        primary: espresso,
        onPrimary: latte,
        secondary: cafeTorrado,
        onSecondary: latte,
        surface: latte,
        onSurface: espresso,
        surfaceContainerHighest: Color(0xFFC2A377),
        outline: espresso,
        surfaceContainer: Color(0xFFC9AC81),
        surfaceContainerLow: Color(0xFFDABE94),
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.arvo(color: espresso, fontSize: 48, fontWeight: FontWeight.w700),
        titleLarge: GoogleFonts.arvo(color: espresso, fontSize: 24, fontWeight: FontWeight.w600),
        bodyMedium: GoogleFonts.courierPrime(color: cafeTorrado, fontSize: 16),
        labelSmall: GoogleFonts.courierPrime(color: cafeTorrado, fontSize: 12),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: latte,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: espresso),
        titleTextStyle: GoogleFonts.arvo(color: espresso, fontSize: 20, fontWeight: FontWeight.w600),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: Color(0xFFDABE94),
        indicatorColor: Color(0xFFC2A377),
        unselectedIconTheme: IconThemeData(color: cafeTorrado),
        selectedIconTheme: IconThemeData(color: espresso),
      ),
      dividerTheme: const DividerThemeData(
        color: espresso,
        thickness: 1,
        space: 1,
      ),
    );
  }
}