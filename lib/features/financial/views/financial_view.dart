import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../controllers/financial_controller.dart';

class FinancialView extends ConsumerWidget {
  const FinancialView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final finState = ref.watch(financialControllerProvider);

    return SingleChildScrollView(
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Gestão Financeira & Métricas',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: finState.isDayClosed
                              ? AppColors.warning.withValues(alpha: 0.15)
                              : AppColors.success.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          finState.isDayClosed
                              ? 'Expediente Consolidado'
                              : 'Expediente Aberto',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: finState.isDayClosed
                                ? AppColors.warning
                                : AppColors.success,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Data de referência: ${AppFormatters.sqlDateToBr(finState.todayDate)} • Isolamento de métricas ativo (daily_financial_stats)',
                    style: const TextStyle(color: AppColors.textSecondaryLight),
                  ),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => _confirmResetAndCloseDay(context, ref, finState),
                icon: const Icon(Icons.lock_clock_rounded),
                label: const Text('Resetar / Fechar Dia'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Cards de Indicadores Financeiros
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 720;
              final cards = [
                _FinancialSummaryCard(
                  title: 'Faturamento do Expediente Atual',
                  value: AppFormatters.currency(finState.currentShiftRevenue),
                  subtitle:
                      '${finState.currentShiftRentalsCount} aluguéis finalizados neste turno',
                  icon: Icons.payments_rounded,
                  accentColor: AppColors.primary,
                ),
                _FinancialSummaryCard(
                  title: 'Faturamento Consolidado do Dia',
                  value: AppFormatters.currency(finState.consolidatedDayRevenue),
                  subtitle:
                      'Total acumulado no dia (${finState.consolidatedDayCount} locações)',
                  icon: Icons.account_balance_wallet_rounded,
                  accentColor: AppColors.success,
                ),
                _FinancialSummaryCard(
                  title: 'Ticket Médio (Expediente)',
                  value: finState.currentShiftRentalsCount > 0
                      ? AppFormatters.currency(
                          finState.currentShiftRevenue /
                              finState.currentShiftRentalsCount,
                        )
                      : 'R\$ 0,00',
                  subtitle: 'Média por locação concluída',
                  icon: Icons.trending_up_rounded,
                  accentColor: AppColors.accent,
                ),
              ];

              if (isWide) {
                return Row(
                  children: [
                    for (int i = 0; i < cards.length; i++) ...[
                      Expanded(child: cards[i]),
                      if (i < cards.length - 1) const SizedBox(width: 16),
                    ],
                  ],
                );
              }
              return Column(
                children: [
                  for (int i = 0; i < cards.length; i++) ...[
                    cards[i],
                    if (i < cards.length - 1) const SizedBox(height: 12),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          // Seção de Gráficos (Barras por Faixa Horária + Pizza/Ranking de Categorias e Itens)
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 860;
              final hourlyChartCard = _HourlyBarChartCard(
                metrics: finState.hourlyMetrics,
              );
              final rankingCard = _CategoryAndItemRankingCard(
                categoryRanking: finState.categoryRanking,
                itemRanking: finState.itemRanking,
              );

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: hourlyChartCard),
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: rankingCard),
                  ],
                );
              }
              return Column(
                children: [
                  hourlyChartCard,
                  const SizedBox(height: 16),
                  rankingCard,
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          // Histórico de Dias Consolidados (daily_financial_stats)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Row(
                          children: [
                            Icon(Icons.history_edu_rounded, color: AppColors.primary),
                            SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                'Registro Isolado de Fechamentos Diários',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (finState.historyDays.isNotEmpty)
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.danger,
                            side: const BorderSide(color: AppColors.danger),
                          ),
                          onPressed: () =>
                              _confirmClearDailyFinancialStats(context, ref),
                          icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                          label: const Text('Apagar Fechamentos'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (finState.historyDays.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Nenhum registro diário consolidado até o momento.',
                        style: TextStyle(color: AppColors.textSecondaryLight),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: finState.historyDays.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final rec = finState.historyDays[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: rec.isClosed
                                ? AppColors.success.withValues(alpha: 0.15)
                                : AppColors.primary.withValues(alpha: 0.15),
                            foregroundColor: rec.isClosed
                                ? AppColors.success
                                : AppColors.primary,
                            child: Icon(
                              rec.isClosed
                                  ? Icons.verified_rounded
                                  : Icons.timelapse_rounded,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            AppFormatters.sqlDateToBr(rec.date),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            '${rec.totalRentalsCount} locações registradas • '
                            'Status: ${rec.isClosed ? "Fechado / Consolidado" : "Em andamento"}',
                          ),
                          trailing: Text(
                            AppFormatters.currency(rec.totalRevenue),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmResetAndCloseDay(
    BuildContext context,
    WidgetRef ref,
    FinancialState finState,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock_clock_rounded, color: AppColors.primary),
            SizedBox(width: 10),
            Expanded(child: Text('Resetar / Fechar Expediente do Dia')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Esta ação irá consolidar os números atuais na tabela isolada '
              'daily_financial_stats com flag fechada (is_closed = 1) e '
              'reiniciar o painel de faturamento e gráficos para um novo expediente.',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Turno Atual: ${finState.currentShiftRentalsCount} aluguéis (${AppFormatters.currency(finState.currentShiftRevenue)})',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Total Consolidado no Dia: ${finState.consolidatedDayCount} aluguéis (${AppFormatters.currency(finState.consolidatedDayRevenue)})',
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.check_circle_outline_rounded),
            label: const Text('Consolidar e Reiniciar Expediente'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(financialControllerProvider.notifier).resetAndCloseDay();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Expediente consolidado em daily_financial_stats! Painel reiniciado.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _confirmClearDailyFinancialStats(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_sweep_rounded, color: AppColors.danger),
            SizedBox(width: 10),
            Expanded(child: Text('Apagar Fechamentos Diários')),
          ],
        ),
        content: const Text(
          'Deseja apagar todos os registros da tabela isolada de fechamentos diários (daily_financial_stats)?\n\n'
          'Esta ação removerá o histórico consolidado de dias anteriores e zerará as estatísticas acumuladas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.delete_forever_rounded),
            label: const Text('Apagar Todos os Fechamentos'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref
          .read(financialControllerProvider.notifier)
          .clearAllDailyFinancialStats();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Todos os fechamentos diários foram apagados com sucesso!',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

class _FinancialSummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color accentColor;

  const _FinancialSummaryCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: accentColor, size: 28),
            ),
            const SizedBox(width: 16),
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
                      fontWeight: FontWeight.w800,
                      color: accentColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
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

class _HourlyBarChartCard extends StatelessWidget {
  final List<HourlyMetric> metrics;

  const _HourlyBarChartCard({required this.metrics});

  @override
  Widget build(BuildContext context) {
    // Se ainda não houver métricas, exibe faixas padrão de operação (ex: 16-17 a 21-22) com zero
    final displayMetrics = metrics.isNotEmpty
        ? metrics
        : const [
            HourlyMetric(slot: '16-17', count: 0, revenue: 0),
            HourlyMetric(slot: '17-18', count: 0, revenue: 0),
            HourlyMetric(slot: '18-19', count: 0, revenue: 0),
            HourlyMetric(slot: '19-20', count: 0, revenue: 0),
            HourlyMetric(slot: '20-21', count: 0, revenue: 0),
            HourlyMetric(slot: '21-22', count: 0, revenue: 0),
          ];

    double maxCount = 5;
    for (final m in displayMetrics) {
      if (m.count > maxCount) {
        maxCount = m.count.toDouble() + 2;
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.bar_chart_rounded, color: AppColors.primary),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Aluguéis por Faixa Horária (h)',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Volume de locações e receita registrados em cada hora de operação',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 260,
              child: BarChart(
                BarChartData(
                  maxY: maxCount,
                  minY: 0,
                  alignment: BarChartAlignment.spaceAround,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 1,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Colors.grey.withValues(alpha: 0.18),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => AppColors.primaryDark,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final idx = group.x.toInt();
                        if (idx < 0 || idx >= displayMetrics.length) {
                          return null;
                        }
                        final item = displayMetrics[idx];
                        return BarTooltipItem(
                          '${item.slot}h\n',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          children: [
                            TextSpan(
                              text:
                                  '${item.count} aluguéis\n${AppFormatters.currency(item.revenue)}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          if (value % 1 != 0) return const SizedBox.shrink();
                          return SideTitleWidget(
                            meta: meta,
                            child: Text(
                              value.toInt().toString(),
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondaryLight,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 34,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= displayMetrics.length) {
                            return const SizedBox.shrink();
                          }
                          return SideTitleWidget(
                            meta: meta,
                            child: Text(
                              '${displayMetrics[idx].slot}h',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: List.generate(displayMetrics.length, (index) {
                    final metric = displayMetrics[index];
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: metric.count.toDouble(),
                          width: 24,
                          color: AppColors.primary,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(8),
                          ),
                          backDrawRodData: BackgroundBarChartRodData(
                            show: true,
                            toY: maxCount,
                            color: AppColors.primary.withValues(alpha: 0.06),
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryAndItemRankingCard extends StatelessWidget {
  final Map<String, int> categoryRanking;
  final Map<String, int> itemRanking;

  const _CategoryAndItemRankingCard({
    required this.categoryRanking,
    required this.itemRanking,
  });

  Color _categoryColor(String category) {
    switch (category) {
      case 'Bicicleta':
      case 'Bike':
        return AppColors.primary;
      case 'Carrinho':
        return const Color(0xFFE53935);
      default:
        return const Color(0xFF00ACC1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalCatCount = categoryRanking.values.fold<int>(0, (a, b) => a + b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.pie_chart_rounded, color: AppColors.primary),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Categorias & Ranking de Itens',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (totalCatCount == 0)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    'Conclua aluguéis para visualizar a distribuição por categoria e o ranking de equipamentos.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondaryLight),
                  ),
                ),
              )
            else ...[
              SizedBox(
                height: 160,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 3,
                    centerSpaceRadius: 34,
                    sections: categoryRanking.entries.map((entry) {
                      final pct = (entry.value / totalCatCount) * 100;
                      final color = _categoryColor(entry.key);
                      return PieChartSectionData(
                        value: entry.value.toDouble(),
                        color: color,
                        radius: 44,
                        title: '${pct.toStringAsFixed(0)}%',
                        titleStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: categoryRanking.entries.map((e) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _categoryColor(e.key),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${e.key}: ${e.value}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
              const Divider(height: 24),
              const Text(
                'Top Equipamentos Mais Alugados',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              const SizedBox(height: 8),
              ...itemRanking.entries.take(5).map((entry) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          entry.key,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${entry.value}x',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}
