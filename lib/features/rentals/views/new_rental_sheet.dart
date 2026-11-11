import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../catalog/controllers/catalog_controller.dart';
import '../../catalog/models/item_model.dart';
import '../../settings/controllers/settings_controller.dart';
import '../controllers/rental_controller.dart';
import '../widgets/rental_card.dart';

class NewRentalSheet extends ConsumerStatefulWidget {
  const NewRentalSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const NewRentalSheet(),
    );
  }

  @override
  ConsumerState<NewRentalSheet> createState() => _NewRentalSheetState();
}

class _NewRentalSheetState extends ConsumerState<NewRentalSheet> {
  final Set<int> _selectedItemIds = {};
  late final TextEditingController _minutesController;
  late final TextEditingController _priceController;
  bool _hasAppliedInitialPreset = false;

  @override
  void initState() {
    super.initState();
    _minutesController = TextEditingController(text: '30');
    _priceController = TextEditingController(text: '15,00');
  }

  @override
  void dispose() {
    _minutesController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _applyCategoryPreset(String category) {
    final settings = ref.read(settingsControllerProvider);
    final preset = settings.presetFor(category);
    _minutesController.text = preset.defaultMinutes.toString();
    _priceController.text = preset.defaultPrice
        .toStringAsFixed(2)
        .replaceAll('.', ',');
  }

  void _toggleItemSelection(ItemModel item) {
    final id = item.id;
    if (id == null) return;

    setState(() {
      if (_selectedItemIds.contains(id)) {
        _selectedItemIds.remove(id);
      } else {
        final wasEmpty = _selectedItemIds.isEmpty;
        _selectedItemIds.add(id);
        if (wasEmpty) {
          _applyCategoryPreset(item.type);
        }
      }
    });
  }

  void _addQuickMinutes(int deltaMinutes) {
    final current = int.tryParse(_minutesController.text.trim()) ?? 0;
    final updated = (current + deltaMinutes).clamp(1, 1440);
    setState(() {
      _minutesController.text = updated.toString();
    });
  }

  void _setExactMinutes(int minutes) {
    setState(() {
      _minutesController.text = minutes.toString();
    });
  }

  Future<void> _confirmBatchRentals() async {
    if (_selectedItemIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione pelo menos 1 equipamento para alugar.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final durationMinutes = int.tryParse(_minutesController.text.trim()) ?? 30;
    final basePrice = AppFormatters.parseCurrency(
      _priceController.text,
      fallback: 15.0,
    );

    final validMinutes = durationMinutes < 1 ? 1 : durationMinutes;
    final validPrice = basePrice < 0 ? 0.0 : basePrice;

    final requests = _selectedItemIds.map((itemId) {
      return BatchRentalRequestItem(
        itemId: itemId,
        durationMinutes: validMinutes,
        basePrice: validPrice,
      );
    }).toList();

    await ref
        .read(rentalControllerProvider.notifier)
        .createBatchRentals(requests);

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            requests.length == 1
                ? 'Aluguel iniciado com sucesso!'
                : '${requests.length} aluguéis iniciados em lote com sucesso!',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalogState = ref.watch(catalogControllerProvider);
    final rentalsState = ref.watch(rentalControllerProvider);
    final settingsState = ref.watch(settingsControllerProvider);

    if (!_hasAppliedInitialPreset && settingsState.isLoaded) {
      final bikePreset = settingsState.presetFor('Bike');
      _minutesController.text = bikePreset.defaultMinutes.toString();
      _priceController.text = bikePreset.defaultPrice
          .toStringAsFixed(2)
          .replaceAll('.', ',');
      _hasAppliedInitialPreset = true;
    }

    final activeItems = catalogState.activeItems;
    final busyIds = rentalsState.busyItemIds;

    return Container(
      constraints: const BoxConstraints(maxWidth: 720, maxHeight: 780),
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
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E88E5), Color(0xFF0D47A1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.8),
                    width: 1.2,
                  ),
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '+ Novo Aluguel (Individual ou Lote)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${_selectedItemIds.length} equipamento(s) selecionado(s)',
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
          const Divider(height: 24),
          const Text(
            'Selecione um ou mais equipamentos disponíveis:',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 10),
          Flexible(
            child: activeItems.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Nenhum item ativo no catálogo. Cadastre ou ative itens na aba Catálogo.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: activeItems.length,
                    itemBuilder: (context, index) {
                      final item = activeItems[index];
                      final itemId = item.id!;
                      final isSelected = _selectedItemIds.contains(itemId);
                      final isBusy = busyIds.contains(itemId);
                      final itemColor = AppColors.fromHex(item.colorHex);
                      final preset = settingsState.presetFor(item.type);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: isSelected
                                ? AppColors.primary
                                : itemColor.withValues(alpha: 0.45),
                            width: isSelected ? 2.2 : 1.2,
                          ),
                        ),
                        child: CheckboxListTile(
                          value: isSelected,
                          onChanged: (_) => _toggleItemSelection(item),
                          secondary: RentalItemAvatar(
                            photoPath: item.photoPath,
                            colorHex: item.colorHex,
                            itemType: item.type,
                            size: 44,
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (isBusy)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.warning.withValues(
                                      alpha: 0.16,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text(
                                    'Alugado agora',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.warning,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Text(
                            '${item.type} • Padrão: ${preset.defaultMinutes} min / ${AppFormatters.currency(preset.defaultPrice)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const Divider(height: 24),
          const Text(
            'Tempo e Valor por Equipamento (Atalhos Rápidos):',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: () => _addQuickMinutes(15),
                icon: const Icon(Icons.add_alarm_rounded, size: 18),
                label: const Text('+15 min'),
              ),
              FilledButton.tonalIcon(
                onPressed: () => _addQuickMinutes(30),
                icon: const Icon(Icons.add_alarm_rounded, size: 18),
                label: const Text('+30 min'),
              ),
              FilledButton.tonalIcon(
                onPressed: () => _addQuickMinutes(60),
                icon: const Icon(Icons.add_alarm_rounded, size: 18),
                label: const Text('+1h'),
              ),
              ActionChip(
                label: const Text('Fixar 15m'),
                onPressed: () => _setExactMinutes(15),
              ),
              ActionChip(
                label: const Text('Fixar 30m'),
                onPressed: () => _setExactMinutes(30),
              ),
              ActionChip(
                label: const Text('Fixar 1h'),
                onPressed: () => _setExactMinutes(60),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _minutesController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Tempo (minutos)',
                    prefixIcon: Icon(Icons.timer_outlined),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: TextFormField(
                  controller: _priceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Valor Unitário (R\$)',
                    prefixIcon: Icon(Icons.attach_money_rounded),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _confirmBatchRentals,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(
                _selectedItemIds.isEmpty
                    ? 'Iniciar Aluguel'
                    : _selectedItemIds.length > 1
                        ? 'Iniciar ${_selectedItemIds.length} Aluguéis'
                        : 'Iniciar Aluguel deste item',

                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
