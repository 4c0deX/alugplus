import 'package:alugplus/core/constants/app_colors.dart';
import 'package:alugplus/core/utils/time_utils.dart';
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
    test('Paleta fixa possui exatamente as 30 cores hexadecimais distintas', () {
      expect(AppColors.itemColorPalette.length, 30);
      expect(AppColors.itemColorPalette.toSet().length, 30);
      expect(AppColors.itemColorPalette.first, '#E53935');
      expect(AppColors.itemColorPalette.last, '#263238');
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
