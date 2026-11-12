import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/item_image_service.dart';
import '../../rentals/widgets/rental_card.dart';
import '../controllers/catalog_controller.dart';
import '../models/item_model.dart';

class CatalogView extends ConsumerWidget {
  const CatalogView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogState = ref.watch(catalogControllerProvider);
    final items = catalogState.filteredItems;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_catalog',
        onPressed: () => _openItemFormDialog(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Novo Item'),
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Catálogo de Equipamentos',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${catalogState.activeItems.length} ativos comigo • ${catalogState.items.length} cadastrados no total',
                      style: const TextStyle(
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
                SegmentedButton<CatalogFilter>(
                  segments: const [
                    ButtonSegment<CatalogFilter>(
                      value: CatalogFilter.activeOnly,
                      icon: Icon(Icons.check_circle_outline_rounded, size: 18),
                      label: Text('Apenas itens comigo / ativos'),
                    ),
                    ButtonSegment<CatalogFilter>(
                      value: CatalogFilter.all,
                      icon: Icon(Icons.grid_view_rounded, size: 18),
                      label: Text('Todos'),
                    ),
                  ],
                  selected: {catalogState.filter},
                  onSelectionChanged: (selection) {
                    ref
                        .read(catalogControllerProvider.notifier)
                        .setFilter(selection.first);
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: catalogState.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : items.isEmpty
                  ? _EmptyCatalogPlaceholder(
                      onAddPressed: () => _openItemFormDialog(context, ref),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        int crossAxisCount = 1;
                        if (width >= 1100) {
                          crossAxisCount = 4;
                        } else if (width >= 780) {
                          crossAxisCount = 3;
                        } else if (width >= 500) {
                          crossAxisCount = 2;
                        }

                        return GridView.builder(
                          padding: const EdgeInsets.only(bottom: 80),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                mainAxisExtent: 230,
                              ),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return _CatalogItemCard(
                              item: item,
                              onEdit: () =>
                                  _openItemFormDialog(context, ref, item: item),
                              onToggleActive: () => ref
                                  .read(catalogControllerProvider.notifier)
                                  .toggleItemActive(item),
                              onDelete: () =>
                                  _confirmDeleteItem(context, ref, item),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteItem(
    BuildContext context,
    WidgetRef ref,
    ItemModel item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Equipamento'),
        content: Text(
          'Deseja remover "${item.name}" do catálogo? Esta ação não pode ser desfeita.',
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

    if (confirmed == true && item.id != null) {
      await ref.read(catalogControllerProvider.notifier).deleteItem(item.id!);
      if (context.mounted) {
        final error = ref.read(catalogControllerProvider).errorMessage;
        if (error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error),
              backgroundColor: AppColors.danger,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Future<void> _openItemFormDialog(
    BuildContext context,
    WidgetRef ref, {
    ItemModel? item,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ItemFormDialog(existingItem: item),
    );
  }
}

class _CatalogItemCard extends StatelessWidget {
  final ItemModel item;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;

  const _CatalogItemCard({
    required this.item,
    required this.onEdit,
    required this.onToggleActive,
    required this.onDelete,
  });

  IconData _typeIcon(String type) {
    switch (type) {
      case 'Bicicleta':
      case 'Bike':
        return Icons.directions_bike_rounded;
      case 'Carrinho':
        return Icons.electric_rickshaw_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemColor = AppColors.fromHex(item.colorHex);

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: item.isActive
              ? itemColor.withValues(alpha: 0.75)
              : Colors.grey.withValues(alpha: 0.35),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 8,
            color: item.isActive ? itemColor : Colors.grey,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _ItemAvatarWidget(item: item, size: 54),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                decoration: item.isActive
                                    ? null
                                    : TextDecoration.lineThrough,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: itemColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: itemColor.withValues(alpha: 0.5),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _typeIcon(item.type),
                                        size: 13,
                                        color: itemColor,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        item.type,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: itemColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: itemColor,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    item.colorHex.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.contrastingTextColor(
                                        itemColor,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: onToggleActive,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                item.isActive
                                    ? Icons.check_circle_rounded
                                    : Icons.pause_circle_filled_rounded,
                                size: 18,
                                color: item.isActive
                                    ? AppColors.success
                                    : Colors.grey,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                item.isActive ? 'Comigo / Ativo' : 'Inativo',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: item.isActive
                                      ? AppColors.success
                                      : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Editar Item',
                            onPressed: onEdit,
                            icon: const Icon(Icons.edit_outlined, size: 20),
                          ),
                          IconButton(
                            tooltip: 'Excluir Item',
                            onPressed: onDelete,
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 20,
                              color: AppColors.danger,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemAvatarWidget extends StatelessWidget {
  final ItemModel item;
  final double size;

  const _ItemAvatarWidget({
    required this.item,
    this.size = 52,
  });

  @override
  Widget build(BuildContext context) {
    return RentalItemAvatar(
      itemName: item.name,
      photoPath: item.photoPath,
      colorHex: item.colorHex,
      itemType: item.type,
      size: size,
    );
  }
}

class _ItemFormDialog extends ConsumerStatefulWidget {
  final ItemModel? existingItem;

  const _ItemFormDialog({this.existingItem});

  @override
  ConsumerState<_ItemFormDialog> createState() => _ItemFormDialogState();
}

class _ItemFormDialogState extends ConsumerState<_ItemFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _photoPathController;
  late String _selectedType;
  late String _selectedColorHex;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    final item = widget.existingItem;
    _nameController = TextEditingController(text: item?.name ?? '');
    _photoPathController = TextEditingController(text: item?.photoPath ?? '');
    final initialType = item?.type ?? 'Bicicleta';
    _selectedType = (initialType == 'Bike') ? 'Bicicleta' : initialType;
    _selectedColorHex = item?.colorHex ?? AppColors.itemColorPalette.first;
    _isActive = item?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _photoPathController.dispose();
    super.dispose();
  }

  Future<void> _pickLocalImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
      );
      if (picked != null) {
        final permanentPath = await ItemImageService.instance
            .saveImageToAppStorage(picked.path);
        if (mounted) {
          setState(() {
            _photoPathController.text = permanentPath;
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Não foi possível abrir o seletor de imagem: $e'),
          backgroundColor: AppColors.warning,
        ),
      );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final model = ItemModel(
      id: widget.existingItem?.id,
      name: _nameController.text.trim(),
      type: _selectedType,
      colorHex: _selectedColorHex,
      photoPath: _photoPathController.text.trim().isEmpty
          ? null
          : _photoPathController.text.trim(),
      isActive: _isActive,
    );

    final notifier = ref.read(catalogControllerProvider.notifier);
    if (widget.existingItem == null) {
      await notifier.addItem(model);
    } else {
      await notifier.updateItem(model);
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingItem != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 740),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEditing
                          ? 'Editar Equipamento'
                          : 'Novo Equipamento no Catálogo',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Nome / Identificação do Item *',
                            hintText: 'Ex: Bicicleta Aro 29 Azul #04',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Informe o nome do equipamento';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedType,
                          decoration: const InputDecoration(
                            labelText: 'Categoria *',
                            prefixIcon: Icon(Icons.category_outlined),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Bicicleta',
                              child: Text('Bicicleta'),
                            ),
                            DropdownMenuItem(
                              value: 'Carrinho',
                              child: Text('Carrinho'),
                            ),
                            DropdownMenuItem(
                              value: 'Outro',
                              child: Text('Outro'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _selectedType = value);
                            }
                          },
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Cor do Equipamento (Paleta de 30 Cores)',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.fromHex(_selectedColorHex),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _selectedColorHex.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.contrastingTextColor(
                                    AppColors.fromHex(_selectedColorHex),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: AppColors.itemColorPalette.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 10,
                                mainAxisSpacing: 8,
                                crossAxisSpacing: 8,
                              ),
                          itemBuilder: (context, index) {
                            final hex = AppColors.itemColorPalette[index];
                            final color = AppColors.fromHex(hex);
                            final isSelected =
                                hex.toUpperCase() ==
                                _selectedColorHex.toUpperCase();

                            return InkWell(
                              onTap: () =>
                                  setState(() => _selectedColorHex = hex),
                              borderRadius: BorderRadius.circular(10),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.black87
                                        : Colors.transparent,
                                    width: isSelected ? 2.5 : 1,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: color.withValues(alpha: 0.5),
                                            blurRadius: 6,
                                            spreadRadius: 1,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: isSelected
                                    ? Icon(
                                        Icons.check_rounded,
                                        size: 18,
                                        color: AppColors.contrastingTextColor(
                                          color,
                                        ),
                                      )
                                    : null,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Foto do Equipamento (URL Web ou Arquivo Local)',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            RentalItemAvatar(
                              itemName: _nameController.text.trim().isEmpty
                                  ? 'Prévia do Item'
                                  : _nameController.text.trim(),
                              photoPath: _photoPathController.text.trim().isEmpty
                                  ? null
                                  : _photoPathController.text.trim(),
                              colorHex: _selectedColorHex,
                              itemType: _selectedType,
                              size: 52,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _photoPathController,
                                decoration: InputDecoration(
                                  labelText: 'URL ou Foto Salva no App (Opcional)',
                                  hintText: 'Selecione da galeria para salvar no app',
                                  prefixIcon: const Icon(Icons.image_outlined),
                                  suffixIcon:
                                      _photoPathController.text.isNotEmpty
                                      ? IconButton(
                                          onPressed: () {
                                            setState(() {
                                              _photoPathController.clear();
                                            });
                                          },
                                          icon: const Icon(Icons.clear_rounded),
                                        )
                                      : null,
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            const SizedBox(width: 10),
                            OutlinedButton.icon(
                              onPressed: _pickLocalImage,
                              icon: const Icon(Icons.photo_library_outlined),
                              label: const Text('Galeria'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Disponível fisicamente comigo (Ativo)',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: const Text(
                            'Itens ativos aparecem na seleção rápida de novo aluguel.',
                          ),
                          value: _isActive,
                          onChanged: (val) => setState(() => _isActive = val),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _submit,
                      icon: const Icon(Icons.check_rounded),
                      label: Text(
                        isEditing ? 'Salvar Alterações' : 'Cadastrar Item',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyCatalogPlaceholder extends StatelessWidget {
  final VoidCallback onAddPressed;

  const _EmptyCatalogPlaceholder({required this.onAddPressed});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.directions_bike_outlined,
            size: 64,
            color: AppColors.primary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 12),
          const Text(
            'Nenhum equipamento encontrado para este filtro.',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: onAddPressed,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Cadastrar Equipamento'),
          ),
        ],
      ),
    );
  }
}
