import 'package:flutter/foundation.dart';

@immutable
class ItemModel {
  final int? id;
  final String name;
  final String type; // 'Bicicleta', 'Carrinho', 'Outro'
  final String colorHex;
  final String? photoPath;
  final bool isActive;

  const ItemModel({
    this.id,
    required this.name,
    required this.type,
    required this.colorHex,
    this.photoPath,
    this.isActive = true,
  });

  bool get hasPhoto => photoPath != null && photoPath!.trim().isNotEmpty;

  bool get isNetworkPhoto {
    if (!hasPhoto) return false;
    final uri = Uri.tryParse(photoPath!.trim());
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
  }

  ItemModel copyWith({
    int? id,
    String? name,
    String? type,
    String? colorHex,
    String? photoPath,
    bool clearPhoto = false,
    bool? isActive,
  }) {
    return ItemModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      colorHex: colorHex ?? this.colorHex,
      photoPath: clearPhoto ? null : (photoPath ?? this.photoPath),
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name.trim(),
      'type': type,
      'color_hex': colorHex,
      'photo_path': (photoPath != null && photoPath!.trim().isEmpty)
          ? null
          : photoPath?.trim(),
      'is_active': isActive ? 1 : 0,
    };
  }

  factory ItemModel.fromMap(Map<String, dynamic> map) {
    final rawType = (map['type'] as String?) ?? 'Outro';
    return ItemModel(
      id: (map['id'] as num?)?.toInt(),
      name: (map['name'] as String?) ?? '',
      type: rawType == 'Bike' ? 'Bicicleta' : rawType,
      colorHex: (map['color_hex'] as String?) ?? '#1565C0',
      photoPath: map['photo_path'] as String?,
      isActive: ((map['is_active'] as num?)?.toInt() ?? 1) == 1,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ItemModel &&
        other.id == id &&
        other.name == name &&
        other.type == type &&
        other.colorHex == colorHex &&
        other.photoPath == photoPath &&
        other.isActive == isActive;
  }

  @override
  int get hashCode =>
      Object.hash(id, name, type, colorHex, photoPath, isActive);
}
