import 'package:flutter/material.dart';

class AppColors {
  // ─── PALETA CORPORATIVA NOVACON (Azul, Celeste y Gris) ───────────────
  static const Color primary = Color(0xFF004899);       // Azul corporativo principal
  static const Color primaryDark = Color(0xFF0F172A);   // Azul pizarra profundo / texto principal
  static const Color accent = Color(0xFF0090F0);        // Celeste vibrante / acento interactivo
  static const Color celeste = Color(0xFF0284C7);       // Celeste medio
  static const Color celesteLight = Color(0xFFE0F2FE);  // Fondo celeste suave para chips / badges
  static const Color blueLight = Color(0xFFEFF6FF);     // Fondo azul tenue para selecciones

  // ─── TONOS GRISES ELEGANTES ──────────────────────────────────────────
  static const Color grey = Color(0xFF64748B);          // Gris pizarra medio (subtítulos, iconos)
  static const Color greyDark = Color(0xFF334155);      // Gris carbón (textos oscuros secundarios)
  static const Color greyLight = Color(0xFFF1F5F9);     // Gris suave para tarjetas / campos
  static const Color greyBorder = Color(0xFFE2E8F0);    // Borde elegante sutil
  static const Color background = Color(0xFFF8FAFC);    // Fondo general limpio

  // ─── ESTADOS Y ALERTAS ───────────────────────────────────────────────
  static const Color success = Color(0xFF10B981);       // Verde éxito
  static const Color warning = Color(0xFFF59E0B);       // Ámbar advertencia
  static const Color error = Color(0xFFEF4444);         // Rojo error
  
  static const Color mixerCargando = Color(0xFFFEF08A); 
  static const Color mixerRegulando = Color(0xFFBAE6FD); 
  static const Color mixerSalio = Color(0xFF86EFAC);    

  // ─── MODO OSCURO ────────────────────────────────────────────────────
  static const Color backgroundDark = Color(0xFF0B132B); // Azul noche profundo
  static const Color surfaceDark = Color(0xFF1E293B);    // Slate 800
  static const Color textDark = Color(0xFFF8FAFC);       // Slate 50

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',
      brightness: Brightness.light,
      primaryColor: primary,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: accent,
        tertiary: grey,
        brightness: Brightness.light,
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: background,
      cardColor: Colors.white,
      dividerColor: greyBorder,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: primaryDark),
        titleTextStyle: TextStyle(
          color: primaryDark,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',
      brightness: Brightness.dark,
      primaryColor: primary,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: accent,
        secondary: celeste,
        tertiary: grey,
        brightness: Brightness.dark,
        surface: surfaceDark,
      ),
      scaffoldBackgroundColor: backgroundDark,
      cardColor: surfaceDark,
      dividerColor: const Color(0xFF334155),
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceDark,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: textDark),
        titleTextStyle: TextStyle(
          color: textDark,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}