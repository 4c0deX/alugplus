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

  static const int maxCompletedRentals = 200;

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
    _database = await _initDatabase();
    return _database!;
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
      onOpen: (db) async {
        await db.execute("UPDATE items SET type = 'Bicicleta' WHERE type = 'Bike'");
      },
      onCreate: (db, version) async {
        await db.transaction((txn) async {
          await txn.execute(DatabaseMigrations.createItemsTable);
          await txn.execute(DatabaseMigrations.createRentalsTable);
          await txn.execute(DatabaseMigrations.createDailyFinancialStatsTable);
          await txn.execute(
            'CREATE INDEX idx_rentals_status ON rentals(status);',
          );
          await txn.execute(
            'CREATE INDEX idx_rentals_start_time ON rentals(start_time);',
          );
          await txn.execute(
            'CREATE INDEX idx_rentals_created_date ON rentals(created_date);',
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
      final Map<String, dynamic> hourlyMap = {
        slotKey: {
          'count': 1,
          'revenue': amountPaid,
        },
        '_categories': {itemCategory: 1},
        '_items': {itemName: 1},
      };

      await txn.insert('daily_financial_stats', {
        'date': dateKey,
        'total_rentals_count': 1,
        'total_revenue': amountPaid,
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
        'revenue': slotRevenue + amountPaid,
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
          'total_revenue': currentRevenue + amountPaid,
          'hourly_data': jsonEncode(hourlyMap),
          'is_closed': 0,
        },
        where: 'date = ?',
        whereArgs: [dateKey],
      );
    }
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
