import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../utils/formatters.dart';
import '../utils/time_utils.dart';
import 'migrations.dart';

class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();
  static Database? _database;
  static Completer<Database>? _dbInitCompleter;

  static const int maxCompletedRentals = 200;

  static double roundCurrency(double val) {
    if (val < 0.005) return 0.0;
    return (val * 100).roundToDouble() / 100.0;
  }

  /// Garante que o driver FFI esteja inicializado em plataformas Desktop.
  static void ensurePlatformInitialized() {
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) {
      return _database!;
    }
    if (_dbInitCompleter != null) {
      return _dbInitCompleter!.future;
    }
    _dbInitCompleter = Completer<Database>();
    try {
      _database = await _initDatabase();
      _dbInitCompleter!.complete(_database!);
      _dbInitCompleter = null;
      return _database!;
    } catch (e) {
      _dbInitCompleter!.completeError(e);
      _dbInitCompleter = null;
      rethrow;
    }
  }

  Future<Database> _initDatabase() async {
    ensurePlatformInitialized();

    Directory dbDirectory;
    try {
      dbDirectory = await getApplicationDocumentsDirectory();
    } catch (_) {
      final dbPath = await getDatabasesPath();
      dbDirectory = Directory(dbPath);
    }

    final targetDir = Directory(p.join(dbDirectory.path, 'alugplus_data'));
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final fullPath = p.join(targetDir.path, DatabaseMigrations.databaseName);

    return openDatabase(
      fullPath,
      version: DatabaseMigrations.databaseVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            "UPDATE items SET type = 'Bicicleta' WHERE type = 'Bike'",
          );
          final columns = await db.rawQuery('PRAGMA table_info(rentals)');
          final hasManualSurcharge = columns.any(
            (col) => col['name'] == 'is_manual_surcharge',
          );
          if (!hasManualSurcharge) {
            await db.execute(
              'ALTER TABLE rentals ADD COLUMN is_manual_surcharge INTEGER DEFAULT 0;',
            );
          }
          await db.execute(
            "CREATE UNIQUE INDEX IF NOT EXISTS idx_rentals_unique_active_item ON rentals(item_id) WHERE status = 'active';",
          );
        }
      },
      onOpen: (db) async {
        await db.execute(
          "UPDATE items SET type = 'Bicicleta' WHERE type = 'Bike'",
        );
        await db.execute(
          "CREATE UNIQUE INDEX IF NOT EXISTS idx_rentals_unique_active_item ON rentals(item_id) WHERE status = 'active';",
        );
      },
      onCreate: (db, version) async {
        await db.transaction((txn) async {
          await txn.execute(DatabaseMigrations.createItemsTable);
          await txn.execute(DatabaseMigrations.createRentalsTable);
          await txn.execute(DatabaseMigrations.createDailyFinancialStatsTable);
          await txn.execute(
            'CREATE INDEX IF NOT EXISTS idx_rentals_status ON rentals(status);',
          );
          await txn.execute(
            'CREATE INDEX IF NOT EXISTS idx_rentals_start_time ON rentals(start_time);',
          );
          await txn.execute(
            'CREATE INDEX IF NOT EXISTS idx_rentals_created_date ON rentals(created_date);',
          );
          await txn.execute(
            "CREATE UNIQUE INDEX IF NOT EXISTS idx_rentals_unique_active_item ON rentals(item_id) WHERE status = 'active';",
          );
          await txn.execute(DatabaseMigrations.createRetentionTrigger);

          for (final item in DatabaseMigrations.initialSeedItems) {
            await txn.insert('items', item);
          }
        });
      },
    );
  }

  /// Registra um aluguel finalizado na tabela [daily_financial_stats] dentro da transação,
  /// garantindo isolamento de métricas antes de qualquer expurgo da tabela [rentals].
  Future<void> recordRentalInFinancialStatsTxn({
    required Transaction txn,
    required String dateKey,
    required DateTime rentalStartTime,
    required double amountPaid,
    required String itemCategory,
    required String itemName,
  }) async {
    final rows = await txn.query(
      'daily_financial_stats',
      where: 'date = ?',
      whereArgs: [dateKey],
      limit: 1,
    );

    final slotKey = TimeUtils.hourlySlotKey(rentalStartTime);

    if (rows.isEmpty) {
      final roundedAmount = roundCurrency(amountPaid);
      final Map<String, dynamic> hourlyMap = {
        slotKey: {
          'count': 1,
          'revenue': roundedAmount,
        },
        '_categories': {itemCategory: 1},
        '_items': {itemName: 1},
      };

      await txn.insert('daily_financial_stats', {
        'date': dateKey,
        'total_rentals_count': 1,
        'total_revenue': roundedAmount,
        'hourly_data': jsonEncode(hourlyMap),
        'is_closed': 0,
      });
    } else {
      final current = rows.first;
      final currentCount = (current['total_rentals_count'] as num?)?.toInt() ?? 0;
      final currentRevenue =
          (current['total_revenue'] as num?)?.toDouble() ?? 0.0;
      final rawHourly = current['hourly_data'] as String?;

      Map<String, dynamic> hourlyMap = {};
      if (rawHourly != null && rawHourly.isNotEmpty) {
        try {
          hourlyMap = Map<String, dynamic>.from(jsonDecode(rawHourly) as Map);
        } catch (_) {
          hourlyMap = {};
        }
      }

      // Se o dia havia sido fechado anteriormente e um novo expediente se iniciou,
      // reabre o indicador de expediente ativo mantendo os dados históricos íntegros.
      final slotEntry = hourlyMap[slotKey];
      int slotCount = 0;
      double slotRevenue = 0.0;
      if (slotEntry is Map) {
        slotCount = (slotEntry['count'] as num?)?.toInt() ?? 0;
        slotRevenue = (slotEntry['revenue'] as num?)?.toDouble() ?? 0.0;
      }
      hourlyMap[slotKey] = {
        'count': slotCount + 1,
        'revenue': roundCurrency(slotRevenue + amountPaid),
      };

      final categoriesMap = hourlyMap['_categories'] is Map
          ? Map<String, dynamic>.from(hourlyMap['_categories'] as Map)
          : <String, dynamic>{};
      categoriesMap[itemCategory] =
          ((categoriesMap[itemCategory] as num?)?.toInt() ?? 0) + 1;
      hourlyMap['_categories'] = categoriesMap;

      final itemsMap = hourlyMap['_items'] is Map
          ? Map<String, dynamic>.from(hourlyMap['_items'] as Map)
          : <String, dynamic>{};
      itemsMap[itemName] = ((itemsMap[itemName] as num?)?.toInt() ?? 0) + 1;
      hourlyMap['_items'] = itemsMap;

      await txn.update(
        'daily_financial_stats',
        {
          'total_rentals_count': currentCount + 1,
          'total_revenue': roundCurrency(currentRevenue + amountPaid),
          'hourly_data': jsonEncode(hourlyMap),
          'is_closed': 0,
        },
        where: 'date = ?',
        whereArgs: [dateKey],
      );
    }
  }

  /// Remove completamente o rastro financeiro de um aluguel concluído em [daily_financial_stats].
  Future<void> revertRentalFromFinancialStatsTxn({
    required Transaction txn,
    required String primaryDateKey,
    required String fallbackDateKey,
    required DateTime rentalStartTime,
    DateTime? rentalCompletedAt,
    required double amountPaid,
    required String itemCategory,
    required String itemName,
  }) async {
    var rows = await txn.query(
      'daily_financial_stats',
      where: 'date = ?',
      whereArgs: [primaryDateKey],
      limit: 1,
    );
    String targetDateKey = primaryDateKey;

    if (rows.isEmpty && fallbackDateKey != primaryDateKey) {
      rows = await txn.query(
        'daily_financial_stats',
        where: 'date = ?',
        whereArgs: [fallbackDateKey],
        limit: 1,
      );
      targetDateKey = fallbackDateKey;
    }

    if (rows.isEmpty) return;

    final current = rows.first;
    final currentCount = (current['total_rentals_count'] as num?)?.toInt() ?? 0;
    final currentRevenue =
        (current['total_revenue'] as num?)?.toDouble() ?? 0.0;
    final rawHourly = current['hourly_data'] as String?;

    final newCount = (currentCount - 1).clamp(0, 999999);
    final newRevenue = roundCurrency(currentRevenue - amountPaid);

    Map<String, dynamic> hourlyMap = {};
    if (rawHourly != null && rawHourly.isNotEmpty) {
      try {
        hourlyMap = Map<String, dynamic>.from(jsonDecode(rawHourly) as Map);
      } catch (_) {
        hourlyMap = {};
      }
    }

    final isClosed = ((current['is_closed'] as num?)?.toInt() ?? 0) == 1;
    final hasClosedSnapshot =
        hourlyMap['_closed_hourly_snapshot'] != null ||
        hourlyMap['_shift_baseline_count'] != null;

    if (newCount <= 0) {
      if (isClosed || hasClosedSnapshot) {
        final keysToRemove = hourlyMap.keys
            .where((k) => !k.startsWith('_'))
            .toList();
        for (final k in keysToRemove) {
          hourlyMap.remove(k);
        }
        hourlyMap['_shift_baseline_count'] = 0;
        hourlyMap['_shift_baseline_revenue'] = 0.0;
        hourlyMap['_closed_hourly_snapshot'] = <String, dynamic>{};
        hourlyMap['_closed_categories_snapshot'] = <String, dynamic>{};
        hourlyMap['_closed_items_snapshot'] = <String, dynamic>{};
        hourlyMap['_categories'] = <String, dynamic>{};
        hourlyMap['_items'] = <String, dynamic>{};
        await txn.update(
          'daily_financial_stats',
          {
            'total_rentals_count': 0,
            'total_revenue': 0.0,
            'hourly_data': jsonEncode(hourlyMap),
          },
          where: 'date = ?',
          whereArgs: [targetDateKey],
        );
      } else {
        await txn.update(
          'daily_financial_stats',
          {
            'total_rentals_count': 0,
            'total_revenue': 0.0,
            'hourly_data': jsonEncode(<String, dynamic>{}),
          },
          where: 'date = ?',
          whereArgs: [targetDateKey],
        );
      }
      return;
    }

    final slotKey = TimeUtils.hourlySlotKey(rentalStartTime);
    final closedAtStr = hourlyMap['_shift_closed_at'] as String?;
    final closedAt = closedAtStr != null ? DateTime.tryParse(closedAtStr) : null;
    final effectiveCompletedAt = rentalCompletedAt ?? rentalStartTime;
    final isPriorToClosure =
        closedAt != null && effectiveCompletedAt.isBefore(closedAt);

    final slotEntry = hourlyMap[slotKey];
    if (!isPriorToClosure && slotEntry is Map) {
      final slotCount =
          (((slotEntry['count'] as num?)?.toInt() ?? 1) - 1).clamp(0, 999999);
      final slotRev = roundCurrency(
        ((slotEntry['revenue'] as num?)?.toDouble() ?? 0.0) - amountPaid,
      );
      if (slotCount <= 0) {
        hourlyMap.remove(slotKey);
      } else {
        hourlyMap[slotKey] = {
          'count': slotCount,
          'revenue': slotRev,
        };
      }

      if (hourlyMap['_categories'] is Map) {
        final catMap = Map<String, dynamic>.from(
          hourlyMap['_categories'] as Map,
        );
        final prev = (catMap[itemCategory] as num?)?.toInt() ?? 0;
        if (prev <= 1) {
          catMap.remove(itemCategory);
        } else {
          catMap[itemCategory] = prev - 1;
        }
        hourlyMap['_categories'] = catMap;
      }

      if (hourlyMap['_items'] is Map) {
        final itemsMap = Map<String, dynamic>.from(hourlyMap['_items'] as Map);
        final prev = (itemsMap[itemName] as num?)?.toInt() ?? 0;
        if (prev <= 1) {
          itemsMap.remove(itemName);
        } else {
          itemsMap[itemName] = prev - 1;
        }
        hourlyMap['_items'] = itemsMap;
      }
    } else if (hourlyMap['_shift_baseline_count'] != null) {
      final baseCount =
          (((hourlyMap['_shift_baseline_count'] as num?)?.toInt() ?? 1) - 1)
              .clamp(0, 999999);
      final baseRev = roundCurrency(
        ((hourlyMap['_shift_baseline_revenue'] as num?)?.toDouble() ?? 0.0) -
            amountPaid,
      );
      hourlyMap['_shift_baseline_count'] = baseCount;
      hourlyMap['_shift_baseline_revenue'] = baseRev;

      if (hourlyMap['_closed_hourly_snapshot'] is Map) {
        final closedSnapshot = Map<String, dynamic>.from(
          hourlyMap['_closed_hourly_snapshot'] as Map,
        );
        if (closedSnapshot[slotKey] is Map) {
          final slot = Map<String, dynamic>.from(
            closedSnapshot[slotKey] as Map,
          );
          final c = ((slot['count'] as num?)?.toInt() ?? 1) - 1;
          final r = roundCurrency(
            ((slot['revenue'] as num?)?.toDouble() ?? 0.0) - amountPaid,
          );
          if (c <= 0) {
            closedSnapshot.remove(slotKey);
          } else {
            closedSnapshot[slotKey] = {'count': c, 'revenue': r};
          }
          hourlyMap['_closed_hourly_snapshot'] = closedSnapshot;
        }
      }
    }

    await txn.update(
      'daily_financial_stats',
      {
        'total_rentals_count': newCount,
        'total_revenue': newRevenue,
        'hourly_data': jsonEncode(hourlyMap),
      },
      where: 'date = ?',
      whereArgs: [targetDateKey],
    );
  }

  /// Ajusta a receita financeira em [daily_financial_stats] quando o operador
  /// edita o valor pago de um aluguel recente no Histórico.
  Future<void> adjustRentalRevenueInFinancialStatsTxn({
    required Transaction txn,
    required String primaryDateKey,
    required String fallbackDateKey,
    required DateTime rentalStartTime,
    required double oldAmountPaid,
    required double newAmountPaid,
  }) async {
    final delta = newAmountPaid - oldAmountPaid;
    if (delta.abs() < 0.001) return;

    var rows = await txn.query(
      'daily_financial_stats',
      where: 'date = ?',
      whereArgs: [primaryDateKey],
      limit: 1,
    );
    String targetDateKey = primaryDateKey;

    if (rows.isEmpty && fallbackDateKey != primaryDateKey) {
      rows = await txn.query(
        'daily_financial_stats',
        where: 'date = ?',
        whereArgs: [fallbackDateKey],
        limit: 1,
      );
      targetDateKey = fallbackDateKey;
    }

    if (rows.isEmpty) return;

    final current = rows.first;
    final currentRevenue =
        (current['total_revenue'] as num?)?.toDouble() ?? 0.0;
    final rawHourly = current['hourly_data'] as String?;

    final newRevenue = roundCurrency(currentRevenue + delta);

    Map<String, dynamic> hourlyMap = {};
    if (rawHourly != null && rawHourly.isNotEmpty) {
      try {
        hourlyMap = Map<String, dynamic>.from(jsonDecode(rawHourly) as Map);
      } catch (_) {
        hourlyMap = {};
      }
    }

    final slotKey = TimeUtils.hourlySlotKey(rentalStartTime);
    final slotEntry = hourlyMap[slotKey];
    if (slotEntry is Map) {
      final slotCount = (slotEntry['count'] as num?)?.toInt() ?? 1;
      final rawSlotRev =
          ((slotEntry['revenue'] as num?)?.toDouble() ?? 0.0) + delta;
      hourlyMap[slotKey] = {
        'count': slotCount,
        'revenue': roundCurrency(rawSlotRev),
      };
    } else if (hourlyMap['_shift_baseline_revenue'] != null) {
      final rawBaseRev =
          ((hourlyMap['_shift_baseline_revenue'] as num?)?.toDouble() ?? 0.0) +
          delta;
      hourlyMap['_shift_baseline_revenue'] = roundCurrency(rawBaseRev);
    }

    await txn.update(
      'daily_financial_stats',
      {
        'total_revenue': newRevenue,
        'hourly_data': jsonEncode(hourlyMap),
      },
      where: 'date = ?',
      whereArgs: [targetDateKey],
    );
  }

  /// Regra de Retenção de 200 Aluguéis:
  /// Verifica a contagem de registros na tabela `rentals` com status 'completed'.
  /// Se ultrapassar 200, remove fisicamente os mais antigos.
  Future<void> enforceRetentionLimitTxn(Transaction txn) async {
    final countResult = await txn.rawQuery(
      "SELECT COUNT(*) as total FROM rentals WHERE status = 'completed'",
    );
    final totalCompleted =
        (countResult.firstOrNull?['total'] as num?)?.toInt() ?? 0;

    if (totalCompleted > maxCompletedRentals) {
      final excessCount = totalCompleted - maxCompletedRentals;
      await txn.rawDelete(
        "DELETE FROM rentals WHERE id IN ("
        "SELECT id FROM rentals WHERE status = 'completed' "
        "ORDER BY start_time ASC LIMIT ?"
        ")",
        [excessCount],
      );
    }
  }

  /// Consolida e fecha o expediente do dia em [daily_financial_stats],
  /// preservando o histórico consolidado e preparando o painel para novo expediente.
  Future<void> closeAndResetDailyStats(String dateKey) async {
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'daily_financial_stats',
        where: 'date = ?',
        whereArgs: [dateKey],
        limit: 1,
      );

      if (rows.isEmpty) {
        final emptyHourly = <String, dynamic>{
          '_shift_baseline_count': 0,
          '_shift_baseline_revenue': 0.0,
          '_shift_closed_at': DateTime.now().toIso8601String(),
        };
        await txn.insert('daily_financial_stats', {
          'date': dateKey,
          'total_rentals_count': 0,
          'total_revenue': 0.0,
          'hourly_data': jsonEncode(emptyHourly),
          'is_closed': 1,
        });
      } else {
        final row = rows.first;
        final totalCount = (row['total_rentals_count'] as num?)?.toInt() ?? 0;
        final totalRevenue =
            (row['total_revenue'] as num?)?.toDouble() ?? 0.0;
        final rawHourly = row['hourly_data'] as String?;

        Map<String, dynamic> hourlyMap = {};
        if (rawHourly != null && rawHourly.isNotEmpty) {
          try {
            hourlyMap = Map<String, dynamic>.from(jsonDecode(rawHourly) as Map);
          } catch (_) {
            hourlyMap = {};
          }
        }

        // Arquiva os dados horários acumulados até o fechamento e reinicia os slots do novo turno,
        // mantendo total_rentals_count e total_revenue consolidados no registro com is_closed = 1.
        final closedSnapshot = <String, dynamic>{};
        final keysToReset = <String>[];
        for (final entry in hourlyMap.entries) {
          if (!entry.key.startsWith('_')) {
            closedSnapshot[entry.key] = entry.value;
            keysToReset.add(entry.key);
          }
        }
        for (final k in keysToReset) {
          hourlyMap.remove(k);
        }

        hourlyMap['_closed_hourly_snapshot'] = closedSnapshot;
        hourlyMap['_closed_categories_snapshot'] =
            hourlyMap['_categories'] ?? <String, dynamic>{};
        hourlyMap['_closed_items_snapshot'] =
            hourlyMap['_items'] ?? <String, dynamic>{};
        hourlyMap['_categories'] = <String, dynamic>{};
        hourlyMap['_items'] = <String, dynamic>{};
        hourlyMap['_shift_baseline_count'] = totalCount;
        hourlyMap['_shift_baseline_revenue'] = totalRevenue;
        hourlyMap['_shift_closed_at'] = DateTime.now().toIso8601String();

        await txn.update(
          'daily_financial_stats',
          {
            'hourly_data': jsonEncode(hourlyMap),
            'is_closed': 1,
          },
          where: 'date = ?',
          whereArgs: [dateKey],
        );
      }
    });
  }

  /// Remove todos os registros da tabela daily_financial_stats
  Future<void> clearAllDailyFinancialStats() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('daily_financial_stats');
    });
  }

  /// Reseta completamente o banco de dados do aplicativo para o estado original de fábrica:
  /// - Exclui todos os aluguéis (rentals)
  /// - Exclui todas as estatísticas diárias (daily_financial_stats)
  /// - Restaura os itens originais padrão do catálogo (items)
  Future<void> resetEntireAppDatabase() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('rentals');
      await txn.delete('daily_financial_stats');
      await txn.delete('items');
      for (final item in DatabaseMigrations.initialSeedItems) {
        await txn.insert('items', item);
      }
    });
  }

  /// Helper para obter a data atual formatada YYYY-MM-DD.
  String get todayDateKey => AppFormatters.sqlDate(DateTime.now());
}
