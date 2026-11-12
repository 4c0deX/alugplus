import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/time_utils.dart';
import '../../catalog/controllers/catalog_controller.dart';
import '../controllers/rental_controller.dart';
import '../models/rental_model.dart';
import '../widgets/rental_card.dart';
import '../widgets/rental_custom_modals.dart';

class RentalDetailView extends ConsumerStatefulWidget {
  final int rentalId;

  const RentalDetailView({
    super.key,
    required this.rentalId,
  });

  static Future<void> show(BuildContext context, int rentalId) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RentalDetailView(rentalId: rentalId),
    );
  }

  @override
  ConsumerState<RentalDetailView> createState() => _RentalDetailViewState();
}

class _RentalDetailViewState extends ConsumerState<RentalDetailView> {
  final TextEditingController _surchargeController = TextEditingController();
  final TextEditingController _timeExpressionController =
      TextEditingController();
  final FocusNode _surchargeFocusNode = FocusNode();
  bool _isEditingSurchargeText = false;
  int? _previewEvaluatedMinutes;

  @override
  void initState() {
    super.initState();
    final initialRental = ref
        .read(rentalControllerProvider)
        .activeRentals
        .where((r) => r.id == widget.rentalId)
        .firstOrNull;
    if (initialRental != null) {
      _surchargeController.text = initialRental.surcharge
          .toStringAsFixed(2)
          .replaceAll('.', ',');
    }
    _surchargeFocusNode.addListener(() {
      if (!_surchargeFocusNode.hasFocus && mounted) {
        setState(() => _isEditingSurchargeText = false);
      }
    });
  }

  @override
  void dispose() {
    _surchargeFocusNode.dispose();
    _surchargeController.dispose();
    _timeExpressionController.dispose();
    super.dispose();
  }

  void _syncSurchargeField(RentalModel rental) {
    if (_isEditingSurchargeText) return;
    final formatted = rental.surcharge.toStringAsFixed(2).replaceAll('.', ',');
    if (_surchargeController.text != formatted) {
      _surchargeController.text = formatted;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<RentalsState>(rentalControllerProvider, (prev, next) {
      if (_isEditingSurchargeText) return;
      final updated = next.activeRentals
          .where((r) => r.id == widget.rentalId)
          .firstOrNull;
      if (updated != null) {
        _syncSurchargeField(updated);
      }
    });

    final rentalsState = ref.watch(rentalControllerProvider);
    final rental = rentalsState.activeRentals
        .where((r) => r.id == widget.rentalId)
        .firstOrNull;

    if (rental == null) {
      return Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Este aluguel já foi finalizado ou removido.'),
          ],
        ),
      );
    }

    final now = rentalsState.currentTime;
    final itemColor = AppColors.fromHex(rental.itemColorHex);
    final isOverdue = rental.isOverdueAt(now);
    final rawProgress = rental.progressAt(now);
    final clampedProgress = rawProgress.clamp(0.0, 1.0);
    final delayMinutes = rental.overdueMinutesAt(now);
    final barColor = isOverdue ? AppColors.danger : itemColor;
    final statusText = TimeUtils.statusTimeLabel(
      plannedEndTime: rental.plannedEndTime,
      currentTime: now,
    );

    return Container(
      constraints: const BoxConstraints(maxWidth: 680),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Cabeçalho do Item
            Row(
              children: [
                RentalItemAvatar(
                  itemName: rental.itemName,
                  photoPath: rental.itemPhotoPath,
                  colorHex: rental.itemColorHex,
                  itemType: rental.itemType,
                  size: 60,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rental.itemName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Categoria: ${rental.itemType} • Início: ${AppFormatters.timeFull(rental.startTime)} • Previsto: ${AppFormatters.timeFull(rental.plannedEndTime)}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Card de Cronômetro e Barra de Progresso em Tempo Real
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: barColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: barColor.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isOverdue
                                ? Icons.alarm_off_rounded
                                : Icons.timer_rounded,
                            color: barColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: barColor,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${(clampedProgress * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: barColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: isOverdue ? 1.0 : clampedProgress,
                      minHeight: 12,
                      backgroundColor: barColor.withValues(alpha: 0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(barColor),
                    ),
                  ),
                  if (isOverdue) ...[
                    const SizedBox(height: 8),
                    Text(
                      delayMinutes < TimeUtils.surchargeTriggerMinute
                          ? 'Em período de tolerância ($delayMinutes/${TimeUtils.toleranceMinutes} min). Acréscimo inicia no ${TimeUtils.surchargeTriggerMinute}º minuto.'
                          : 'Atraso de $delayMinutes min • Cobrança de acréscimo ativa!',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: barColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Seção de Valores e Acréscimo (Surcharge) em Destaque
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: rental.surcharge > 0
                      ? AppColors.warning.withValues(alpha: 0.6)
                      : Colors.grey.withValues(alpha: 0.25),
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Valor Base',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                AppFormatters.currency(rental.basePrice),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 6),
                              InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () =>
                                    _showChangePriceDialog(context, rental),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.edit_rounded,
                                        size: 13,
                                        color: AppColors.primary,
                                      ),
                                      SizedBox(width: 3),
                                      Text(
                                        'Editar',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Total a Pagar',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                          Text(
                            AppFormatters.currency(rental.totalPaid),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  const Text(
                    'Acréscimo por Atraso (Editável pelo Operador)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _surchargeController,
                          focusNode: _surchargeFocusNode,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Acréscimo (R\$)',
                            prefixIcon: Icon(Icons.trending_up_rounded),
                          ),
                          onTap: () {
                            _isEditingSurchargeText = true;
                          },
                          onChanged: (val) {
                            _isEditingSurchargeText = true;
                            final parsed = AppFormatters.parseCurrency(
                              val,
                              fallback: rental.surcharge,
                            );
                            ref
                                .read(rentalControllerProvider.notifier)
                                .updateSurchargeValue(rental.id!, parsed);
                          },
                          onFieldSubmitted: (_) {
                            _isEditingSurchargeText = false;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: SizedBox(
                          height: 50,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: rental.surchargeApplied
                                  ? AppColors.success
                                  : AppColors.warning,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              _isEditingSurchargeText = false;
                              final parsed = AppFormatters.parseCurrency(
                                _surchargeController.text,
                                fallback: rental.surcharge,
                              );
                              ref
                                  .read(rentalControllerProvider.notifier)
                                  .toggleApplySurcharge(
                                    rental.id!,
                                    apply: !rental.surchargeApplied,
                                    surchargeOverride: parsed,
                                  );
                            },
                            icon: Icon(
                              rental.surchargeApplied
                                  ? Icons.check_circle_rounded
                                  : Icons.add_circle_outline_rounded,
                              size: 18,
                            ),
                            label: Text(
                              rental.surchargeApplied
                                  ? 'Acréscimo Somado'
                                  : 'Adicionar Acréscimo ao Valor',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            // Seção Didática de Edição do Tempo Restante
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.edit_calendar_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Editar Tempo Restante (Adicionar / Diminuir)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      if (_previewEvaluatedMinutes != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color:
                                (_previewEvaluatedMinutes! >= 0
                                        ? AppColors.primary
                                        : AppColors.danger)
                                    .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _previewEvaluatedMinutes! >= 0
                                ? '+$_previewEvaluatedMinutes min'
                                : '$_previewEvaluatedMinutes min',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: _previewEvaluatedMinutes! >= 0
                                  ? AppColors.primary
                                  : AppColors.danger,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Escreva o tempo para adicionar, use "-" para diminuir, ou faça cálculos didáticos (ex: 10+20+5 ou -15+5):',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _timeExpressionController,
                          keyboardType: TextInputType.text,
                          decoration: InputDecoration(
                            labelText: 'Ajuste de minutos (+ / - / cálculos)',
                            hintText: 'Ex: 15, -10, 10+20+5',
                            prefixIcon: const Icon(Icons.calculate_outlined),
                            suffixIcon:
                                _timeExpressionController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.clear_rounded,
                                      size: 18,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _timeExpressionController.clear();
                                        _previewEvaluatedMinutes = null;
                                      });
                                    },
                                  )
                                : null,
                          ),
                          onChanged: (val) {
                            final eval = TimeUtils.evaluateMinutesExpression(
                              val,
                            );
                            setState(() {
                              _previewEvaluatedMinutes = eval;
                            });
                          },
                          onFieldSubmitted: (_) => _applyTimeAdjustment(rental),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        height: 52,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                _previewEvaluatedMinutes != null &&
                                    _previewEvaluatedMinutes! < 0
                                ? AppColors.warning
                                : AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => _applyTimeAdjustment(rental),
                          icon: const Icon(Icons.update_rounded, size: 18),
                          label: const Text('Aplicar'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _QuickTimeChip(
                        label: '+5 min',
                        onTap: () => _appendOrSetTime('5'),
                      ),
                      _QuickTimeChip(
                        label: '+10 min',
                        onTap: () => _appendOrSetTime('10'),
                      ),
                      _QuickTimeChip(
                        label: '+15 min',
                        onTap: () => _appendOrSetTime('15'),
                      ),
                      _QuickTimeChip(
                        label: '+30 min',
                        onTap: () => _appendOrSetTime('30'),
                      ),
                      _QuickTimeChip(
                        label: '-5 min',
                        isNegative: true,
                        onTap: () => _appendOrSetTime('-5'),
                      ),
                      _QuickTimeChip(
                        label: '-10 min',
                        isNegative: true,
                        onTap: () => _appendOrSetTime('-10'),
                      ),
                      _QuickTimeChip(
                        label: '-15 min',
                        isNegative: true,
                        onTap: () => _appendOrSetTime('-15'),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('+10+20+5'),
                        onPressed: () {
                          setState(() {
                            _timeExpressionController.text = '10+20+5';
                            _previewEvaluatedMinutes =
                                TimeUtils.evaluateMinutesExpression('10+20+5');
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Ações Rápidas do Aluguel',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    ref
                        .read(rentalControllerProvider.notifier)
                        .extendRentalTime(rental.id!, 10);
                  },
                  icon: const Icon(Icons.more_time_rounded, size: 18),
                  label: const Text('+10 min'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    ref
                        .read(rentalControllerProvider.notifier)
                        .extendRentalTime(rental.id!, 15);
                  },
                  icon: const Icon(Icons.more_time_rounded, size: 18),
                  label: const Text('+15 min'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _showChangeItemDialog(context, rental),
                  icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                  label: const Text('Modificar Item'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _showChangePriceDialog(context, rental),
                  icon: const Icon(Icons.payments_rounded, size: 18),
                  label: const Text('Modificar Valor'),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger),
                  ),
                  onPressed: () => _confirmDeleteRental(context, rental),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Excluir Aluguel'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  _isEditingSurchargeText = false;
                  final currentSurcharge = AppFormatters.parseCurrency(
                    _surchargeController.text,
                    fallback: rental.surcharge,
                  );
                  await ref
                      .read(rentalControllerProvider.notifier)
                      .completeRental(
                        rental.id!,
                        finalSurcharge: currentSurcharge,
                        surchargeApplied: rental.surchargeApplied,
                      );
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Aluguel de "${rental.itemName}" finalizado com sucesso!',
                        ),
                        backgroundColor: AppColors.success,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.task_alt_rounded),
                label: Text(
                  'Finalizar Aluguel (${AppFormatters.currency(rental.totalPaid)})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showChangeItemDialog(
    BuildContext context,
    RentalModel rental,
  ) async {
    final catalogItems = ref.read(catalogControllerProvider).activeItems;
    if (catalogItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nenhum item ativo disponível no catálogo.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final rentalsState = ref.read(rentalControllerProvider);
    final busyIds = rentalsState.busyItemIds;

    final chosen = await CustomChangeItemModal.show(
      context,
      rental: rental,
      catalogItems: catalogItems,
      busyIds: busyIds,
    );

    if (chosen != null && chosen != rental.itemId) {
      await ref
          .read(rentalControllerProvider.notifier)
          .changeRentalItem(rental.id!, chosen);

      if (context.mounted) {
        final error = ref.read(rentalControllerProvider).errorMessage;
        if (error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                error,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              backgroundColor: AppColors.danger,
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
        final newItem = catalogItems.where((i) => i.id == chosen).firstOrNull;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Equipamento alterado para "${newItem?.name ?? "novo item"}"!',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _showChangePriceDialog(
    BuildContext context,
    RentalModel rental,
  ) async {
    final newPrice = await CustomChangePriceModal.show(
      context,
      rental: rental,
      isHistoryRental: false,
    );

    if (newPrice != null) {
      await ref
          .read(rentalControllerProvider.notifier)
          .updateBasePrice(rental.id!, newPrice);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Valor base atualizado para ${AppFormatters.currency(newPrice)}!',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _confirmDeleteRental(
    BuildContext context,
    RentalModel rental,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Aluguel Ativo'),
        content: Text(
          'Deseja excluir o aluguel de "${rental.itemName}" sem contabilizá-lo no histórico?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref
          .read(rentalControllerProvider.notifier)
          .deleteRental(rental.id!);
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  void _appendOrSetTime(String token) {
    final current = _timeExpressionController.text.trim();
    String updated;
    if (current.isEmpty) {
      updated = token;
    } else {
      if (token.startsWith('-') || token.startsWith('+')) {
        updated = '$current$token';
      } else {
        updated = '$current+$token';
      }
    }
    setState(() {
      _timeExpressionController.text = updated;
      _previewEvaluatedMinutes = TimeUtils.evaluateMinutesExpression(updated);
    });
  }

  Future<void> _applyTimeAdjustment(RentalModel rental) async {
    final expr = _timeExpressionController.text.trim();
    final evaluated = TimeUtils.evaluateMinutesExpression(expr);

    if (evaluated == null || evaluated == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Informe uma quantidade de minutos válida (ex: 15, -10 ou 10+20+5).',
          ),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    await ref
        .read(rentalControllerProvider.notifier)
        .adjustRentalTime(rental.id!, evaluated);

    setState(() {
      _timeExpressionController.clear();
      _previewEvaluatedMinutes = null;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            evaluated > 0
                ? 'Tempo estendido em +$evaluated minuto(s) com sucesso!'
                : 'Tempo reduzido em $evaluated minuto(s) com sucesso!',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor: evaluated > 0
              ? AppColors.success
              : AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

class _QuickTimeChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isNegative;

  const _QuickTimeChip({
    required this.label,
    required this.onTap,
    this.isNegative = false,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(
        isNegative ? Icons.remove_rounded : Icons.add_rounded,
        size: 16,
        color: isNegative ? AppColors.danger : AppColors.primary,
      ),
      label: Text(
        label,
        style: TextStyle(
          color: isNegative ? AppColors.danger : null,
          fontWeight: FontWeight.w600,
        ),
      ),
      onPressed: onTap,
    );
  }
}
