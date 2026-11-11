import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_helper.dart';

@immutable
class HourlyMetric {
  final String slot; // Ex: "18-19"
  final int count;
  final double revenue;

  const HourlyMetric({
    required this.slot,
    required this.count,
    required this.revenue,
  });
}

@immutable
class DailyArchiveRecord {
  final String date;
  final int totalRentalsCount;
  final double totalRevenue;
  final bool isClosed;

  const DailyArchiveRecord({
    required this.date,
    required this.totalRentalsCount,
    required this.totalRevenue,
    required this.isClosed,
  });
}

@immutable
class FinancialState {
  final String todayDate;
  final int currentShiftRentalsCount;
  final double currentShiftRevenue;
  final int consolidatedDayCount;
  final double consolidatedDayRevenue;
  final bool isDayClosed;
  final List<HourlyMetric> hourlyMetrics;
  final Map<String, int> categoryRanking;
  final Map<String, int> itemRanking;
  final List<DailyArchiveRecord> historyDays;
  final bool isLoading;

  const FinancialState({
    required this.todayDate,
    this.currentShiftRentalsCount = 0,
    this.currentShiftRevenue = 0.0,
    this.consolidatedDayCount = 0,
    this.consolidatedDayRevenue = 0.0,
    this.isDayClosed = false,
    this.hourlyMetrics = const [],
    this.categoryRanking = const {},
    this.itemRanking = const {},
    this.historyDays = const [],
    this.isLoading = false,
  });

  FinancialState copyWith({
    String? todayDate,
    int? currentShiftRentalsCount,
    double? currentShiftRevenue,
    int? consolidatedDayCount,
    double? consolidatedDayRevenue,
    bool? isDayClosed,
    List<HourlyMetric>? hourlyMetrics,
    Map<String, int>? categoryRanking,
    Map<String, int>? itemRanking,
    List<DailyArchiveRecord>? historyDays,
    bool? isLoading,
  }) {
    return FinancialState(
      todayDate: todayDate ?? this.todayDate,
      currentShiftRentalsCount:
          currentShiftRentalsCount ?? this.currentShiftRentalsCount,
      currentShiftRevenue: currentShiftRevenue ?? this.currentShiftRevenue,
      consolidatedDayCount: consolidatedDayCount ?? this.consolidatedDayCount,
      consolidatedDayRevenue:
          consolidatedDayRevenue ?? this.consolidatedDayRevenue,
      isDayClosed: isDayClosed ?? this.isDayClosed,
      hourlyMetrics: hourlyMetrics != null
          ? List.unmodifiable(hourlyMetrics)
          : this.hourlyMetrics,
      categoryRanking: categoryRanking != null
          ? Map.unmodifiable(categoryRanking)
          : this.categoryRanking,
      itemRanking: itemRanking != null
          ? Map.unmodifiable(itemRanking)
          : this.itemRanking,
      historyDays: historyDays != null
          ? List.unmodifiable(historyDays)
          : this.historyDays,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class FinancialController extends Notifier<FinancialState> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  @override
  FinancialState build() {
    Future.microtask(loadFinancialStats);
    return FinancialState(
      todayDate: _dbHelper.todayDateKey,
      isLoading: true,
    );
  }

  Future<void> loadFinancialStats() async {
    state = state.copyWith(isLoading: true);
    try {
      final db = await _dbHelper.database;
      final todayKey = _dbHelper.todayDateKey;

      final todayRows = await db.query(
        'daily_financial_stats',
        where: 'date = ?',
        whereArgs: [todayKey],
        limit: 1,
      );

      int consolidatedCount = 0;
      double consolidatedRev = 0.0;
      int shiftCount = 0;
      double shiftRev = 0.0;
      bool isClosed = false;
      final List<HourlyMetric> parsedHourly = [];
      final Map<String, int> parsedCategories = {};
      final Map<String, int> parsedItems = {};

      if (todayRows.isNotEmpty) {
        final row = todayRows.first;
        consolidatedCount = (row['total_rentals_count'] as num?)?.toInt() ?? 0;
        consolidatedRev = (row['total_revenue'] as num?)?.toDouble() ?? 0.0;
        isClosed = ((row['is_closed'] as num?)?.toInt() ?? 0) == 1;

        final rawHourly = row['hourly_data'] as String?;
        Map<String, dynamic> hourlyMap = {};
        if (rawHourly != null && rawHourly.isNotEmpty) {
          try {
            hourlyMap = Map<String, dynamic>.from(jsonDecode(rawHourly) as Map);
          } catch (_) {
            hourlyMap = {};
          }
        }

        final baselineCount =
            (hourlyMap['_shift_baseline_count'] as num?)?.toInt() ?? 0;
        final baselineRevenue =
            (hourlyMap['_shift_baseline_revenue'] as num?)?.toDouble() ?? 0.0;

        shiftCount = (consolidatedCount - baselineCount).clamp(
          0,
          consolidatedCount,
        );
        shiftRev = (consolidatedRev - baselineRevenue) < 0
            ? 0.0
            : (consolidatedRev - baselineRevenue);

        for (final entry in hourlyMap.entries) {
          if (entry.key.startsWith('_')) continue;
          if (entry.value is Map) {
            final mapVal = entry.value as Map;
            parsedHourly.add(
              HourlyMetric(
                slot: entry.key,
                count: (mapVal['count'] as num?)?.toInt() ?? 0,
                revenue: (mapVal['revenue'] as num?)?.toDouble() ?? 0.0,
              ),
            );
          }
        }
        parsedHourly.sort((a, b) => a.slot.compareTo(b.slot));

        if (hourlyMap['_categories'] is Map) {
          final catMap = hourlyMap['_categories'] as Map;
          for (final entry in catMap.entries) {
            parsedCategories[entry.key.toString()] =
                (entry.value as num?)?.toInt() ?? 0;
          }
        }

        if (hourlyMap['_items'] is Map) {
          final itemMap = hourlyMap['_items'] as Map;
          for (final entry in itemMap.entries) {
            parsedItems[entry.key.toString()] =
                (entry.value as num?)?.toInt() ?? 0;
          }
        }
      }

      // Ordena rankings de forma decrescente
      final sortedCategories = Map.fromEntries(
        parsedCategories.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)),
      );
      final sortedItems = Map.fromEntries(
        parsedItems.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)),
      );

      // Carrega histórico dos últimos dias consolidados em daily_financial_stats
      final allStatsRows = await db.query(
        'daily_financial_stats',
        orderBy: 'date DESC',
        limit: 30,
      );
      final archiveList = allStatsRows.map((r) {
        return DailyArchiveRecord(
          date: (r['date'] as String?) ?? todayKey,
          totalRentalsCount: (r['total_rentals_count'] as num?)?.toInt() ?? 0,
          totalRevenue: (r['total_revenue'] as num?)?.toDouble() ?? 0.0,
          isClosed: ((r['is_closed'] as num?)?.toInt() ?? 0) == 1,
        );
      }).toList(growable: false);

      state = state.copyWith(
        todayDate: todayKey,
        currentShiftRentalsCount: shiftCount,
        currentShiftRevenue: shiftRev,
        consolidatedDayCount: consolidatedCount,
        consolidatedDayRevenue: consolidatedRev,
        isDayClosed: isClosed,
        hourlyMetrics: parsedHourly,
        categoryRanking: sortedCategories,
        itemRanking: sortedItems,
        historyDays: archiveList,
        isLoading: false,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Consolida os números em daily_financial_stats com flag is_closed = 1
  /// e reinicia o painel para um novo expediente.
  Future<void> resetAndCloseDay() async {
    final todayKey = _dbHelper.todayDateKey;
    await _dbHelper.closeAndResetDailyStats(todayKey);
    await loadFinancialStats();
  }

  /// Remove todos os registros isolados de fechamentos diários em daily_financial_stats
  Future<void> clearAllDailyFinancialStats() async {
    await _dbHelper.clearAllDailyFinancialStats();
    await loadFinancialStats();
  }
}

final financialControllerProvider =
    NotifierProvider<FinancialController, FinancialState>(
      FinancialController.new,
    );
