import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

@immutable
class CategoryPreset {
  final String category;
  final double defaultPrice;
  final int defaultMinutes;

  const CategoryPreset({
    required this.category,
    required this.defaultPrice,
    required this.defaultMinutes,
  });

  CategoryPreset copyWith({
    double? defaultPrice,
    int? defaultMinutes,
  }) {
    return CategoryPreset(
      category: category,
      defaultPrice: defaultPrice ?? this.defaultPrice,
      defaultMinutes: defaultMinutes ?? this.defaultMinutes,
    );
  }
}

@immutable
class AppSettingsState {
  final Map<String, CategoryPreset> presets;
  final ThemeMode themeMode;
  final bool isLoaded;

  const AppSettingsState({
    required this.presets,
    this.themeMode = ThemeMode.dark,
    this.isLoaded = false,
  });

  factory AppSettingsState.initial() {
    return const AppSettingsState(
      presets: {
        'Bicicleta': CategoryPreset(
          category: 'Bicicleta',
          defaultPrice: 15.0,
          defaultMinutes: 30,
        ),
        'Carrinho': CategoryPreset(
          category: 'Carrinho',
          defaultPrice: 25.0,
          defaultMinutes: 30,
        ),
        'Outro': CategoryPreset(
          category: 'Outro',
          defaultPrice: 20.0,
          defaultMinutes: 30,
        ),
      },
      themeMode: ThemeMode.dark,
      isLoaded: false,
    );
  }

  CategoryPreset presetFor(String category) {
    if ((category == 'Bike' || category == 'Bicicleta') &&
        presets.containsKey('Bicicleta')) {
      return presets['Bicicleta']!;
    }
    return presets[category] ??
        presets['Bicicleta'] ??
        const CategoryPreset(
          category: 'Outro',
          defaultPrice: 20.0,
          defaultMinutes: 30,
        );
  }

  AppSettingsState copyWith({
    Map<String, CategoryPreset>? presets,
    ThemeMode? themeMode,
    bool? isLoaded,
  }) {
    return AppSettingsState(
      presets: presets != null ? Map.unmodifiable(presets) : this.presets,
      themeMode: themeMode ?? this.themeMode,
      isLoaded: isLoaded ?? this.isLoaded,
    );
  }
}

class SettingsController extends Notifier<AppSettingsState> {
  static const List<String> categories = ['Bicicleta', 'Carrinho', 'Outro'];

  @override
  AppSettingsState build() {
    _loadFromPrefs();
    return AppSettingsState.initial();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = Map<String, CategoryPreset>.from(state.presets);

      for (final cat in categories) {
        var price = prefs.getDouble('preset_price_$cat');
        var mins = prefs.getInt('preset_minutes_$cat');
        if (cat == 'Bicicleta') {
          price ??= prefs.getDouble('preset_price_Bike');
          mins ??= prefs.getInt('preset_minutes_Bike');
        }
        final existing = current[cat]!;
        current[cat] = existing.copyWith(
          defaultPrice: price ?? existing.defaultPrice,
          defaultMinutes: mins ?? existing.defaultMinutes,
        );
      }

      final isDark = prefs.getBool('app_dark_mode') ?? true;
      state = state.copyWith(
        presets: current,
        themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
        isLoaded: true,
      );
    } catch (_) {
      state = state.copyWith(isLoaded: true);
    }
  }

  Future<void> updateCategoryPreset({
    required String category,
    required double defaultPrice,
    required int defaultMinutes,
  }) async {
    final sanitizedPrice = defaultPrice < 0 ? 0.0 : defaultPrice;
    final sanitizedMinutes = defaultMinutes < 1 ? 1 : defaultMinutes;

    final updatedMap = Map<String, CategoryPreset>.from(state.presets);
    updatedMap[category] = CategoryPreset(
      category: category,
      defaultPrice: sanitizedPrice,
      defaultMinutes: sanitizedMinutes,
    );

    state = state.copyWith(presets: updatedMap);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('preset_price_$category', sanitizedPrice);
      await prefs.setInt('preset_minutes_$category', sanitizedMinutes);
    } catch (_) {}
  }

  Future<void> saveAllPresets(Map<String, CategoryPreset> newPresets) async {
    state = state.copyWith(presets: newPresets);
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final entry in newPresets.entries) {
        await prefs.setDouble(
          'preset_price_${entry.key}',
          entry.value.defaultPrice,
        );
        await prefs.setInt(
          'preset_minutes_${entry.key}',
          entry.value.defaultMinutes,
        );
      }
    } catch (_) {}
  }

  Future<void> toggleThemeMode(bool isDark) async {
    state = state.copyWith(
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('app_dark_mode', isDark);
    } catch (_) {}
  }
}

final settingsControllerProvider =
    NotifierProvider<SettingsController, AppSettingsState>(
      SettingsController.new,
    );
