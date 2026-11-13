import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Paleta principal roxa (Purple Edition)
  static const Color primary = Color(0xFF7C3AED);
  static const Color primaryDark = Color(0xFF5B21B6);
  static const Color primaryLight = Color(0xFFA78BFA);
  static const Color accent = Color(0xFF8B5CF6);

  // Superfícies e fundos
  static const Color surfaceLight = Color(0xFFF8FAFC);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF0F172A);
  static const Color cardDark = Color(0xFF1E293B);

  // Semânticas e alertas
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFF57C00);
  static const Color danger = Color(0xFFD32F2F);
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF475569);
  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFF94A3B8);

  /// Paleta expandida de 70 cores hexadecimais distintas para identificação de itens (30 originais + 40 novas)
  static const List<String> itemColorPalette = [
    // --- 30 Cores Originais ---
    '#E53935',
    '#D81B60',
    '#8E24AA',
    '#5E35B1',
    '#3949AB',
    '#1E88E5',
    '#039BE5',
    '#00ACC1',
    '#00897B',
    '#43A047',
    '#7CB342',
    '#C0CA33',
    '#FDD835',
    '#FFB300',
    '#FB8C00',
    '#F4511E',
    '#6D4C41',
    '#757575',
    '#546E7A',
    '#B71C1C',
    '#880E4F',
    '#4A148C',
    '#311B92',
    '#0D47A1',
    '#006064',
    '#1B5E20',
    '#33691E',
    '#E65100',
    '#BF360C',
    '#263238',
    // --- 40 Novas Cores Experimentais (Purple Edition) ---
    // Tons Roxos, Violetas e Púrpuras
    '#7C3AED', // Vibrant Violet
    '#6D28D9', // Deep Purple
    '#9333EA', // Electric Purple
    '#A855F7', // Medium Purple
    '#C084FC', // Light Lavender
    '#4C1D95', // Midnight Violet
    '#6B21A8', // Royal Purple
    '#A21CAF', // Fuchsia Dark
    '#C026D3', // Fuchsia Vivid
    '#E879F9', // Orchid Pink
    // Tons Rosas e Carmins
    '#EC4899', // Bright Pink
    '#DB2777', // Deep Rose
    '#BE185D', // Crimson Berry
    '#F43F5E', // Rose Red
    '#E11D48', // Ruby
    // Tons Laranjas, Âmbares e Dourados
    '#F97316', // Orange Sun
    '#EA580C', // Bright Rust
    '#D97706', // Amber Dark
    '#F59E0B', // Marigold
    '#CA8A04', // Golden Olive
    // Tons Amarelos e Limas
    '#EAB308', // Sunflower
    '#84CC16', // Lime Bright
    '#65A30D', // Olive Green
    '#4D7C0F', // Forest Lime
    // Tons Verdes e Esmeraldas
    '#10B981', // Emerald
    '#059669', // Emerald Dark
    '#047857', // Pine Green
    '#14B8A6', // Teal Modern
    '#0D9488', // Dark Teal
    '#0F766E', // Deep Sea Teal
    // Tons Cianos e Azuis Celestes
    '#06B6D4', // Cyan Vivid
    '#0891B2', // Cyan Deep
    '#0284C7', // Sky Blue Dark
    '#0EA5E9', // Sky Blue
    '#38BDF8', // Light Cyan
    // Tons Azuis, Índigo e Safiras
    '#2563EB', // Sapphire Blue
    '#1D4ED8', // Cobalt
    '#1E40AF', // Deep Navy
    '#6366F1', // Indigo
    '#4F46E5', // Indigo Deep
  ];

  /// Converte string hexadecimal (ex: '#1565C0') em objeto [Color].
  static Color fromHex(String hexString) {
    final cleanHex = hexString.trim().replaceAll('#', '');
    if (cleanHex.length == 6) {
      final value = int.tryParse('FF$cleanHex', radix: 16);
      if (value != null) {
        return Color(value);
      }
    } else if (cleanHex.length == 8) {
      final value = int.tryParse(cleanHex, radix: 16);
      if (value != null) {
        return Color(value);
      }
    }
    return primary;
  }

  /// Retorna uma cor de texto contrastante (branco ou escuro) para um dado fundo.
  static Color contrastingTextColor(Color background) {
    return ThemeData.estimateBrightnessForColor(background) == Brightness.dark
        ? Colors.white
        : const Color(0xFF0F172A);
  }
}
