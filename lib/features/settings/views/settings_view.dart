import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/utils/formatters.dart';
import '../../catalog/controllers/catalog_controller.dart';
import '../../financial/controllers/financial_controller.dart';
import '../../rentals/controllers/rental_controller.dart';
import '../controllers/settings_controller.dart';

class SettingsView extends ConsumerStatefulWidget {
  const SettingsView({super.key});

  @override
  ConsumerState<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends ConsumerState<SettingsView> {
  final Map<String, TextEditingController> _priceControllers = {};
  final Map<String, TextEditingController> _minutesControllers = {};
  late final TextEditingController _surchargeMinuteController;
  bool _initializedFromState = false;

  @override
  void initState() {
    super.initState();
    final initialSettings = ref.read(settingsControllerProvider);
    for (final cat in SettingsController.categories) {
      final preset = initialSettings.presetFor(cat);
      _priceControllers[cat] = TextEditingController(
        text: preset.defaultPrice.toStringAsFixed(2).replaceAll('.', ','),
      );
      _minutesControllers[cat] = TextEditingController(
        text: preset.defaultMinutes.toString(),
      );
    }
    _surchargeMinuteController = TextEditingController(
      text: initialSettings.surchargeStartMinute.toString(),
    );
    _initializedFromState = initialSettings.isLoaded;
  }

  void _syncControllers(AppSettingsState settings) {
    for (final cat in SettingsController.categories) {
      final preset = settings.presetFor(cat);
      _priceControllers[cat]?.text = preset.defaultPrice
          .toStringAsFixed(2)
          .replaceAll('.', ',');
      _minutesControllers[cat]?.text = preset.defaultMinutes.toString();
    }
    _surchargeMinuteController.text = settings.surchargeStartMinute.toString();
  }

  @override
  void dispose() {
    for (final c in _priceControllers.values) {
      c.dispose();
    }
    for (final c in _minutesControllers.values) {
      c.dispose();
    }
    _surchargeMinuteController.dispose();
    super.dispose();
  }

  IconData _iconForCategory(String category) {
    switch (category) {
      case 'Bicicleta':
      case 'Bike':
        return Icons.directions_bike_rounded;
      case 'Carrinho':
        return Icons.electric_rickshaw_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  Future<void> _saveSettings() async {
    final currentPresets = <String, CategoryPreset>{};
    for (final cat in SettingsController.categories) {
      final price = AppFormatters.parseCurrency(
        _priceControllers[cat]?.text ?? '15,00',
        fallback: 15.0,
      );
      final mins =
          int.tryParse(_minutesControllers[cat]?.text.trim() ?? '30') ?? 30;
      currentPresets[cat] = CategoryPreset(
        category: cat,
        defaultPrice: price < 0 ? 0.0 : price,
        defaultMinutes: mins < 1 ? 1 : mins,
      );
    }

    final surchargeMin =
        (int.tryParse(_surchargeMinuteController.text.trim()) ?? 4).clamp(
          1,
          120,
        );
    _surchargeMinuteController.text = surchargeMin.toString();

    await ref
        .read(settingsControllerProvider.notifier)
        .saveAllPresets(currentPresets, surchargeStartMinute: surchargeMin);
    await ref.read(rentalControllerProvider.notifier).loadRentals();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Configurações padrão e regra de acréscimo salvas com sucesso!',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AppSettingsState>(settingsControllerProvider, (prev, next) {
      if (!_initializedFromState && next.isLoaded) {
        _syncControllers(next);
        _initializedFromState = true;
      }
    });

    final settingsState = ref.watch(settingsControllerProvider);
    final isDark = settingsState.themeMode == ThemeMode.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.tune_rounded,
                      color: AppColors.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Parâmetros Operacionais',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Defina o valor base e o tempo padrão para preenchimento automático de novos aluguéis.',
                          style: TextStyle(color: AppColors.textSecondaryLight),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ...SettingsController.categories.map((cat) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: AppColors.primary.withValues(
                                  alpha: 0.12,
                                ),
                                foregroundColor: AppColors.primary,
                                child: Icon(_iconForCategory(cat)),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Categoria: $cat',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _priceControllers[cat],
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: const InputDecoration(
                                    labelText: 'Preço Padrão (R\$)',
                                    prefixIcon: Icon(Icons.attach_money_rounded),
                                    helperText: 'Ex: 15,00',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextFormField(
                                  controller: _minutesControllers[cat],
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Tempo Padrão (minutos)',
                                    prefixIcon: Icon(Icons.timer_outlined),
                                    helperText: 'Ex: 30',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _QuickMinuteChip(
                                label: '15 min',
                                onTap: () {
                                  setState(() {
                                    _minutesControllers[cat]?.text = '15';
                                  });
                                },
                              ),
                              _QuickMinuteChip(
                                label: '30 min',
                                onTap: () {
                                  setState(() {
                                    _minutesControllers[cat]?.text = '30';
                                  });
                                },
                              ),
                              _QuickMinuteChip(
                                label: '60 min (1h)',
                                onTap: () {
                                  setState(() {
                                    _minutesControllers[cat]?.text = '60';
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 8),
              // Card de Configuração do Tempo para Iniciar Acréscimo
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: AppColors.warning.withValues(alpha: 0.45),
                    width: 1.5,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Builder(
                    builder: (context) {
                      final currentMin =
                          (int.tryParse(
                                _surchargeMinuteController.text.trim(),
                              ) ??
                              settingsState.surchargeStartMinute)
                              .clamp(1, 120);
                      final toleranceMin = (currentMin - 1).clamp(0, 119);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: AppColors.warning.withValues(
                                  alpha: 0.15,
                                ),
                                foregroundColor: AppColors.warning,
                                child: const Icon(Icons.timer_rounded),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Tempo até Começar a Contar o Acréscimo',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Escolha em qual minuto de atraso começa a adicionar R\$ 1,00 (ex: 3 min, 4 min, 5 min).',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: AppColors.textSecondaryLight,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              IconButton.filledTonal(
                                onPressed: () {
                                  final next = (currentMin - 1).clamp(1, 120);
                                  setState(() {
                                    _surchargeMinuteController.text = next
                                        .toString();
                                  });
                                  ref
                                      .read(settingsControllerProvider.notifier)
                                      .updateSurchargeStartMinute(next);
                                  ref
                                      .read(rentalControllerProvider.notifier)
                                      .loadRentals();
                                },
                                icon: const Icon(Icons.remove_rounded),
                                tooltip: 'Diminuir 1 minuto',
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _surchargeMinuteController,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  decoration: const InputDecoration(
                                    labelText:
                                        'Minuto de Início do Acréscimo (min)',
                                    prefixIcon: Icon(
                                      Icons.av_timer_rounded,
                                      color: AppColors.warning,
                                    ),
                                    helperText:
                                        'Minuto de atraso em que soma R\$ 1,00 inicial',
                                  ),
                                  onChanged: (val) {
                                    final parsed = int.tryParse(val.trim());
                                    if (parsed != null && parsed >= 1) {
                                      setState(() {});
                                      ref
                                          .read(
                                            settingsControllerProvider.notifier,
                                          )
                                          .updateSurchargeStartMinute(parsed);
                                      ref
                                          .read(
                                            rentalControllerProvider.notifier,
                                          )
                                          .loadRentals();
                                    } else {
                                      setState(() {});
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              IconButton.filledTonal(
                                onPressed: () {
                                  final next = (currentMin + 1).clamp(1, 120);
                                  setState(() {
                                    _surchargeMinuteController.text = next
                                        .toString();
                                  });
                                  ref
                                      .read(settingsControllerProvider.notifier)
                                      .updateSurchargeStartMinute(next);
                                  ref
                                      .read(rentalControllerProvider.notifier)
                                      .loadRentals();
                                },
                                icon: const Icon(Icons.add_rounded),
                                tooltip: 'Aumentar 1 minuto',
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [1, 2, 3, 4, 5, 6, 10].map((m) {
                              final isSelected = currentMin == m;
                              return ChoiceChip(
                                label: Text(
                                  m == 4 ? '$m min (Padrão)' : '$m min',
                                  style: TextStyle(
                                    fontWeight: isSelected
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                  ),
                                ),
                                selected: isSelected,
                                selectedColor: AppColors.warning.withValues(
                                  alpha: 0.25,
                                ),
                                onSelected: (_) {
                                  setState(() {
                                    _surchargeMinuteController.text = m
                                        .toString();
                                  });
                                  ref
                                      .read(settingsControllerProvider.notifier)
                                      .updateSurchargeStartMinute(m);
                                  ref
                                      .read(rentalControllerProvider.notifier)
                                      .loadRentals();
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.info_outline_rounded,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    toleranceMin == 0
                                        ? 'Regra Ativa: Sem tolerância. Ao atingir 1 minuto de atraso, adiciona-se R\$ 1,00 + R\$ 1,00 por minuto completo adicional.'
                                        : 'Regra Ativa: Tolerância de $toleranceMin minuto(s) após o término previsto. '
                                              'A partir do $currentMinº minuto de atraso, adiciona-se R\$ 1,00 + R\$ 1,00 por minuto completo adicional.',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: SwitchListTile(
                  secondary: Icon(
                    isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                    color: AppColors.primary,
                  ),
                  title: const Text(
                    'Modo Noturno (#0F172A)',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'Alterna entre a superfície clara (#F8FAFC) e o tema escuro de alto contraste.',
                  ),
                  value: isDark,
                  onChanged: (value) {
                    ref
                        .read(settingsControllerProvider.notifier)
                        .toggleThemeMode(value);
                  },
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _saveSettings,
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('Salvar Configurações Padrão'),
                ),
              ),
              const SizedBox(height: 24),
              Card(
                color: AppColors.danger.withValues(alpha: 0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: AppColors.danger.withValues(alpha: 0.3)),
                ),
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.restart_alt_rounded, color: AppColors.danger),
                          SizedBox(width: 10),
                          Text(
                            'Zona de Manutenção • Zerar Aplicativo',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.danger,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Apaga todos os aluguéis ativos e histórico, zera o faturamento diário '
                        'e restaura o catálogo inicial de fábrica. Ideal para deixar a base 100% limpa antes de publicar.',
                        style: TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.danger,
                            side: const BorderSide(color: AppColors.danger, width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => _confirmResetEntireApp(context),
                          icon: const Icon(Icons.delete_forever_rounded),
                          label: const Text(
                            'Zerar Todo o App (Restaurar de Fábrica)',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmResetEntireApp(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.danger),
            SizedBox(width: 10),
            Expanded(child: Text('Resetar Todo o App?')),
          ],
        ),
        content: const Text(
          'Atenção: Esta ação irá apagar:\n\n'
          '• Todos os aluguéis ativos e histórico\n'
          '• Todas as estatísticas de fechamentos diários\n'
          '• Restaurará o catálogo original padrão de fábrica\n\n'
          'O banco de dados ficará 100% zerado e pronto para produção.',
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
            label: const Text('Zerar Tudo Agora'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await DatabaseHelper.instance.resetEntireAppDatabase();
      await ref.read(rentalControllerProvider.notifier).loadRentals();
      await ref.read(catalogControllerProvider.notifier).loadItems();
      await ref.read(financialControllerProvider.notifier).loadFinancialStats();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'O aplicativo foi completamente zerado e restaurado!',
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

class _QuickMinuteChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickMinuteChip({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: const Icon(Icons.schedule_rounded, size: 16),
      label: Text(label),
      onPressed: onTap,
    );
  }
}
