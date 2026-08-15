import 'package:flutter/material.dart';

/// AppColors defines the color palette used throughout Maarg.
/// It features slate grey/navy tones as primary surfaces and a vibrant amber/orange
/// accent color representing logistics, movement, and efficiency.
abstract class AppColors {
  // Brand colors
  static const Color primaryBlue = Color(0xFF1677FF); // Electric Blue from logo arrow
  static const Color primaryLight = Color(0xFF2EA8FF); // Soft electric blue
  static const Color accentOrange = Color(0xFF1677FF); // Kept for compatibility, mapped to Electric Blue
  static const Color accentAmber = Color(0xFF2EA8FF); // Kept for compatibility, mapped to Light Blue
  static const Color cyanAccent = Color(0xFF38BDF8);
  static const Color skyBlue = Color(0xFF7DD3FC);

  // Light Mode Colors
  static const Color lightBg = Color(0xFFF4F6F9); // Crisp premium light grey/blue
  static const Color lightSurface = Colors.white;
  static const Color lightTextPrimary = Color(0xFF0A1628); // Deep Navy Slate
  static const Color lightTextSecondary = Color(0xFF3A4F6B); // Slate Blue
  static const Color lightTextTertiary = Color(0xFF8B9FB4); // Cool Grey
  static const Color lightBorder = Color(0xFFE2E8F0); // Subtle Border
  static const Color lightDivider = Color(0xFFF1F5F9); 

  // Dark Mode Colors (Deep Navy / Electric Blue)
  static const Color darkBg = Color(0xFF0A1628); // Logo Navy Background
  static const Color darkSurface = Color(0xFF0F1D32); // Premium deep navy slate surface
  static const Color darkSurfaceCard = Color(0xFF162A45); // Elevated card container bg
  static const Color darkTextPrimary = Color(0xFFF8FAFC); // High visibility white/grey
  static const Color darkTextSecondary = Color(0xFF90A3BC); // Cool blue-grey secondary
  static const Color darkTextTertiary = Color(0xFF526D8C); // Muted navy text
  static const Color darkBorder = Color(0xFF1E3A5F); // Premium subtle blue/navy border
  static const Color darkDivider = Color(0xFF162A45); 

  // Universal Semantic Colors
  static const Color success = Color(0xFF10B981); // Emerald Green
  static const Color error = Color(0xFFEF4444); // Red 
  static const Color warning = Color(0xFFF59E0B); 
  static const Color info = Color(0xFF06B6D4); // Cyan

  // Premium Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF1677FF), Color(0xFF2EA8FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF1677FF), Color(0xFF2EA8FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkCardGradient = LinearGradient(
    colors: [darkSurface, Color(0xFF162A45)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
