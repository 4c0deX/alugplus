import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../controllers/rental_controller.dart';
import '../models/rental_model.dart';
import '../widgets/rental_card.dart';
import '../widgets/rental_custom_modals.dart';
import 'new_rental_sheet.dart';
import 'rental_detail_view.dart';

class RentalsView extends ConsumerWidget {
  const RentalsView({super.key});

  /// Formata e copia todos os aluguéis para a área de transferência (WhatsApp da empresa).
  /// Cada linha possui: Nome do item, Horário de Saída, Horário de Chegada e Valor Total Pago.
  Future<void> _copyRentalsForWhatsApp(
    BuildContext context,
    RentalsState rentalsState,
  ) async {
    final allToExport = <RentalModel>[
      ...rentalsState.completedRentals,
      ...rentalsState.activeRentals,
    ];

    if (allToExport.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Nenhum aluguel registrado no momento para copiar.',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Ordena cronologicamente pelo horário de saída (do primeiro ao último alugado)
    allToExport.sort((a, b) => a.startTime.compareTo(b.startTime));

    final lines = <String>[];
    for (final r in allToExport) {
      final saida = AppFormatters.timeShort(r.startTime);
      final chegadaTime = r.actualEndTime ?? r.plannedEndTime;
      final chegada = AppFormatters.timeShort(chegadaTime);
      final valor = AppFormatters.currency(r.totalPaid);
      lines.add(
        '${r.itemName} - Saída: $saida | Chegada: $chegada | Total: $valor',
      );
    }

    final clipboardText = lines.join('\n');
    await Clipboard.setData(ClipboardData(text: clipboardText));

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${lines.length} aluguel(is) copiado(s) para a área de transferência! Pronto para colar no WhatsApp.',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Ver Texto',
          textColor: Colors.white,
          onPressed: () {
            _showWhatsAppPreviewDialog(context, clipboardText, lines.length);
          },
        ),
      ),
    );
  }

  void _showWhatsAppPreviewDialog(
    BuildContext context,
    String text,
    int count,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 540),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF128C7E), Color(0xFF25D366)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.content_paste_go_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Copiado para o WhatsApp!',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '$count linha(s) formatada(s) na área de transferência',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).cardColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.grey.withValues(alpha: 0.3),
                      ),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        text,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Fechar'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF128C7E),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: text));
                        if (ctx.mounted) {
                          Navigator.of(ctx).pop();
                        }
                      },
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('Copiar Novamente'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (activeCount, completedCount) = ref.watch(
      rentalControllerProvider.select(
        (s) => (s.activeRentals.length, s.completedRentals.length),
      ),
    );
    final totalAvailableToCopy = completedCount + activeCount;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'fab_rentals',
          onPressed: () => NewRentalSheet.show(context),
          icon: const Icon(Icons.add_rounded),
          label: const Text('+ Novo Aluguel'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 16,
                runSpacing: 12,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Controle de Aluguéis',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Acompanhe cronômetros ativos em tempo real e o histórico recente (máx. 200 registros)',
                        style: TextStyle(color: AppColors.textSecondaryLight),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF128C7E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => _copyRentalsForWhatsApp(
                      context,
                      ref.read(rentalControllerProvider),
                    ),
                    icon: const Icon(Icons.content_copy_rounded, size: 18),
                    label: Text(
                      totalAvailableToCopy > 0
                          ? 'Copiar p/ WhatsApp ($totalAvailableToCopy)'
                          : 'Copiar p/ WhatsApp',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TabBar(
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  indicator: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: AppColors.textSecondaryLight,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                  tabs: [
                    Tab(
                      text: 'Ativos ($activeCount)',
                    ),
                    Tab(
                      text: 'Histórico ($completedCount/200)',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: TabBarView(
                  children: [
                    const _ActiveRentalsTab(),
                    _HistoryRentalsTab(
                      onClearHistory: () => _confirmClearHistory(context, ref),
                      onCopyWhatsApp: () => _copyRentalsForWhatsApp(
                        context,
                        ref.read(rentalControllerProvider),
                      ),
                      onEditRentalPrice: (rental) =>
                          _editHistoryRentalPrice(context, ref, rental),
                      onDeleteSingleRental: (rental) =>
                          _confirmDeleteHistoryRental(context, ref, rental),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editHistoryRentalPrice(
    BuildContext context,
    WidgetRef ref,
    RentalModel rental,
  ) async {
    final newPrice = await CustomChangePriceModal.show(
      context,
      rental: rental,
      isHistoryRental: true,
    );

    if (newPrice != null && (newPrice - rental.totalPaid).abs() > 0.001) {
      await ref
          .read(rentalControllerProvider.notifier)
          .updateCompletedRentalPrice(rental, newPrice);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Valor de "${rental.itemName}" atualizado para ${AppFormatters.currency(newPrice)} (Histórico e Financeiro)!',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _confirmDeleteHistoryRental(
    BuildContext context,
    WidgetRef ref,
    RentalModel rental,
  ) async {
    final endTime = rental.actualEndTime ?? rental.plannedEndTime;
    final itemColor = AppColors.fromHex(rental.itemColorHex);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.danger,
                      AppColors.danger.withValues(alpha: 0.8),
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.delete_forever_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Apagar Aluguel e Rastro Financeiro?',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: itemColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: itemColor.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        children: [
                          RentalItemAvatar(
                            itemName: rental.itemName,
                            photoPath: rental.itemPhotoPath,
                            colorHex: rental.itemColorHex,
                            itemType: rental.itemType,
                            size: 44,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  rental.itemName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                                Text(
                                  'Saída: ${AppFormatters.timeShort(rental.startTime)} • Chegada: ${AppFormatters.timeShort(endTime)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondaryLight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            AppFormatters.currency(rental.totalPaid),
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: AppColors.danger,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Esta ação removerá este aluguel do Histórico e também subtrairá '
                      'seu valor e sua contagem da aba Financeiro, apagando todo o rastro de que ele existiu.',
                      style: TextStyle(fontSize: 13.5, height: 1.4),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.danger,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => Navigator.of(ctx).pop(true),
                      icon: const Icon(Icons.delete_forever_rounded, size: 18),
                      label: const Text(
                        'Apagar Sem Deixar Rastro',
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
    );

    if (confirmed == true) {
      await ref
          .read(rentalControllerProvider.notifier)
          .deleteCompletedRentalWithFinancialTrace(rental);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Aluguel de "${rental.itemName}" (${AppFormatters.currency(rental.totalPaid)}) removido do histórico e do financeiro!',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _confirmClearHistory(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Apagar Histórico de Aluguéis'),
        content: const Text(
          'Deseja remover todos os registros da aba Histórico? '
          'Os totais financeiros e gráficos em daily_financial_stats permanecerão preservados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Apagar Histórico'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(rentalControllerProvider.notifier).clearCompletedHistory();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Histórico limpo com sucesso!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

class _ActiveRentalsTab extends ConsumerWidget {
  const _ActiveRentalsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (activeRentals, currentTime) = ref.watch(
      rentalControllerProvider.select((s) => (s.activeRentals, s.currentTime)),
    );
    if (activeRentals.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.timer_off_outlined,
              size: 64,
              color: AppColors.primary.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 12),
            const Text(
              'Nenhum aluguel ativo no momento.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => NewRentalSheet.show(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('+ Novo Aluguel'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: activeRentals.length,
      itemBuilder: (context, index) {
        final rental = activeRentals[index];
        return RentalCard(
          rental: rental,
          currentTime: currentTime,
          onExpand: () {
            if (rental.id != null) {
              RentalDetailView.show(context, rental.id!);
            }
          },
        );
      },
    );
  }
}

class _HistoryRentalsTab extends ConsumerWidget {
  final VoidCallback onClearHistory;
  final VoidCallback onCopyWhatsApp;
  final ValueChanged<RentalModel> onEditRentalPrice;
  final ValueChanged<RentalModel> onDeleteSingleRental;

  const _HistoryRentalsTab({
    required this.onClearHistory,
    required this.onCopyWhatsApp,
    required this.onEditRentalPrice,
    required this.onDeleteSingleRental,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completedRentals = ref.watch(
      rentalControllerProvider.select((s) => s.completedRentals),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (completedRentals.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Wrap(
              spacing: 10,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Exibindo ${completedRentals.length} registro(s) recente(s)',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondaryLight,
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF128C7E),
                        side: const BorderSide(color: Color(0xFF128C7E)),
                      ),
                      onPressed: onCopyWhatsApp,
                      icon: const Icon(Icons.content_copy_rounded, size: 17),
                      label: const Text('Copiar Lista'),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: AppColors.danger),
                      ),
                      onPressed: onClearHistory,
                      icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                      label: const Text('Limpar Aba'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        Expanded(
          child: completedRentals.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.history_rounded,
                        size: 64,
                        color: AppColors.primary.withValues(alpha: 0.35),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Nenhum aluguel finalizado no histórico.',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: completedRentals.length,
                  itemBuilder: (context, index) {
                    final rental = completedRentals[index];
                    final endTime =
                        rental.actualEndTime ?? rental.plannedEndTime;
                    final itemColor = AppColors.fromHex(rental.itemColorHex);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: itemColor.withValues(alpha: 0.4),
                          width: 1.4,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            RentalItemAvatar(
                              itemName: rental.itemName,
                              photoPath: rental.itemPhotoPath,
                              colorHex: rental.itemColorHex,
                              itemType: rental.itemType,
                              size: 48,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    rental.itemName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Saída: ${AppFormatters.timeShort(rental.startTime)}  •  '
                                    'Chegada: ${AppFormatters.timeShort(endTime)}',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      color: AppColors.textSecondaryLight,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (rental.surchargeApplied &&
                                      rental.surcharge > 0) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      'Inclui acréscimo de +${AppFormatters.currency(rental.surcharge)}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.warning,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Botão clicável com o valor pago (abre a janela personalizada de modificar valor)
                            InkWell(
                              onTap: () => onEditRentalPrice(rental),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.success.withValues(
                                      alpha: 0.35,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      AppFormatters.currency(rental.totalPaid),
                                      style: const TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.success,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    const Icon(
                                      Icons.edit_rounded,
                                      size: 14,
                                      color: AppColors.success,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            // Botão de apagar aluguel e remover da área financeira sem deixar rastro
                            IconButton(
                              tooltip:
                                  'Apagar aluguel do histórico e do financeiro',
                              onPressed: () => onDeleteSingleRental(rental),
                              icon: const Icon(
                                Icons.delete_forever_rounded,
                                color: AppColors.danger,
                                size: 22,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
