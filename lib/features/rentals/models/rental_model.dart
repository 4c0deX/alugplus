import 'package:flutter/foundation.dart';

import '../../../core/utils/time_utils.dart';

@immutable
class RentalModel {
  final int? id;
  final int itemId;
  final DateTime startTime;
  final DateTime plannedEndTime;
  final DateTime? actualEndTime;
  final double basePrice;
  final double surcharge;
  final bool surchargeApplied;
  final bool isManualSurcharge;
  final double totalPaid;
  final String status; // 'active' | 'completed'
  final String createdDate; // YYYY-MM-DD

  // Campos de junção (JOIN com tabela items) para exibição rápida e reativa
  final String itemName;
  final String itemType;
  final String itemColorHex;
  final String? itemPhotoPath;

  const RentalModel({
    this.id,
    required this.itemId,
    required this.startTime,
    required this.plannedEndTime,
    this.actualEndTime,
    required this.basePrice,
    this.surcharge = 0.0,
    this.surchargeApplied = false,
    this.isManualSurcharge = false,
    required this.totalPaid,
    required this.status,
    required this.createdDate,
    this.itemName = 'Equipamento',
    this.itemType = 'Bicicleta',
    this.itemColorHex = '#1565C0',
    this.itemPhotoPath,
  });

  bool get isActive => status == 'active';
  bool get isCompleted => status == 'completed';

  /// Progresso em tempo real: (tempo_atual - start_time) / (planned_end_time - start_time)
  double progressAt(DateTime now) {
    return TimeUtils.calculateProgress(
      startTime: startTime,
      plannedEndTime: plannedEndTime,
      currentTime: now,
    );
  }

  /// Verifica se o tempo atual já atingiu ou passou do horário previsto
  bool isOverdueAt(DateTime now) {
    return TimeUtils.isFinishedOrOverdue(
      plannedEndTime: plannedEndTime,
      currentTime: now,
    );
  }

  /// Minutos completos de atraso no instante [now]
  int overdueMinutesAt(DateTime now) {
    return TimeUtils.overdueMinutes(
      plannedEndTime: plannedEndTime,
      currentTime: now,
    );
  }

  /// Calcula o acréscimo automático pelo tempo decorrido (a partir do 4º minuto)
  double autoSurchargeAt(DateTime now) {
    return TimeUtils.calculateSurcharge(
      plannedEndTime: plannedEndTime,
      currentTime: now,
    );
  }

  RentalModel copyWith({
    int? id,
    int? itemId,
    DateTime? startTime,
    DateTime? plannedEndTime,
    DateTime? actualEndTime,
    double? basePrice,
    double? surcharge,
    bool? surchargeApplied,
    bool? isManualSurcharge,
    double? totalPaid,
    String? status,
    String? createdDate,
    String? itemName,
    String? itemType,
    String? itemColorHex,
    String? itemPhotoPath,
  }) {
    return RentalModel(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      startTime: startTime ?? this.startTime,
      plannedEndTime: plannedEndTime ?? this.plannedEndTime,
      actualEndTime: actualEndTime ?? this.actualEndTime,
      basePrice: basePrice ?? this.basePrice,
      surcharge: surcharge ?? this.surcharge,
      surchargeApplied: surchargeApplied ?? this.surchargeApplied,
      isManualSurcharge: isManualSurcharge ?? this.isManualSurcharge,
      totalPaid: totalPaid ?? this.totalPaid,
      status: status ?? this.status,
      createdDate: createdDate ?? this.createdDate,
      itemName: itemName ?? this.itemName,
      itemType: itemType ?? this.itemType,
      itemColorHex: itemColorHex ?? this.itemColorHex,
      itemPhotoPath: itemPhotoPath ?? this.itemPhotoPath,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'item_id': itemId,
      'start_time': startTime.toIso8601String(),
      'planned_end_time': plannedEndTime.toIso8601String(),
      'actual_end_time': actualEndTime?.toIso8601String(),
      'base_price': basePrice,
      'surcharge': surcharge,
      'surcharge_applied': surchargeApplied ? 1 : 0,
      'is_manual_surcharge': isManualSurcharge ? 1 : 0,
      'total_paid': totalPaid,
      'status': status,
      'created_date': createdDate,
    };
  }

  factory RentalModel.fromJoinedMap(Map<String, dynamic> map) {
    return RentalModel(
      id: (map['id'] as num?)?.toInt(),
      itemId: (map['item_id'] as num?)?.toInt() ?? 0,
      startTime:
          DateTime.tryParse((map['start_time'] as String?) ?? '') ??
          DateTime.now(),
      plannedEndTime:
          DateTime.tryParse((map['planned_end_time'] as String?) ?? '') ??
          DateTime.now(),
      actualEndTime: map['actual_end_time'] != null
          ? DateTime.tryParse(map['actual_end_time'] as String)
          : null,
      basePrice: (map['base_price'] as num?)?.toDouble() ?? 0.0,
      surcharge: (map['surcharge'] as num?)?.toDouble() ?? 0.0,
      surchargeApplied: ((map['surcharge_applied'] as num?)?.toInt() ?? 0) == 1,
      isManualSurcharge:
          ((map['is_manual_surcharge'] as num?)?.toInt() ?? 0) == 1,
      totalPaid: (map['total_paid'] as num?)?.toDouble() ?? 0.0,
      status: (map['status'] as String?) ?? 'active',
      createdDate: (map['created_date'] as String?) ?? '',
      itemName: (map['item_name'] as String?) ?? 'Equipamento',
      itemType: (map['item_type'] as String?) ?? 'Bicicleta',
      itemColorHex: (map['item_color_hex'] as String?) ?? '#1565C0',
      itemPhotoPath: map['item_photo_path'] as String?,
    );
  }
}
