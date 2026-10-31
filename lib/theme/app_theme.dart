import 'package:flutter/material.dart';

/// Shared brand colors. Screens should use the theme for adaptive text and icons.
abstract final class AppPalette {
  static const ink = Color(0xFF201B1D);
  static const mutedInk = Color(0xFF766D70);
  static const surface = Color(0xFFFFFBFA);
  static const page = Color(0xFFF5F1F0);
  static const amaranto = Color(0xFF841230);
  static const amarantoDark = Color(0xFF3F091B);
  static const darkPage = Color(0xFF20070D);
  static const playoff = Color(0xFFE58436);
  static const promotion = Color(0xFF3E9957);
  static const gold = Color(0xFFE4CF7E);
  static const goldDark = Color(0xFFB26D26);
  static const line = Color(0xFFE8DEDF);
  // Match white-backed club images and keep transparent crests readable.
  static const teamLogoBackground = Colors.white;
  static const teamLogoForeground = amaranto;
  static const navMuted = Color(0xFFDDBFC7);
  static const bannerMuted = Color(0xFFE8D3D8);
  static const labelOnBrand = Color(0xFFF2C8D0);
  static const detailOnBrand = Color(0xFFF2DDE1);
  static const captionOnBrand = Color(0xFFE7DADD);
  static const subtleOnBrand = Color(0xFFDABDC3);
  static const lightTile = Color(0xFFF8F1F2);
  static const lightTileBorder = Color(0xFFE8DADD);
  static const placeholderTop = Color(0xFFE5D7D9);
  static const placeholderBottom = Color(0xFFF4EBEC);
  static const placeholderInk = Color(0xFF886F75);
  static const iconTile = Color(0xFFF1E7E9);
  static const chatIconTile = Color(0xFFF1E6E8);
  static const shadow = Color(0x30000000);
  static const brandShadow = Color(0x1D4B2732);
  static const glass = Color(0x18FFFFFF);
  static const glassLine = Color(0x29FFFFFF);

  static const amarantoGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [amaranto, amarantoDark],
  );
  static const goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [gold, goldDark],
  );
}

abstract final class AppTheme {
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static BoxDecoration panel(BuildContext context, double radius) =>
      BoxDecoration(
        gradient: isDark(context) ? AppPalette.amarantoGradient : null,
        color: isDark(context) ? null : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: isDark(context) ? 1.25 : 1,
        ),
      );

  static BoxDecoration subtlePanel(BuildContext context, double radius) =>
      BoxDecoration(
        color: isDark(context)
            ? Colors.white.withValues(alpha: 0.08)
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant
              .withValues(alpha: isDark(context) ? 0.35 : 1),
        ),
      );

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final colors = ColorScheme.fromSeed(
      seedColor: AppPalette.amaranto,
      brightness: brightness,
      primary: dark ? AppPalette.gold : AppPalette.amaranto,
      onPrimary: dark ? AppPalette.amarantoDark : Colors.white,
      secondary: dark ? AppPalette.gold : AppPalette.amaranto,
      surface: dark ? AppPalette.amarantoDark : AppPalette.surface,
      onSurface: dark ? Colors.white : AppPalette.ink,
      onSurfaceVariant: dark ? Colors.white : AppPalette.mutedInk,
      outline: dark ? AppPalette.gold : AppPalette.line,
      outlineVariant: dark ? AppPalette.gold : AppPalette.line,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colors,
      scaffoldBackgroundColor: dark ? AppPalette.darkPage : AppPalette.page,
      textTheme: (dark ? ThemeData.dark() : ThemeData.light()).textTheme.apply(
        bodyColor: colors.onSurface,
        displayColor: colors.onSurface,
      ),
      iconTheme: IconThemeData(color: colors.primary),
      dividerColor: colors.outlineVariant,
      cardTheme: CardThemeData(
        color: colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colors.outlineVariant),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: dark ? AppPalette.amaranto : AppPalette.page,
        foregroundColor: colors.onSurface,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}
