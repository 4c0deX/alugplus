import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/time_utils.dart';
import '../../financial/controllers/financial_controller.dart';
import '../models/rental_model.dart';

@immutable
class BatchRentalRequestItem {
  final int itemId;
  final int durationMinutes;
  final double basePrice;

  const BatchRentalRequestItem({
    required this.itemId,
    required this.durationMinutes,
    required this.basePrice,
  });
}

@immutable
class RentalsState {
  final List<RentalModel> activeRentals;
  final List<RentalModel> completedRentals;
  final Set<int> manuallyEditedSurchargeIds;
  final DateTime currentTime;
  final bool isLoading;
  final String? errorMessage;

  const RentalsState({
    this.activeRentals = const [],
    this.completedRentals = const [],
    this.manuallyEditedSurchargeIds = const {},
    required this.currentTime,
    this.isLoading = false,
    this.errorMessage,
  });

  Set<int> get busyItemIds =>
      activeRentals.map((r) => r.itemId).toSet();

  RentalsState copyWith({
    List<RentalModel>? activeRentals,
    List<RentalModel>? completedRentals,
    Set<int>? manuallyEditedSurchargeIds,
    DateTime? currentTime,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return RentalsState(
      activeRentals: activeRentals != null
          ? List.unmodifiable(activeRentals)
          : this.activeRentals,
      completedRentals: completedRentals != null
          ? List.unmodifiable(completedRentals)
          : this.completedRentals,
      manuallyEditedSurchargeIds: manuallyEditedSurchargeIds != null
          ? Set.unmodifiable(manuallyEditedSurchargeIds)
          : this.manuallyEditedSurchargeIds,
      currentTime: currentTime ?? this.currentTime,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class RentalController extends Notifier<RentalsState> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  Timer? _centralTimer;

  // Controle de disparo único de notificações por aluguel ativo
  final Set<int> _notifiedFinishedIds = {};
  final Set<int> _notifiedSurchargeIds = {};

  @override
  RentalsState build() {
    _startCentralTicker();
    ref.onDispose(() {
      _centralTimer?.cancel();
    });
    Future.microtask(loadRentals);
    return RentalsState(
      currentTime: DateTime.now(),
      isLoading: true,
    );
  }

  void _startCentralTicker() {
    _centralTimer?.cancel();
    _centralTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _onTick(DateTime.now());
    });
  }

  void _onTick(DateTime now) {
    if (state.activeRentals.isEmpty) {
      state = state.copyWith(currentTime: now);
      return;
    }

    bool listChanged = false;
    final updatedActive = <RentalModel>[];

    for (final rental in state.activeRentals) {
      final rentalId = rental.id;
      final isFinished = rental.isOverdueAt(now);
      final hasSurcharge = TimeUtils.hasSurchargeStarted(
        plannedEndTime: rental.plannedEndTime,
        currentTime: now,
      );

      if (rentalId != null) {
        // 1. Dispara notificação nativa imediatamente quando tempo_atual >= planned_end_time
        if (isFinished && !_notifiedFinishedIds.contains(rentalId)) {
          _notifiedFinishedIds.add(rentalId);
          NotificationService.instance.notifyRentalFinished(
            rentalId: rentalId,
            itemName: rental.itemName,
          );
        }

        // 2. No 4º minuto exato de atraso, dispara notificação nativa de início de acréscimo
        if (hasSurcharge && !_notifiedSurchargeIds.contains(rentalId)) {
          _notifiedSurchargeIds.add(rentalId);
          NotificationService.instance.notifySurchargeStarted(
            rentalId: rentalId,
            itemName: rental.itemName,
          );
        }
      }

      // Recalcula o acréscimo automático caso o operador não tenha fixado valor manual
      if (rentalId != null &&
          !state.manuallyEditedSurchargeIds.contains(rentalId)) {
        final autoSurcharge = rental.autoSurchargeAt(now);
        if ((autoSurcharge - rental.surcharge).abs() > 0.001) {
          final updatedTotal = rental.surchargeApplied
              ? (rental.basePrice + autoSurcharge)
              : rental.basePrice;
          updatedActive.add(
            rental.copyWith(
              surcharge: autoSurcharge,
              totalPaid: updatedTotal,
            ),
          );
          listChanged = true;
          continue;
        }
      }

      updatedActive.add(rental);
    }

    if (listChanged) {
      state = state.copyWith(
        activeRentals: updatedActive,
        currentTime: now,
      );
    } else {
      state = state.copyWith(currentTime: now);
    }
  }

  static const String _joinedSelectSql = '''
    SELECT 
      r.*,
      COALESCE(i.name, 'Item Removido') AS item_name,
      COALESCE(i.type, 'Outro') AS item_type,
      COALESCE(i.color_hex, '#1565C0') AS item_color_hex,
      i.photo_path AS item_photo_path
    FROM rentals r
    LEFT JOIN items i ON r.item_id = i.id
  ''';

  Future<void> loadRentals() async {
    try {
      final db = await _dbHelper.database;

      final activeRows = await db.rawQuery(
        "$_joinedSelectSql WHERE r.status = 'active' ORDER BY r.planned_end_time ASC",
      );
      final completedRows = await db.rawQuery(
        "$_joinedSelectSql WHERE r.status = 'completed' ORDER BY r.actual_end_time DESC, r.start_time DESC LIMIT 200",
      );

      final now = DateTime.now();
      final activeList = activeRows.map((row) {
        final model = RentalModel.fromJoinedMap(row);
        if (model.id != null && model.isOverdueAt(now)) {
          _notifiedFinishedIds.add(model.id!);
        }
        if (model.id != null &&
            TimeUtils.hasSurchargeStarted(
              plannedEndTime: model.plannedEndTime,
              currentTime: now,
            )) {
          _notifiedSurchargeIds.add(model.id!);
        }
        if (model.id != null &&
            !state.manuallyEditedSurchargeIds.contains(model.id)) {
          final autoSurcharge = model.autoSurchargeAt(now);
          final total = model.surchargeApplied
              ? model.basePrice + autoSurcharge
              : model.basePrice;
          return model.copyWith(surcharge: autoSurcharge, totalPaid: total);
        }
        return model;
      }).toList(growable: false);

      final completedList = completedRows
          .map(RentalModel.fromJoinedMap)
          .toList(growable: false);

      state = state.copyWith(
        activeRentals: activeList,
        completedRentals: completedList,
        currentTime: now,
        isLoading: false,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Erro ao carregar aluguéis: $e',
      );
    }
  }

  /// Criação em Lote de Aluguéis:
  /// Cria registros individuais separados no banco para cada item selecionado.
  Future<void> createBatchRentals(List<BatchRentalRequestItem> batchItems) async {
    if (batchItems.isEmpty) return;

    try {
      final db = await _dbHelper.database;
      final now = DateTime.now();
      final createdDate = AppFormatters.sqlDate(now);

      await db.transaction((txn) async {
        for (final req in batchItems) {
          final plannedEnd = now.add(Duration(minutes: req.durationMinutes));
          await txn.insert('rentals', {
            'item_id': req.itemId,
            'start_time': now.toIso8601String(),
            'planned_end_time': plannedEnd.toIso8601String(),
            'actual_end_time': null,
            'base_price': req.basePrice,
            'surcharge': 0.0,
            'surcharge_applied': 0,
            'total_paid': req.basePrice,
            'status': 'active',
            'created_date': createdDate,
          });
        }
        // Verifica retenção de 200 concluídos na criação também conforme especificação
        await _dbHelper.enforceRetentionLimitTxn(txn);
      });

      await loadRentals();
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Erro ao registrar aluguéis em lote: $e',
      );
    }
  }

  /// Altera o tempo previsto de término adicionando ou diminuindo minutos ([deltaMinutes]).
  /// Suporta valores positivos (adiciona tempo) ou negativos (diminui tempo).
  /// O novo planned_end_time não pode ser anterior ao start_time.
  Future<void> adjustRentalTime(int rentalId, int deltaMinutes) async {
    final target = state.activeRentals
        .where((r) => r.id == rentalId)
        .firstOrNull;
    if (target == null || deltaMinutes == 0) return;

    var newPlannedEnd = target.plannedEndTime.add(
      Duration(minutes: deltaMinutes),
    );

    // Garante que o horário previsto de término seja no mínimo igual ou posterior ao início
    if (newPlannedEnd.isBefore(target.startTime)) {
      newPlannedEnd = target.startTime.add(const Duration(minutes: 1));
    }

    final now = DateTime.now();

    // Se o novo horário voltou a ficar no futuro, limpa flags de notificação
    if (now.isBefore(newPlannedEnd)) {
      _notifiedFinishedIds.remove(rentalId);
      _notifiedSurchargeIds.remove(rentalId);
    }

    final manualSet = Set<int>.from(state.manuallyEditedSurchargeIds)
      ..remove(rentalId);
    state = state.copyWith(manuallyEditedSurchargeIds: manualSet);

    final newAutoSurcharge = TimeUtils.calculateSurcharge(
      plannedEndTime: newPlannedEnd,
      currentTime: now,
    );
    final newTotalPaid = target.surchargeApplied
        ? target.basePrice + newAutoSurcharge
        : target.basePrice;

    try {
      final db = await _dbHelper.database;
      await db.transaction((txn) async {
        await txn.update(
          'rentals',
          {
            'planned_end_time': newPlannedEnd.toIso8601String(),
            'surcharge': newAutoSurcharge,
            'total_paid': newTotalPaid,
          },
          where: 'id = ?',
          whereArgs: [rentalId],
        );
      });
      await loadRentals();
    } catch (e) {
      state = state.copyWith(errorMessage: 'Erro ao ajustar tempo: $e');
    }
  }

  /// Adiciona minutos extras (+10 min, +15 min, etc.) ao horário previsto de término
  Future<void> extendRentalTime(int rentalId, int extraMinutes) async {
    await adjustRentalTime(rentalId, extraMinutes);
  }

  /// Altera o equipamento vinculado a um aluguel ativo
  Future<void> changeRentalItem(int rentalId, int newItemId) async {
    try {
      final db = await _dbHelper.database;
      await db.transaction((txn) async {
        await txn.update(
          'rentals',
          {'item_id': newItemId},
          where: 'id = ?',
          whereArgs: [rentalId],
        );
      });
      await loadRentals();
    } catch (e) {
      state = state.copyWith(errorMessage: 'Erro ao alterar equipamento: $e');
    }
  }

  /// Altera o valor base de um aluguel ativo
  Future<void> updateBasePrice(int rentalId, double newBasePrice) async {
    final target = state.activeRentals
        .where((r) => r.id == rentalId)
        .firstOrNull;
    if (target == null) return;

    final sanitizedPrice = newBasePrice < 0 ? 0.0 : newBasePrice;
    final newTotalPaid = target.surchargeApplied
        ? sanitizedPrice + target.surcharge
        : sanitizedPrice;

    try {
      final db = await _dbHelper.database;
      await db.transaction((txn) async {
        await txn.update(
          'rentals',
          {
            'base_price': sanitizedPrice,
            'total_paid': newTotalPaid,
          },
          where: 'id = ?',
          whereArgs: [rentalId],
        );
      });
      await loadRentals();
    } catch (e) {
      state = state.copyWith(errorMessage: 'Erro ao alterar valor base: $e');
    }
  }

  /// Permite que o operador edite manualmente o valor do acréscimo
  Future<void> updateSurchargeValue(
    int rentalId,
    double customSurcharge, {
    bool? applyToTotal,
  }) async {
    final target = state.activeRentals
        .where((r) => r.id == rentalId)
        .firstOrNull;
    if (target == null) return;

    final sanitizedSurcharge = customSurcharge < 0 ? 0.0 : customSurcharge;
    final shouldApply = applyToTotal ?? target.surchargeApplied;
    final newTotalPaid = shouldApply
        ? target.basePrice + sanitizedSurcharge
        : target.basePrice;

    final manualSet = Set<int>.from(state.manuallyEditedSurchargeIds)
      ..add(rentalId);
    state = state.copyWith(manuallyEditedSurchargeIds: manualSet);

    try {
      final db = await _dbHelper.database;
      await db.transaction((txn) async {
        await txn.update(
          'rentals',
          {
            'surcharge': sanitizedSurcharge,
            'surcharge_applied': shouldApply ? 1 : 0,
            'total_paid': newTotalPaid,
          },
          where: 'id = ?',
          whereArgs: [rentalId],
        );
      });
      await loadRentals();
    } catch (e) {
      state = state.copyWith(errorMessage: 'Erro ao atualizar acréscimo: $e');
    }
  }

  /// Botão "Adicionar Acréscimo ao Valor":
  /// Se clicado, total_paid = base_price + surcharge e surcharge_applied = 1.
  /// Se não for clicado (ou desmarcado), total_paid = base_price e surcharge_applied = 0.
  Future<void> toggleApplySurcharge(
    int rentalId, {
    required bool apply,
    double? surchargeOverride,
  }) async {
    final target = state.activeRentals
        .where((r) => r.id == rentalId)
        .firstOrNull;
    if (target == null) return;

    final effectiveSurcharge = surchargeOverride ?? target.surcharge;
    await updateSurchargeValue(
      rentalId,
      effectiveSurcharge,
      applyToTotal: apply,
    );
  }

  /// Exclui um aluguel ativo sem contabilizá-lo no faturamento
  Future<void> deleteRental(int rentalId) async {
    try {
      final db = await _dbHelper.database;
      await db.transaction((txn) async {
        await txn.delete(
          'rentals',
          where: 'id = ?',
          whereArgs: [rentalId],
        );
      });
      _notifiedFinishedIds.remove(rentalId);
      _notifiedSurchargeIds.remove(rentalId);
      final manualSet = Set<int>.from(state.manuallyEditedSurchargeIds)
        ..remove(rentalId);
      state = state.copyWith(manuallyEditedSurchargeIds: manualSet);
      await loadRentals();
    } catch (e) {
      state = state.copyWith(errorMessage: 'Erro ao excluir aluguel: $e');
    }
  }

  /// Finaliza o aluguel:
  /// 1. Grava os valores finais (respeitando se "Adicionar Acréscimo ao Valor" foi acionado).
  /// 2. Computa as métricas isoladas em `daily_financial_stats`.
  /// 3. Executa a regra de retenção de no máximo 200 aluguéis concluídos.
  Future<void> completeRental(
    int rentalId, {
    double? finalSurcharge,
    bool? surchargeApplied,
  }) async {
    final target = state.activeRentals
        .where((r) => r.id == rentalId)
        .firstOrNull;
    if (target == null) return;

    final now = DateTime.now();
    final effectiveSurcharge = finalSurcharge ?? target.surcharge;
    final isApplied = surchargeApplied ?? target.surchargeApplied;
    final finalTotalPaid = isApplied
        ? (target.basePrice + effectiveSurcharge)
        : target.basePrice;
    final dateKey = _dbHelper.todayDateKey;

    try {
      final db = await _dbHelper.database;
      await db.transaction((txn) async {
        // 1. Atualiza o registro do aluguel para 'completed'
        await txn.update(
          'rentals',
          {
            'actual_end_time': now.toIso8601String(),
            'surcharge': effectiveSurcharge,
            'surcharge_applied': isApplied ? 1 : 0,
            'total_paid': finalTotalPaid,
            'status': 'completed',
          },
          where: 'id = ?',
          whereArgs: [rentalId],
        );

        // 2. Computa na tabela isolada daily_financial_stats ANTES de qualquer expurgo
        await _dbHelper.recordRentalInFinancialStatsTxn(
          txn: txn,
          dateKey: dateKey,
          rentalStartTime: target.startTime,
          amountPaid: finalTotalPaid,
          itemCategory: target.itemType,
          itemName: target.itemName,
        );

        // 3. Executa expurgo físico se ultrapassar 200 aluguéis 'completed'
        await _dbHelper.enforceRetentionLimitTxn(txn);
      });

      _notifiedFinishedIds.remove(rentalId);
      _notifiedSurchargeIds.remove(rentalId);
      final manualSet = Set<int>.from(state.manuallyEditedSurchargeIds)
        ..remove(rentalId);
      state = state.copyWith(manuallyEditedSurchargeIds: manualSet);

      await loadRentals();
      await ref.read(financialControllerProvider.notifier).loadFinancialStats();
    } catch (e) {
      state = state.copyWith(errorMessage: 'Erro ao finalizar aluguel: $e');
    }
  }

  /// Apaga o histórico de aluguéis concluídos (mantendo daily_financial_stats intacto!)
  Future<void> clearCompletedHistory() async {
    try {
      final db = await _dbHelper.database;
      await db.transaction((txn) async {
        await txn.delete(
          'rentals',
          where: 'status = ?',
          whereArgs: ['completed'],
        );
      });
      await loadRentals();
    } catch (e) {
      state = state.copyWith(errorMessage: 'Erro ao apagar histórico: $e');
    }
  }
}

final rentalControllerProvider =
    NotifierProvider<RentalController, RentalsState>(
      RentalController.new,
    );
