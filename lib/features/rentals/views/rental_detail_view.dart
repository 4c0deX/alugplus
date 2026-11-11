
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/time_utils.dart';
import '../../catalog/controllers/catalog_controller.dart';
import '../controllers/rental_controller.dart';
import '../models/rental_model.dart';
import '../widgets/rental_card.dart';

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
  final TextEditingController _timeExpressionController = TextEditingController();
  bool _isEditingSurchargeText = false;
  int? _previewEvaluatedMinutes;

  @override
  void dispose() {
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

    _syncSurchargeField(rental);

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
                          ? 'Em período de tolerância ($delayMinutes/${TimeUtils.toleranceMinutes} min). Acréscimo inicia no 4º minuto.'
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
                          Text(
                            AppFormatters.currency(rental.basePrice),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
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
            // Seção Didática de Edição do Tempo Restante (Adicionar / Diminuir / Cálculos)
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
                      const Icon(Icons.edit_calendar_rounded,
                          color: AppColors.primary, size: 20),
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
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (_previewEvaluatedMinutes! >= 0
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
                            suffixIcon: _timeExpressionController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, size: 18),
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
                            final eval = TimeUtils.evaluateMinutesExpression(val);
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
                            backgroundColor: _previewEvaluatedMinutes != null &&
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
                OutlinedButton.icon(
                  onPressed: () => _showChangeItemDialog(context, rental),
                  icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                  label: const Text('Alterar Item'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _showChangePriceDialog(context, rental),
                  icon: const Icon(Icons.edit_note_rounded, size: 18),
                  label: const Text('Alterar Valor'),
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
    int selectedId = rental.itemId;

    final chosen = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Cabeçalho estilizado
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primaryDark,
                        AppColors.primary,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.35),
                          ),
                        ),
                        child: const Icon(
                          Icons.swap_horiz_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Alterar Equipamento',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Atual: ${rental.itemName}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(Icons.close_rounded, color: Colors.white),
                        tooltip: 'Fechar',
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                  child: Row(
                    children: [
                      const Icon(Icons.touch_app_outlined,
                          size: 16, color: AppColors.textSecondaryLight),
                      const SizedBox(width: 6),
                      Text(
                        'Selecione o novo item para este aluguel:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(ctx).textTheme.bodySmall?.color,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Lista de Itens com Cores de Destaque
                Flexible(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shrinkWrap: true,
                    itemCount: catalogItems.length,
                    itemBuilder: (ctx, index) {
                      final item = catalogItems[index];
                      final itemId = item.id!;
                      final isSelected = selectedId == itemId;
                      final isCurrentOfThisRental = rental.itemId == itemId;
                      final isBusyWithOther = busyIds.contains(itemId) && !isCurrentOfThisRental;
                      final itemColor = AppColors.fromHex(item.colorHex);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              setModalState(() => selectedId = itemId);
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? itemColor.withValues(alpha: 0.14)
                                    : Theme.of(ctx).cardColor,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected
                                      ? itemColor
                                      : itemColor.withValues(alpha: 0.35),
                                  width: isSelected ? 2.2 : 1.2,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: itemColor.withValues(alpha: 0.25),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  // Barra vertical com a cor de destaque
                                  Container(
                                    width: 5,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: itemColor,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Avatar do Item
                                  RentalItemAvatar(
                                    photoPath: item.photoPath,
                                    colorHex: item.colorHex,
                                    itemType: item.type,
                                    size: 44,
                                  ),
                                  const SizedBox(width: 12),
                                  // Detalhes do Item
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                item.name,
                                                style: TextStyle(
                                                  fontWeight: isSelected
                                                      ? FontWeight.w800
                                                      : FontWeight.w700,
                                                  fontSize: 14.5,
                                                ),
                                              ),
                                            ),
                                            if (isCurrentOfThisRental)
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 7, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppColors.primary
                                                      .withValues(alpha: 0.16),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: const Text(
                                                  'Atual',
                                                  style: TextStyle(
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.primary,
                                                  ),
                                                ),
                                              )
                                            else if (isBusyWithOther)
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 7, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppColors.warning
                                                      .withValues(alpha: 0.16),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: const Text(
                                                  'Em outro aluguel',
                                                  style: TextStyle(
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.warning,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 6, vertical: 1.5),
                                              decoration: BoxDecoration(
                                                color: itemColor.withValues(alpha: 0.16),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                item.type,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: itemColor,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              width: 10,
                                              height: 10,
                                              decoration: BoxDecoration(
                                                color: itemColor,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              item.colorHex.toUpperCase(),
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: itemColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Indicador de seleção
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isSelected
                                          ? itemColor
                                          : Colors.transparent,
                                      border: Border.all(
                                        color: isSelected
                                            ? itemColor
                                            : Colors.grey.withValues(alpha: 0.45),
                                        width: 2,
                                      ),
                                    ),
                                    child: isSelected
                                        ? Icon(
                                            Icons.check_rounded,
                                            size: 16,
                                            color: AppColors.contrastingTextColor(itemColor),
                                          )
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const Divider(height: 1),
                // Rodapé de Ações
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Cancelar'),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => Navigator.of(ctx).pop(selectedId),
                        icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                        label: const Text(
                          'Confirmar Troca',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (chosen != null && chosen != rental.itemId) {
      await ref
          .read(rentalControllerProvider.notifier)
          .changeRentalItem(rental.id!, chosen);

      if (context.mounted) {
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
    final controller = TextEditingController(
      text: rental.basePrice.toStringAsFixed(2).replaceAll('.', ','),
    );
    double previewPrice = rental.basePrice;

    final newPrice = await showDialog<double>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Cabeçalho com Gradiente
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 18),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primaryDark,
                          AppColors.primary,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.35),
                            ),
                          ),
                          child: const Icon(
                            Icons.payments_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Alterar Valor Base',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                rental.itemName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.85),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: const Icon(Icons.close_rounded,
                              color: Colors.white),
                          tooltip: 'Fechar',
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Card comparativo: Valor Atual vs Novo Total Previsto
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Theme.of(ctx).cardColor,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.grey.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Valor Base Atual',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: AppColors.textSecondaryLight,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    AppFormatters.currency(rental.basePrice),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              const Icon(Icons.arrow_forward_rounded,
                                  size: 18,
                                  color: AppColors.textSecondaryLight),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text(
                                    'Novo Valor Previsto',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: AppColors.textSecondaryLight,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    AppFormatters.currency(previewPrice),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Campo de Texto do Valor
                        TextFormField(
                          controller: controller,
                          autofocus: true,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Novo Valor Base (R\$)',
                            hintText: 'Ex: 15,00',
                            prefixIcon: const Icon(Icons.attach_money_rounded),
                            suffixIcon: controller.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded,
                                        size: 18),
                                    onPressed: () {
                                      setModalState(() {
                                        controller.clear();
                                        previewPrice = 0.0;
                                      });
                                    },
                                  )
                                : null,
                          ),
                          onChanged: (val) {
                            setModalState(() {
                              previewPrice = AppFormatters.parseCurrency(
                                val,
                                fallback: 0.0,
                              );
                            });
                          },
                        ),
                        const SizedBox(height: 14),

                        // Chips de Valores Práticos
                        const Text(
                          'Valores sugeridos / Ajustes rápidos:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondaryLight,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _QuickPriceChip(
                              label: 'R\$ 10',
                              onTap: () {
                                setModalState(() {
                                  controller.text = '10,00';
                                  previewPrice = 10.0;
                                });
                              },
                            ),
                            _QuickPriceChip(
                              label: 'R\$ 15',
                              onTap: () {
                                setModalState(() {
                                  controller.text = '15,00';
                                  previewPrice = 15.0;
                                });
                              },
                            ),
                            _QuickPriceChip(
                              label: 'R\$ 20',
                              onTap: () {
                                setModalState(() {
                                  controller.text = '20,00';
                                  previewPrice = 20.0;
                                });
                              },
                            ),
                            _QuickPriceChip(
                              label: 'R\$ 25',
                              onTap: () {
                                setModalState(() {
                                  controller.text = '25,00';
                                  previewPrice = 25.0;
                                });
                              },
                            ),
                            _QuickPriceChip(
                              label: 'R\$ 30',
                              onTap: () {
                                setModalState(() {
                                  controller.text = '30,00';
                                  previewPrice = 30.0;
                                });
                              },
                            ),
                            _QuickPriceChip(
                              label: '+R\$ 5',
                              isDelta: true,
                              onTap: () {
                                setModalState(() {
                                  final current = AppFormatters.parseCurrency(
                                    controller.text,
                                    fallback: rental.basePrice,
                                  );
                                  final updated = (current + 5.0).clamp(0.0, 9999.0);
                                  controller.text = updated
                                      .toStringAsFixed(2)
                                      .replaceAll('.', ',');
                                  previewPrice = updated;
                                });
                              },
                            ),
                            _QuickPriceChip(
                              label: '-R\$ 5',
                              isDelta: true,
                              isNegative: true,
                              onTap: () {
                                setModalState(() {
                                  final current = AppFormatters.parseCurrency(
                                    controller.text,
                                    fallback: rental.basePrice,
                                  );
                                  final updated = (current - 5.0).clamp(0.0, 9999.0);
                                  controller.text = updated
                                      .toStringAsFixed(2)
                                      .replaceAll('.', ',');
                                  previewPrice = updated;
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 1),

                  // Rodapé
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            final parsed = AppFormatters.parseCurrency(
                              controller.text,
                              fallback: rental.basePrice,
                            );
                            Navigator.of(ctx).pop(parsed);
                          },
                          icon: const Icon(Icons.check_circle_outline_rounded,
                              size: 18),
                          label: const Text(
                            'Confirmar Valor',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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
          backgroundColor:
              evaluated > 0 ? AppColors.success : AppColors.warning,
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

class _QuickPriceChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isDelta;
  final bool isNegative;

  const _QuickPriceChip({
    required this.label,
    required this.onTap,
    this.isDelta = false,
    this.isNegative = false,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: isDelta
          ? Icon(
              isNegative ? Icons.remove_rounded : Icons.add_rounded,
              size: 15,
              color: isNegative ? AppColors.danger : AppColors.primary,
            )
          : const Icon(
              Icons.payments_outlined,
              size: 15,
              color: AppColors.primary,
            ),
      label: Text(
        label,
        style: TextStyle(
          color: isNegative ? AppColors.danger : null,
          fontWeight: FontWeight.w600,
          fontSize: 12.5,
        ),
      ),
      onPressed: onTap,
    );
  }
}
