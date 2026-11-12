import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/services/item_image_service.dart';
import '../models/item_model.dart';

enum CatalogFilter {
  activeOnly,
  all,
}

@immutable
class CatalogState {
  final List<ItemModel> items;
  final CatalogFilter filter;
  final bool isLoading;
  final String? errorMessage;

  const CatalogState({
    this.items = const [],
    this.filter = CatalogFilter.activeOnly,
    this.isLoading = false,
    this.errorMessage,
  });

  List<ItemModel> get filteredItems {
    if (filter == CatalogFilter.activeOnly) {
      return items.where((item) => item.isActive).toList(growable: false);
    }
    return items;
  }

  List<ItemModel> get activeItems =>
      items.where((item) => item.isActive).toList(growable: false);

  CatalogState copyWith({
    List<ItemModel>? items,
    CatalogFilter? filter,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CatalogState(
      items: items != null ? List.unmodifiable(items) : this.items,
      filter: filter ?? this.filter,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class CatalogController extends Notifier<CatalogState> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  @override
  CatalogState build() {
    Future.microtask(loadItems);
    return const CatalogState(isLoading: true);
  }

  Future<void> loadItems() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final db = await _dbHelper.database;
      final rows = await db.query(
        'items',
        orderBy: 'is_active DESC, name ASC',
      );
      final rawItems = rows.map(ItemModel.fromMap).toList(growable: false);
      final items = <ItemModel>[];

      for (final item in rawItems) {
        if (item.hasPhoto && !item.isNetworkPhoto) {
          final storedPath = await ItemImageService.instance
              .saveImageToAppStorage(item.photoPath!);
          if (storedPath != item.photoPath && item.id != null) {
            await db.update(
              'items',
              {'photo_path': storedPath},
              where: 'id = ?',
              whereArgs: [item.id],
            );
            items.add(item.copyWith(photoPath: storedPath));
          } else {
            await ItemImageService.instance.preloadFileIntoMemory(storedPath);
            items.add(item);
          }
        } else {
          items.add(item);
        }
      }

      state = state.copyWith(items: items, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Erro ao carregar catálogo: $e',
      );
    }
  }

  void setFilter(CatalogFilter filter) {
    state = state.copyWith(filter: filter);
  }

  Future<void> addItem(ItemModel item) async {
    try {
      var preparedItem = item;
      if (item.hasPhoto && !item.isNetworkPhoto) {
        final permanentPath = await ItemImageService.instance
            .saveImageToAppStorage(item.photoPath!);
        preparedItem = item.copyWith(photoPath: permanentPath);
      }

      final db = await _dbHelper.database;
      await db.transaction((txn) async {
        await txn.insert('items', preparedItem.toMap());
      });
      await loadItems();
    } catch (e) {
      state = state.copyWith(errorMessage: 'Erro ao cadastrar item: $e');
    }
  }

  Future<void> updateItem(ItemModel item) async {
    if (item.id == null) return;
    try {
      var preparedItem = item;
      if (item.hasPhoto && !item.isNetworkPhoto) {
        final permanentPath = await ItemImageService.instance
            .saveImageToAppStorage(item.photoPath!);
        preparedItem = item.copyWith(photoPath: permanentPath);
      }

      final db = await _dbHelper.database;
      await db.transaction((txn) async {
        await txn.update(
          'items',
          preparedItem.toMap(),
          where: 'id = ?',
          whereArgs: [preparedItem.id],
        );
      });
      await loadItems();
    } catch (e) {
      state = state.copyWith(errorMessage: 'Erro ao atualizar item: $e');
    }
  }

  Future<void> toggleItemActive(ItemModel item) async {
    if (item.id == null) return;
    await updateItem(item.copyWith(isActive: !item.isActive));
  }

  Future<void> deleteItem(int itemId) async {
    state = state.copyWith(clearError: true);
    try {
      final db = await _dbHelper.database;
      final activeRentals = await db.query(
        'rentals',
        where: "item_id = ? AND status = 'active'",
        whereArgs: [itemId],
        limit: 1,
      );
      if (activeRentals.isNotEmpty) {
        state = state.copyWith(
          errorMessage:
              'Não é possível excluir um equipamento com aluguel em andamento.',
        );
        return;
      }

      final pastRentals = await db.query(
        'rentals',
        where: 'item_id = ?',
        whereArgs: [itemId],
        limit: 1,
      );

      await db.transaction((txn) async {
        if (pastRentals.isNotEmpty) {
          await txn.update(
            'items',
            {'is_active': 0},
            where: 'id = ?',
            whereArgs: [itemId],
          );
        } else {
          await txn.delete(
            'items',
            where: 'id = ?',
            whereArgs: [itemId],
          );
        }
      });
      await loadItems();
    } catch (e) {
      state = state.copyWith(errorMessage: 'Erro ao remover item: $e');
    }
  }
}

final catalogControllerProvider =
    NotifierProvider<CatalogController, CatalogState>(
      CatalogController.new,
    );
