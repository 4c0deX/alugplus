import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/item_image_service.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/time_utils.dart';
import '../../../shared/widgets/item_image_preview_dialog.dart';
import '../models/rental_model.dart';

class RentalCard extends StatelessWidget {
  final RentalModel rental;
  final DateTime currentTime;
  final VoidCallback onExpand;

  const RentalCard({
    super.key,
    required this.rental,
    required this.currentTime,
    required this.onExpand,
  });

  @override
  Widget build(BuildContext context) {
    final itemColor = AppColors.fromHex(rental.itemColorHex);
    final rawProgress = rental.progressAt(currentTime);
    final clampedProgress = rawProgress.clamp(0.0, 1.0);
    final isOverdue = rental.isOverdueAt(currentTime);
    final progressBarColor = isOverdue ? AppColors.danger : itemColor;
    final statusLabel = TimeUtils.statusTimeLabel(
      plannedEndTime: rental.plannedEndTime,
      currentTime: currentTime,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isOverdue ? AppColors.danger : itemColor,
          width: 2.2,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onExpand,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  RentalItemAvatar(
                    itemName: rental.itemName,
                    photoPath: rental.itemPhotoPath,
                    colorHex: rental.itemColorHex,
                    itemType: rental.itemType,
                    size: 52,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                rental.itemName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isOverdue
                                    ? AppColors.danger.withValues(alpha: 0.14)
                                    : itemColor.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                statusLabel,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: isOverdue
                                      ? AppColors.danger
                                      : itemColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 16,
                          runSpacing: 4,
                          children: [
                            _TimeBadge(
                              icon: Icons.play_circle_outline_rounded,
                              label:
                                  'Início: ${AppFormatters.timeShort(rental.startTime)}',
                            ),
                            _TimeBadge(
                              icon: Icons.flag_outlined,
                              label:
                                  'Previsto: ${AppFormatters.timeShort(rental.plannedEndTime)}',
                            ),
                            _TimeBadge(
                              icon: Icons.payments_outlined,
                              label: AppFormatters.currency(rental.totalPaid),
                              highlight: rental.surchargeApplied,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: 'Expandir Detalhes e Ações',
                    onPressed: onExpand,
                    icon: const Icon(Icons.open_in_full_rounded, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: isOverdue ? 1.0 : clampedProgress,
                        minHeight: 10,
                        backgroundColor: progressBarColor.withValues(
                          alpha: 0.16,
                        ),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          progressBarColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${(clampedProgress * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: progressBarColor,
                    ),
                  ),
                ],
              ),
              if (rental.surcharge > 0) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.danger.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        size: 16,
                        color: AppColors.danger,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Acréscimo de atraso: ${AppFormatters.currency(rental.surcharge)} '
                          '(${rental.surchargeApplied ? "Somado ao total" : "Pendente de adição"})',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.danger,
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
      ),
    );
  }
}

class _TimeBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool highlight;

  const _TimeBadge({
    required this.icon,
    required this.label,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: highlight ? AppColors.primary : AppColors.textSecondaryLight,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
            color: highlight ? AppColors.primary : AppColors.textSecondaryLight,
          ),
        ),
      ],
    );
  }
}

class RentalItemAvatar extends StatelessWidget {
  final String itemName;
  final String? photoPath;
  final String colorHex;
  final String itemType;
  final double size;
  final bool enablePreviewOnTap;

  const RentalItemAvatar({
    super.key,
    this.itemName = 'Equipamento',
    required this.photoPath,
    required this.colorHex,
    required this.itemType,
    this.size = 48,
    this.enablePreviewOnTap = true,
  });

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

  Widget _buildContent() {
    final color = AppColors.fromHex(colorHex);
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(
        _iconForType(itemType),
        color: AppColors.contrastingTextColor(color),
        size: size * 0.54,
      ),
    );

    if (photoPath == null || photoPath!.trim().isEmpty) {
      return fallback;
    }

    final clean = photoPath!.trim();
    final uri = Uri.tryParse(clean);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.network(
          clean,
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          cacheWidth: (size * 3).round(),
          errorBuilder: (_, _, _) => fallback,
        ),
      );
    }

    final bytes = ItemImageService.instance.getBytesSync(clean);
    if (bytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => fallback,
        ),
      );
    }

    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final content = _buildContent();
    if (!enablePreviewOnTap) {
      return content;
    }

    final hasPhoto = photoPath != null && photoPath!.trim().isNotEmpty;

    return Tooltip(
      message: 'Toque para ampliar imagem de $itemName',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          ItemImagePreviewDialog.show(
            context,
            itemName: itemName,
            itemType: itemType,
            colorHex: colorHex,
            photoPath: photoPath,
          );
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            content,
            if (hasPhoto)
              Positioned(
                right: -3,
                bottom: -3,
                child: Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    color: AppColors.primaryDark,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 3,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.zoom_in_rounded,
                    size: (size * 0.24).clamp(10.0, 14.0),
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
