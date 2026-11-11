import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Paleta principal azulada profissional
  static const Color primary = Color(0xFF1565C0);
  static const Color primaryDark = Color(0xFF0D47A1);
  static const Color primaryLight = Color(0xFF42A5F5);
  static const Color accent = Color(0xFF0288D1);

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

  /// Paleta fixa de 30 cores hexadecimais distintas para identificação de itens
  static const List<String> itemColorPalette = [
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
