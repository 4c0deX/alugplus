import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../catalog/controllers/catalog_controller.dart';
import '../../financial/controllers/financial_controller.dart';
import '../../rentals/controllers/rental_controller.dart';
import '../../rentals/models/rental_model.dart';

@immutable
class DashboardSummary {
  final int availableItemsCount;
  final int totalActiveCatalogCount;
  final int rentedRightNowCount;
  final double todayRevenue;
  final double consolidatedDayRevenue;
  final int todayRentalsCount;
  final List<RentalModel> activeRentals;
  final DateTime currentTime;

  const DashboardSummary({
    required this.availableItemsCount,
    required this.totalActiveCatalogCount,
    required this.rentedRightNowCount,
    required this.todayRevenue,
    required this.consolidatedDayRevenue,
    required this.todayRentalsCount,
    required this.activeRentals,
    required this.currentTime,
  });
}

class DashboardController extends Notifier<DashboardSummary> {
  @override
  DashboardSummary build() {
    final catalogState = ref.watch(catalogControllerProvider);
    final rentalsState = ref.watch(rentalControllerProvider);
    final financialState = ref.watch(financialControllerProvider);

    final activeCatalogItems = catalogState.activeItems;
    final busyItemIds = rentalsState.busyItemIds;

    final availableCount = activeCatalogItems
        .where((item) => item.id != null && !busyItemIds.contains(item.id))
        .length;

    return DashboardSummary(
      availableItemsCount: availableCount,
      totalActiveCatalogCount: activeCatalogItems.length,
      rentedRightNowCount: rentalsState.activeRentals.length,
      todayRevenue: financialState.currentShiftRevenue,
      consolidatedDayRevenue: financialState.consolidatedDayRevenue,
      todayRentalsCount: financialState.currentShiftRentalsCount,
      activeRentals: rentalsState.activeRentals,
      currentTime: rentalsState.currentTime,
    );
  }
}

final dashboardControllerProvider =
    NotifierProvider<DashboardController, DashboardSummary>(
      DashboardController.new,
    );
