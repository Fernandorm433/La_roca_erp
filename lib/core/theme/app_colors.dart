import 'package:flutter/material.dart';

class AppColors {
  static const Color primaryDark = Color(0xFF0F172A); 
  static const Color background = Color(0xFFF8FAFC);  
  static const Color accent = Color(0xFF4F46E5);      
  static const Color success = Color(0xFF10B981);     
  static const Color warning = Color(0xFFF59E0B);     
  static const Color error = Color(0xFFEF4444);       
  
  static const Color mixerCargando = Color(0xFFFEF08A); 
  static const Color mixerRegulando = Color(0xFFBAE6FD); 
  static const Color mixerSalio = Color(0xFF86EFAC);    

  // Dark Mode colors
  static const Color backgroundDark = Color(0xFF0F172A); // Slate 900
  static const Color surfaceDark = Color(0xFF1E293B);    // Slate 800
  static const Color textDark = Color(0xFFF8FAFC);       // Slate 50

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.light,
        background: background,
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: background,
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: primaryDark),
        titleTextStyle: TextStyle(
          color: primaryDark,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.dark,
        background: backgroundDark,
        surface: surfaceDark,
      ),
      scaffoldBackgroundColor: backgroundDark,
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundDark,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: textDark),
        titleTextStyle: TextStyle(
          color: textDark,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}