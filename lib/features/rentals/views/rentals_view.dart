import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../controllers/rental_controller.dart';
import '../models/rental_model.dart';
import '../widgets/rental_card.dart';
import 'new_rental_sheet.dart';
import 'rental_detail_view.dart';

class RentalsView extends ConsumerWidget {
  const RentalsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rentalsState = ref.watch(rentalControllerProvider);

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
                      text:
                          'Ativos (${rentalsState.activeRentals.length})',
                    ),
                    Tab(
                      text:
                          'Histórico (${rentalsState.completedRentals.length}/200)',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: TabBarView(
                  children: [
                    _ActiveRentalsTab(
                      activeRentals: rentalsState.activeRentals,
                      currentTime: rentalsState.currentTime,
                    ),
                    _HistoryRentalsTab(
                      completedRentals: rentalsState.completedRentals,
                      onClearHistory: () =>
                          _confirmClearHistory(context, ref),
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

class _ActiveRentalsTab extends StatelessWidget {
  final List<RentalModel> activeRentals;
  final DateTime currentTime;

  const _ActiveRentalsTab({
    required this.activeRentals,
    required this.currentTime,
  });

  @override
  Widget build(BuildContext context) {
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

class _HistoryRentalsTab extends StatelessWidget {
  final List<RentalModel> completedRentals;
  final VoidCallback onClearHistory;

  const _HistoryRentalsTab({
    required this.completedRentals,
    required this.onClearHistory,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (completedRentals.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Exibindo ${completedRentals.length} registro(s)',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondaryLight,
                  ),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger),
                  ),
                  onPressed: onClearHistory,
                  icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                  label: const Text('Apagar Histórico'),
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
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        leading: RentalItemAvatar(
                          photoPath: rental.itemPhotoPath,
                          colorHex: rental.itemColorHex,
                          itemType: rental.itemType,
                          size: 46,
                        ),
                        title: Text(
                          rental.itemName,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Início: ${AppFormatters.timeShort(rental.startTime)}  •  '
                            'Entrega: ${AppFormatters.timeShort(endTime)}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              AppFormatters.currency(rental.totalPaid),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.success,
                              ),
                            ),
                            if (rental.surchargeApplied && rental.surcharge > 0)
                              Text(
                                'Inclui +${AppFormatters.currency(rental.surcharge)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.warning,
                                  fontWeight: FontWeight.w600,
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
