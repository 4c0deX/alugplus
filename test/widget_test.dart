import 'package:alugplus/core/constants/app_colors.dart';
import 'package:alugplus/core/database/migrations.dart';
import 'package:alugplus/core/utils/formatters.dart';
import 'package:alugplus/core/utils/time_utils.dart';
import 'package:alugplus/features/rentals/models/rental_model.dart';
import 'package:alugplus/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Regras de Negócio • Paleta e Tempo/Acréscimo', () {
    test('Paleta expandida possui exatamente as 70 cores hexadecimais distintas', () {
      expect(AppColors.itemColorPalette.length, 70);
      expect(AppColors.itemColorPalette.toSet().length, 70);
      expect(AppColors.itemColorPalette.first, '#E53935');
      expect(AppColors.itemColorPalette.last, '#4F46E5');
    });

    test('Cálculo de progresso e acréscimo após 3 min de tolerância', () {
      final start = DateTime(2026, 11, 9, 18, 0, 0);
      final plannedEnd = DateTime(2026, 11, 9, 18, 30, 0);

      // Metade do tempo (15 min) -> progresso 0.5
      final halfTime = DateTime(2026, 11, 9, 18, 15, 0);
      expect(
        TimeUtils.calculateProgress(
          startTime: start,
          plannedEndTime: plannedEnd,
          currentTime: halfTime,
        ),
        closeTo(0.5, 0.001),
      );

      // Até 3 minutos de atraso -> tolerância (R$ 0,00)
      final toleranceTime = DateTime(2026, 11, 9, 18, 33, 59);
      expect(
        TimeUtils.calculateSurcharge(
          plannedEndTime: plannedEnd,
          currentTime: toleranceTime,
        ),
        0.0,
      );

      // No 4º minuto exato de atraso -> R$ 1,00
      final fourthMinute = DateTime(2026, 11, 9, 18, 34, 0);
      expect(
        TimeUtils.hasSurchargeStarted(
          plannedEndTime: plannedEnd,
          currentTime: fourthMinute,
        ),
        isTrue,
      );
      expect(
        TimeUtils.calculateSurcharge(
          plannedEndTime: plannedEnd,
          currentTime: fourthMinute,
        ),
        1.0,
      );

      // No 6º minuto de atraso (2 minutos adicionais além do 4º) -> R$ 3,00
      final sixthMinute = DateTime(2026, 11, 9, 18, 36, 0);
      expect(
        TimeUtils.calculateSurcharge(
          plannedEndTime: plannedEnd,
          currentTime: sixthMinute,
        ),
        3.0,
      );

      // Testando alteração dinâmica para iniciar no 5º minuto ou 3º minuto
      TimeUtils.surchargeTriggerMinute = 5;
      expect(TimeUtils.toleranceMinutes, 4);
      expect(
        TimeUtils.calculateSurcharge(
          plannedEndTime: plannedEnd,
          currentTime: fourthMinute,
        ),
        0.0,
      );
      expect(
        TimeUtils.calculateSurcharge(
          plannedEndTime: plannedEnd,
          currentTime: DateTime(2026, 11, 9, 18, 35, 0),
        ),
        1.0,
      );

      TimeUtils.surchargeTriggerMinute = 3;
      expect(TimeUtils.toleranceMinutes, 2);
      expect(
        TimeUtils.calculateSurcharge(
          plannedEndTime: plannedEnd,
          currentTime: DateTime(2026, 11, 9, 18, 33, 0),
        ),
        1.0,
      );

      // Restaura padrão 4
      TimeUtils.surchargeTriggerMinute = 4;
    });

    test('Avaliação didática de expressões de tempo (+, - e cálculos compostos)', () {
      expect(TimeUtils.evaluateMinutesExpression('15'), 15);
      expect(TimeUtils.evaluateMinutesExpression('+15'), 15);
      expect(TimeUtils.evaluateMinutesExpression('-10'), -10);
      expect(TimeUtils.evaluateMinutesExpression('10+20+5'), 35);
      expect(TimeUtils.evaluateMinutesExpression('30-10+5'), 25);
      expect(TimeUtils.evaluateMinutesExpression('-15+5'), -10);
      expect(TimeUtils.evaluateMinutesExpression('  10 + 20 + 5  '), 35);
      expect(TimeUtils.evaluateMinutesExpression(''), isNull);
      expect(TimeUtils.evaluateMinutesExpression('abc'), isNull);
      expect(TimeUtils.evaluateMinutesExpression('10++5'), isNull);
    });

    test('Formatação de moeda brasileira com separador de milhar (BUG-HIGH-06)', () {
      expect(AppFormatters.parseCurrency('15,00'), 15.0);
      expect(AppFormatters.parseCurrency('R\$ 1.250,00'), 1250.0);
      expect(AppFormatters.parseCurrency('1.250,50'), 1250.5);
      expect(AppFormatters.parseCurrency('1,250.50'), 1250.5);
      expect(AppFormatters.parseCurrency('1.000.000'), 1000000.0);
    });

    test('Proteção de integridade no banco: ON DELETE RESTRICT e índice único ativo (BUG-CRIT-01 / BUG-CRIT-02)', () async {
      expect(
        DatabaseMigrations.createRentalsTable.contains('ON DELETE RESTRICT'),
        isTrue,
      );
      expect(
        DatabaseMigrations.createRentalsTable.contains('ON DELETE CASCADE'),
        isFalse,
      );

      final db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: DatabaseMigrations.databaseVersion,
          onConfigure: (db) async => await db.execute('PRAGMA foreign_keys = ON'),
          onCreate: (db, version) async {
            await db.execute(DatabaseMigrations.createItemsTable);
            await db.execute(DatabaseMigrations.createRentalsTable);
            await db.execute(DatabaseMigrations.createDailyFinancialStatsTable);
            await db.execute(
              "CREATE UNIQUE INDEX IF NOT EXISTS idx_rentals_unique_active_item ON rentals(item_id) WHERE status = 'active';",
            );
          },
        ),
      );
      addTearDown(() async => await db.close());

      final itemId = await db.insert('items', {
        'name': 'Bike Teste #01',
        'type': 'Bicicleta',
        'color_hex': '#1E88E5',
        'is_active': 1,
      });

      final nowIso = DateTime.now().toIso8601String();
      await db.insert('rentals', {
        'item_id': itemId,
        'start_time': nowIso,
        'planned_end_time': nowIso,
        'base_price': 20.0,
        'surcharge': 5.0,
        'surcharge_applied': 1,
        'is_manual_surcharge': 1,
        'total_paid': 25.0,
        'status': 'active',
        'created_date': '2026-11-12',
      });

      // BUG-CRIT-02: Impede aluguel simultâneo duplicado para o mesmo item_id ativo
      expect(
        () => db.insert('rentals', {
          'item_id': itemId,
          'start_time': nowIso,
          'planned_end_time': nowIso,
          'base_price': 20.0,
          'total_paid': 20.0,
          'status': 'active',
          'created_date': '2026-11-12',
        }),
        throwsA(isA<DatabaseException>()),
      );

      // BUG-CRIT-01: Impede exclusão física de item que possui aluguéis vinculados
      expect(
        () => db.delete('items', where: 'id = ?', whereArgs: [itemId]),
        throwsA(isA<DatabaseException>()),
      );

      // BUG-HIGH-03: Persistência de is_manual_surcharge no modelo
      final rows = await db.query('rentals', where: 'item_id = ?', whereArgs: [itemId]);
      final model = RentalModel.fromJoinedMap(rows.first);
      expect(model.isManualSurcharge, isTrue);
    });
  });

  testWidgets('Renderiza AlugPlus+ com NavigationBar no mobile (< 720px)', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: AlugPlusApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('AlugPlus+'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('Renderiza AlugPlus+ com NavigationRail em telas largas', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: AlugPlusApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('AlugPlus+'), findsOneWidget);
    expect(find.byType(NavigationRail), findsOneWidget);
  });
}
