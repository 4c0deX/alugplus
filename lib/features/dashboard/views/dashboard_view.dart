import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../rentals/views/new_rental_sheet.dart';
import '../../rentals/views/rental_detail_view.dart';
import '../../rentals/widgets/rental_card.dart';
import '../controllers/dashboard_controller.dart';

class DashboardView extends ConsumerWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(dashboardControllerProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_dashboard',
        onPressed: () => NewRentalSheet.show(context),
        icon: const Icon(Icons.bolt_rounded),
        label: const Text(
          '+ Novo Aluguel',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: 90,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner Superior de Operação
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primaryDark, AppColors.primary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryDark.withValues(alpha: 0.25),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.8),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.bolt_rounded,
                      color: Colors.white,
                      size: 34,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Painel Operacional AlugPlus+',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Monitoramento em tempo real • ${AppFormatters.dateBr(summary.currentTime)} • ${AppFormatters.timeFull(summary.currentTime)}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Cards de KPI no Topo
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 720;
                final kpiCards = [
                  _KpiCard(
                    title: 'Itens Disponíveis',
                    value: '${summary.availableItemsCount}',
                    subtitle:
                        'de ${summary.totalActiveCatalogCount} ativos comigo',
                    icon: Icons.check_circle_outline_rounded,
                    color: AppColors.success,
                  ),
                  _KpiCard(
                    title: 'Itens Alugados Agora',
                    value: '${summary.rentedRightNowCount}',
                    subtitle: 'Em andamento no cronômetro',
                    icon: Icons.directions_bike_rounded,
                    color: AppColors.primary,
                  ),
                  _KpiCard(
                    title: 'Faturamento Total do Dia',
                    value: AppFormatters.currency(summary.todayRevenue),
                    subtitle:
                        '${summary.todayRentalsCount} concluídos • Consolidado: ${AppFormatters.currency(summary.consolidatedDayRevenue)}',
                    icon: Icons.payments_rounded,
                    color: AppColors.primaryDark,
                  ),
                ];

                if (isWide) {
                  return Row(
                    children: [
                      for (int i = 0; i < kpiCards.length; i++) ...[
                        Expanded(child: kpiCards[i]),
                        if (i < kpiCards.length - 1) const SizedBox(width: 16),
                      ],
                    ],
                  );
                }
                return Column(
                  children: [
                    for (int i = 0; i < kpiCards.length; i++) ...[
                      kpiCards[i],
                      if (i < kpiCards.length - 1) const SizedBox(height: 12),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 28),
            // Seção de Aluguéis Ativos em Andamento
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.timelapse_rounded,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Aluguéis Ativos (${summary.activeRentals.length})',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: () => NewRentalSheet.show(context),
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                  label: const Text('Lançar em Lote'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (summary.activeRentals.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 40,
                    horizontal: 24,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.directions_bike_rounded,
                            size: 42,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Nenhum equipamento alugado neste instante',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Clique em "+ Novo Aluguel" para selecionar 1 ou vários equipamentos e iniciar o cronômetro.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondaryLight),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: summary.activeRentals.length,
                itemBuilder: (context, index) {
                  final rental = summary.activeRentals[index];
                  return RentalCard(
                    rental: rental,
                    currentTime: summary.currentTime,
                    onExpand: () {
                      if (rental.id != null) {
                        RentalDetailView.show(context, rental.id!);
                      }
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
