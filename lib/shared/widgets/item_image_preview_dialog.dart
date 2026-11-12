import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/item_image_service.dart';

/// Janela flutuante de visualização nítida da foto/ícone de um equipamento,
/// com suporte a zoom interativo (pinça e toque duplo) e detalhes visuais.
class ItemImagePreviewDialog extends StatefulWidget {
  final String itemName;
  final String itemType;
  final String colorHex;
  final String? photoPath;

  const ItemImagePreviewDialog({
    super.key,
    required this.itemName,
    required this.itemType,
    required this.colorHex,
    this.photoPath,
  });

  static Future<void> show(
    BuildContext context, {
    required String itemName,
    required String itemType,
    required String colorHex,
    String? photoPath,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Fechar visualização de imagem',
      barrierColor: Colors.black.withValues(alpha: 0.72),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, anim1, anim2) {
        return ItemImagePreviewDialog(
          itemName: itemName,
          itemType: itemType,
          colorHex: colorHex,
          photoPath: photoPath,
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
            sigmaX: 6.0 * anim1.value,
            sigmaY: 6.0 * anim1.value,
          ),
          child: FadeTransition(
            opacity: anim1,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.86, end: 1.0).animate(curved),
              child: child,
            ),
          ),
        );
      },
    );
  }

  @override
  State<ItemImagePreviewDialog> createState() => _ItemImagePreviewDialogState();
}

class _ItemImagePreviewDialogState extends State<ItemImagePreviewDialog> {
  final TransformationController _transformController =
      TransformationController();
  bool _isZoomed = false;

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  void _toggleZoom() {
    setState(() {
      if (_isZoomed) {
        _transformController.value = Matrix4.identity();
        _isZoomed = false;
      } else {
        _transformController.value = Matrix4.diagonal3Values(2.2, 2.2, 1.0);
        _isZoomed = true;
      }
    });
  }

  IconData _iconForType(String type) {
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
    final itemColor = AppColors.fromHex(widget.colorHex);
    final cleanPath = widget.photoPath?.trim() ?? '';
    final uri = Uri.tryParse(cleanPath);
    final isNetwork =
        uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
    final originalFile = !isNetwork && cleanPath.isNotEmpty
        ? ItemImageService.instance.originalFile(cleanPath)
        : null;
    final hasValidImage = isNetwork || originalFile != null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        child: Material(
          color: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 500,
              maxHeight: 620,
            ),
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: itemColor.withValues(alpha: 0.75),
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 28,
                    spreadRadius: 2,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Cabeçalho da Janela Flutuante
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          itemColor.withValues(alpha: 0.92),
                          AppColors.primaryDark,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _iconForType(widget.itemType),
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.itemName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.25),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      widget.itemType,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
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
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    widget.colorHex.toUpperCase(),
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.9),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black.withValues(alpha: 0.25),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded, size: 20),
                          tooltip: 'Fechar',
                        ),
                      ],
                    ),
                  ),

                  // Área Central da Imagem em Alta Nitidez
                  Flexible(
                    child: Container(
                      constraints: const BoxConstraints(
                        minHeight: 300,
                        maxHeight: 440,
                      ),
                      color: Colors.black.withValues(alpha: 0.92),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (hasValidImage)
                            GestureDetector(
                              onDoubleTap: _toggleZoom,
                              child: InteractiveViewer(
                                transformationController: _transformController,
                                minScale: 1.0,
                                maxScale: 4.5,
                                clipBehavior: Clip.hardEdge,
                                child: Center(
                                  child: isNetwork
                                      ? Image.network(
                                          cleanPath,
                                          fit: BoxFit.contain,
                                          filterQuality: FilterQuality.high,
                                          errorBuilder: (_, _, _) =>
                                              _buildFallbackGraphic(itemColor),
                                        )
                                      : Image.file(
                                          originalFile!,
                                          fit: BoxFit.contain,
                                          filterQuality: FilterQuality.high,
                                          errorBuilder: (_, _, _) =>
                                              _buildFallbackGraphic(itemColor),
                                        ),
                                ),
                              ),
                            )
                          else
                            _buildFallbackGraphic(itemColor),

                          if (hasValidImage)
                            Positioned(
                              right: 12,
                              bottom: 12,
                              child: FloatingActionButton.small(
                                heroTag: null,
                                backgroundColor:
                                    Colors.black.withValues(alpha: 0.65),
                                foregroundColor: Colors.white,
                                onPressed: _toggleZoom,
                                tooltip: _isZoomed ? 'Reduzir Zoom' : 'Ampliar',
                                child: Icon(
                                  _isZoomed
                                      ? Icons.zoom_out_rounded
                                      : Icons.zoom_in_rounded,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Rodapé informativo
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    color: Theme.of(context).cardColor,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Icon(
                                hasValidImage
                                    ? Icons.pinch_rounded
                                    : Icons.info_outline_rounded,
                                size: 16,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  hasValidImage
                                      ? 'Use pinça ou toque duplo para aproximar a imagem'
                                      : 'Equipamento com ícone padrão (sem foto anexada)',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondaryLight,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text(
                            'Fechar',
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
  }

  Widget _buildFallbackGraphic(Color itemColor) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              color: itemColor,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: itemColor.withValues(alpha: 0.45),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              _iconForType(widget.itemType),
              size: 72,
              color: AppColors.contrastingTextColor(itemColor),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.itemName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Cor: ${widget.colorHex.toUpperCase()} • ${widget.itemType}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
