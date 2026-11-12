import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../catalog/models/item_model.dart';
import '../models/rental_model.dart';
import 'rental_card.dart';

/// Janela flutuante personalizada e moderna para trocar o equipamento de um aluguel ativo.
class CustomChangeItemModal extends StatefulWidget {
  final RentalModel rental;
  final List<ItemModel> catalogItems;
  final Set<int> busyIds;

  const CustomChangeItemModal({
    super.key,
    required this.rental,
    required this.catalogItems,
    required this.busyIds,
  });

  static Future<int?> show(
    BuildContext context, {
    required RentalModel rental,
    required List<ItemModel> catalogItems,
    required Set<int> busyIds,
  }) {
    return showGeneralDialog<int>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Fechar troca de equipamento',
      barrierColor: Colors.black.withValues(alpha: 0.65),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, anim1, anim2) {
        return CustomChangeItemModal(
          rental: rental,
          catalogItems: catalogItems,
          busyIds: busyIds,
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curved = CurvedAnimation(
          parent: anim1,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeInCubic,
        );
        return BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 5.0 * anim1.value,
            sigmaY: 5.0 * anim1.value,
          ),
          child: FadeTransition(
            opacity: anim1,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.9, end: 1.0).animate(curved),
              child: child,
            ),
          ),
        );
      },
    );
  }

  @override
  State<CustomChangeItemModal> createState() => _CustomChangeItemModalState();
}

class _CustomChangeItemModalState extends State<CustomChangeItemModal> {
  late int _selectedId;
  String _selectedCategory = 'Todos';

  @override
  void initState() {
    super.initState();
    _selectedId = widget.rental.itemId;
  }

  List<ItemModel> get _filteredItems {
    if (_selectedCategory == 'Todos') {
      return widget.catalogItems;
    }
    return widget.catalogItems
        .where((i) => i.type == _selectedCategory)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final selectedItem = widget.catalogItems
        .where((i) => i.id == _selectedId)
        .firstOrNull;
    final currentColor = AppColors.fromHex(widget.rental.itemColorHex);
    final newColor = selectedItem != null
        ? AppColors.fromHex(selectedItem.colorHex)
        : currentColor;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Material(
          color: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540, maxHeight: 680),
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: newColor.withValues(alpha: 0.65),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Cabeçalho Personalizado
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 18,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primaryDark,
                          newColor.withValues(alpha: 0.85),
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
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.35),
                            ),
                          ),
                          child: const Icon(
                            Icons.swap_horiz_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Modificar Equipamento',
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Toque na foto para ampliar ou no card para selecionar',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black.withValues(alpha: 0.2),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded, size: 20),
                        ),
                      ],
                    ),
                  ),

                  // Painel Comparativo: Atual -> Novo
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: newColor.withValues(alpha: 0.35),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              RentalItemAvatar(
                                itemName: widget.rental.itemName,
                                photoPath: widget.rental.itemPhotoPath,
                                colorHex: widget.rental.itemColorHex,
                                itemType: widget.rental.itemType,
                                size: 40,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'ATUAL',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textSecondaryLight,
                                      ),
                                    ),
                                    Text(
                                      widget.rental.itemName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_forward_rounded,
                              size: 16,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Row(
                            children: [
                              RentalItemAvatar(
                                itemName:
                                    selectedItem?.name ?? widget.rental.itemName,
                                photoPath: selectedItem?.photoPath ??
                                    widget.rental.itemPhotoPath,
                                colorHex: selectedItem?.colorHex ??
                                    widget.rental.itemColorHex,
                                itemType: selectedItem?.type ??
                                    widget.rental.itemType,
                                size: 40,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _selectedId == widget.rental.itemId
                                          ? 'MANTIDO'
                                          : 'NOVO ESCOLHIDO',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: _selectedId ==
                                                widget.rental.itemId
                                            ? AppColors.textSecondaryLight
                                            : AppColors.success,
                                      ),
                                    ),
                                    Text(
                                      selectedItem?.name ??
                                          widget.rental.itemName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: newColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Filtros de Categoria
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: ['Todos', 'Bicicleta', 'Carrinho', 'Outro']
                            .map((cat) {
                          final isSelected = _selectedCategory == cat;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(
                                cat,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                ),
                              ),
                              selected: isSelected,
                              onSelected: (_) {
                                setState(() => _selectedCategory = cat);
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1),

                  // Lista de Equipamentos
                  Flexible(
                    child: _filteredItems.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(
                              child: Text(
                                'Nenhum equipamento ativo nesta categoria.',
                                style: TextStyle(
                                  color: AppColors.textSecondaryLight,
                                ),
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            shrinkWrap: true,
                            itemCount: _filteredItems.length,
                            itemBuilder: (ctx, index) {
                              final item = _filteredItems[index];
                              final itemId = item.id;
                              if (itemId == null) {
                                return const SizedBox.shrink();
                              }
                              final isSelected = _selectedId == itemId;
                              final isCurrent = widget.rental.itemId == itemId;
                              final isBusyOther =
                                  widget.busyIds.contains(itemId) && !isCurrent;
                              final itemColor = AppColors.fromHex(
                                item.colorHex,
                              );

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: isBusyOther
                                        ? null
                                        : () {
                                            setState(
                                              () => _selectedId = itemId,
                                            );
                                          },
                                    borderRadius: BorderRadius.circular(16),
                                    child: Opacity(
                                      opacity: isBusyOther ? 0.45 : 1.0,
                                      child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 180,
                                      ),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? itemColor.withValues(alpha: 0.14)
                                            : Theme.of(context).cardColor,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: isSelected
                                              ? itemColor
                                              : itemColor.withValues(
                                                  alpha: 0.35,
                                                ),
                                          width: isSelected ? 2.4 : 1.2,
                                        ),
                                        boxShadow: isSelected
                                            ? [
                                                BoxShadow(
                                                  color: itemColor.withValues(
                                                    alpha: 0.22,
                                                  ),
                                                  blurRadius: 10,
                                                  offset: const Offset(0, 3),
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 5,
                                            height: 48,
                                            decoration: BoxDecoration(
                                              color: itemColor,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          RentalItemAvatar(
                                            itemName: item.name,
                                            photoPath: item.photoPath,
                                            colorHex: item.colorHex,
                                            itemType: item.type,
                                            size: 48,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
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
                                                          fontSize: 15,
                                                        ),
                                                      ),
                                                    ),
                                                    if (isCurrent)
                                                      _StatusPill(
                                                        label: 'Item Atual',
                                                        color:
                                                            AppColors.primary,
                                                      )
                                                    else if (isBusyOther)
                                                      _StatusPill(
                                                        label: 'Em uso',
                                                        color:
                                                            AppColors.warning,
                                                      )
                                                    else
                                                      _StatusPill(
                                                        label: 'Livre',
                                                        color:
                                                            AppColors.success,
                                                      ),
                                                  ],
                                                ),
                                                const SizedBox(height: 5),
                                                Row(
                                                  children: [
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 7,
                                                            vertical: 2,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: itemColor
                                                            .withValues(
                                                              alpha: 0.16,
                                                            ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              6,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        item.type,
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.w700,
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
                                                      item.colorHex
                                                          .toUpperCase(),
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: itemColor,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          AnimatedContainer(
                                            duration: const Duration(
                                              milliseconds: 150,
                                            ),
                                            width: 26,
                                            height: 26,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: isSelected
                                                  ? itemColor
                                                  : Colors.transparent,
                                              border: Border.all(
                                                color: isSelected
                                                    ? itemColor
                                                    : Colors.grey.withValues(
                                                        alpha: 0.45,
                                                      ),
                                                width: 2,
                                              ),
                                            ),
                                            child: isSelected
                                                ? Icon(
                                                    Icons.check_rounded,
                                                    size: 17,
                                                    color: AppColors
                                                        .contrastingTextColor(
                                                          itemColor,
                                                        ),
                                                  )
                                                : null,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                          ),
                  ),

                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 13,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () =>
                              Navigator.of(context).pop(_selectedId),
                          icon: const Icon(
                            Icons.check_circle_outline_rounded,
                            size: 18,
                          ),
                          label: const Text(
                            'Confirmar Equipamento',
                            style: TextStyle(fontWeight: FontWeight.w800),
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
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

/// Janela flutuante personalizada e moderna para alterar o valor de um aluguel
/// (funciona tanto para aluguéis ativos quanto para aluguéis recentes no Histórico).
class CustomChangePriceModal extends StatefulWidget {
  final RentalModel rental;
  final bool isHistoryRental;

  const CustomChangePriceModal({
    super.key,
    required this.rental,
    this.isHistoryRental = false,
  });

  static Future<double?> show(
    BuildContext context, {
    required RentalModel rental,
    bool isHistoryRental = false,
  }) {
    return showGeneralDialog<double>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Fechar edição de valor',
      barrierColor: Colors.black.withValues(alpha: 0.65),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, anim1, anim2) {
        return CustomChangePriceModal(
          rental: rental,
          isHistoryRental: isHistoryRental,
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curved = CurvedAnimation(
          parent: anim1,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeInCubic,
        );
        return BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 5.0 * anim1.value,
            sigmaY: 5.0 * anim1.value,
          ),
          child: FadeTransition(
            opacity: anim1,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.9, end: 1.0).animate(curved),
              child: child,
            ),
          ),
        );
      },
    );
  }

  @override
  State<CustomChangePriceModal> createState() => _CustomChangePriceModalState();
}

class _CustomChangePriceModalState extends State<CustomChangePriceModal> {
  late final TextEditingController _controller;
  late final double _initialPrice;
  late double _previewPrice;

  @override
  void initState() {
    super.initState();
    _initialPrice = widget.isHistoryRental
        ? widget.rental.totalPaid
        : widget.rental.basePrice;
    _previewPrice = _initialPrice;
    _controller = TextEditingController(
      text: _initialPrice.toStringAsFixed(2).replaceAll('.', ','),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setPrice(double value) {
    final sanitized = value.clamp(0.0, 99999.0);
    setState(() {
      _previewPrice = sanitized;
      _controller.text = sanitized.toStringAsFixed(2).replaceAll('.', ',');
    });
  }

  void _adjustDelta(double delta) {
    final current = AppFormatters.parseCurrency(
      _controller.text,
      fallback: _previewPrice,
    );
    _setPrice(current + delta);
  }

  @override
  Widget build(BuildContext context) {
    final itemColor = AppColors.fromHex(widget.rental.itemColorHex);
    final diff = _previewPrice - _initialPrice;
    final endTime =
        widget.rental.actualEndTime ?? widget.rental.plannedEndTime;

    return Center(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Material(
          color: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 490),
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: itemColor.withValues(alpha: 0.7),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.42),
                    blurRadius: 26,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Cabeçalho com Gradiente Personalizado
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 18,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primaryDark,
                            itemColor.withValues(alpha: 0.85),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Row(
                        children: [
                          RentalItemAvatar(
                            itemName: widget.rental.itemName,
                            photoPath: widget.rental.itemPhotoPath,
                            colorHex: widget.rental.itemColorHex,
                            itemType: widget.rental.itemType,
                            size: 48,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.2,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        widget.isHistoryRental
                                            ? 'ALUGUEL RECENTE • HISTÓRICO'
                                            : 'ALUGUEL EM ANDAMENTO',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.isHistoryRental
                                      ? 'Modificar Valor Pago'
                                      : 'Modificar Valor do Aluguel',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  '${widget.rental.itemName} • ${AppFormatters.timeShort(widget.rental.startTime)} às ${AppFormatters.timeShort(endTime)}',
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
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black.withValues(
                                alpha: 0.2,
                              ),
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded, size: 20),
                          ),
                        ],
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Display Principal estilo Fintech
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.primary.withValues(alpha: 0.1),
                                  itemColor.withValues(alpha: 0.06),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: AppColors.primary.withValues(
                                  alpha: 0.35,
                                ),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Valor Anterior',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: AppColors.textSecondaryLight,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      AppFormatters.currency(_initialPrice),
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: diff.abs() < 0.01
                                        ? Colors.grey.withValues(alpha: 0.15)
                                        : (diff > 0
                                              ? AppColors.success.withValues(
                                                  alpha: 0.18,
                                                )
                                              : AppColors.warning.withValues(
                                                  alpha: 0.18,
                                                )),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    diff.abs() < 0.01
                                        ? 'Igual'
                                        : (diff > 0
                                              ? '+${AppFormatters.currency(diff)}'
                                              : '-${AppFormatters.currency(diff.abs())}'),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: diff.abs() < 0.01
                                          ? AppColors.textSecondaryLight
                                          : (diff > 0
                                                ? AppColors.success
                                                : AppColors.warning),
                                    ),
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text(
                                      'Novo Valor',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: AppColors.textSecondaryLight,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      AppFormatters.currency(_previewPrice),
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.success,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Campo de digitação personalizada com botões - / +
                          Row(
                            children: [
                              IconButton.filledTonal(
                                onPressed: () => _adjustDelta(-1.0),
                                icon: const Icon(Icons.remove_rounded),
                                tooltip: '- R\$ 1,00',
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextFormField(
                                  controller: _controller,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: widget.isHistoryRental
                                        ? 'Valor Total Pago (R\$)'
                                        : 'Valor Base (R\$)',
                                    prefixIcon: const Icon(
                                      Icons.payments_rounded,
                                      color: AppColors.primary,
                                    ),
                                    suffixIcon: _controller.text.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(
                                              Icons.clear_rounded,
                                              size: 18,
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                _controller.clear();
                                                _previewPrice = 0.0;
                                              });
                                            },
                                          )
                                        : null,
                                  ),
                                  onChanged: (val) {
                                    setState(() {
                                      _previewPrice =
                                          AppFormatters.parseCurrency(
                                            val,
                                            fallback: 0.0,
                                          );
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              IconButton.filledTonal(
                                onPressed: () => _adjustDelta(1.0),
                                icon: const Icon(Icons.add_rounded),
                                tooltip: '+ R\$ 1,00',
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Botões de ajuste rápido (+ / -)
                          const Text(
                            'Ajustes Rápidos (+ / -):',
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
                              _DeltaButton(
                                label: '-R\$ 5',
                                isNegative: true,
                                onTap: () => _adjustDelta(-5.0),
                              ),
                              _DeltaButton(
                                label: '-R\$ 2',
                                isNegative: true,
                                onTap: () => _adjustDelta(-2.0),
                              ),
                              _DeltaButton(
                                label: '+R\$ 2',
                                onTap: () => _adjustDelta(2.0),
                              ),
                              _DeltaButton(
                                label: '+R\$ 5',
                                onTap: () => _adjustDelta(5.0),
                              ),
                              _DeltaButton(
                                label: '+R\$ 10',
                                onTap: () => _adjustDelta(10.0),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Valores Prontos de 1 Toque
                          const Text(
                            'Valores Prontos (1 toque):',
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
                            children: [10.0, 15.0, 20.0, 25.0, 30.0, 40.0, 50.0]
                                .map((val) {
                                  final isSelected =
                                      (_previewPrice - val).abs() < 0.01;
                                  return ChoiceChip(
                                    label: Text(
                                      'R\$ ${val.toInt()}',
                                      style: TextStyle(
                                        fontWeight: isSelected
                                            ? FontWeight.w800
                                            : FontWeight.w600,
                                      ),
                                    ),
                                    selected: isSelected,
                                    selectedColor: AppColors.primary.withValues(
                                      alpha: 0.22,
                                    ),
                                    onSelected: (_) => _setPrice(val),
                                  );
                                })
                                .toList(),
                          ),

                          if (widget.isHistoryRental) ...[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(
                                  alpha: 0.08,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.sync_rounded,
                                    size: 16,
                                    color: AppColors.primary,
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Ao salvar, o novo valor também será atualizado automaticamente na aba Financeiro.',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancelar'),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 13,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () {
                              final parsed = AppFormatters.parseCurrency(
                                _controller.text,
                                fallback: _previewPrice,
                              );
                              Navigator.of(context).pop(parsed);
                            },
                            icon: const Icon(
                              Icons.check_circle_outline_rounded,
                              size: 18,
                            ),
                            label: const Text(
                              'Salvar Novo Valor',
                              style: TextStyle(fontWeight: FontWeight.w800),
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
      ),
    );
  }
}

class _DeltaButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isNegative;

  const _DeltaButton({
    required this.label,
    required this.onTap,
    this.isNegative = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isNegative ? AppColors.danger : AppColors.success;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ),
    );
  }
}
