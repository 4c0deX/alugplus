import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../features/catalog/views/catalog_view.dart';
import '../../features/dashboard/views/dashboard_view.dart';
import '../../features/financial/views/financial_view.dart';
import '../../features/rentals/controllers/rental_controller.dart';
import '../../features/rentals/views/rentals_view.dart';
import '../../features/settings/views/settings_view.dart';

class NavigationTabNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setTab(int index) {
    state = index;
  }
}

final navigationTabProvider = NotifierProvider<NavigationTabNotifier, int>(
  NavigationTabNotifier.new,
);

class ResponsiveScaffold extends ConsumerWidget {
  const ResponsiveScaffold({super.key});

  static const List<Widget> _views = [
    DashboardView(),
    RentalsView(),
    CatalogView(),
    FinancialView(),
    SettingsView(),
  ];

  static const List<String> _titles = [
    'Painel',
    'Aluguéis',
    'Catálogo',
    'Financeiro',
    'Configurações',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(navigationTabProvider);
    final activeRentalsCount = ref.watch(
      rentalControllerProvider.select((s) => s.activeRentals.length),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;

        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                const StylizedBoltBadge(),
                const SizedBox(width: 10),
                const Text('AlugPlus+'),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _titles[currentIndex],
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              if (activeRentalsCount > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: ActionChip(
                    avatar: const Icon(
                      Icons.timelapse_rounded,
                      size: 16,
                      color: AppColors.primaryDark,
                    ),
                    backgroundColor: Colors.white,
                    label: Text(
                      '$activeRentalsCount ativo(s)',
                      style: const TextStyle(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                    onPressed: () {
                      ref.read(navigationTabProvider.notifier).setTab(1);
                    },
                  ),
                ),
            ],
          ),
          body: isWide
              ? Row(
                  children: [
                    NavigationRail(
                      extended: constraints.maxWidth >= 1040,
                      selectedIndex: currentIndex,
                      onDestinationSelected: (idx) {
                        ref.read(navigationTabProvider.notifier).setTab(idx);
                      },
                      leading: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: StylizedBoltBadge(size: 40),
                      ),
                      destinations: [
                        const NavigationRailDestination(
                          icon: Icon(Icons.dashboard_outlined),
                          selectedIcon: Icon(Icons.dashboard_rounded),
                          label: Text('Painel'),
                        ),
                        NavigationRailDestination(
                          icon: Badge(
                            isLabelVisible: activeRentalsCount > 0,
                            label: Text('$activeRentalsCount'),
                            child: const Icon(Icons.timer_outlined),
                          ),
                          selectedIcon: Badge(
                            isLabelVisible: activeRentalsCount > 0,
                            label: Text('$activeRentalsCount'),
                            child: const Icon(Icons.timer_rounded),
                          ),
                          label: const Text('Aluguéis'),
                        ),
                        const NavigationRailDestination(
                          icon: Icon(Icons.directions_bike_outlined),
                          selectedIcon: Icon(Icons.directions_bike_rounded),
                          label: Text('Catálogo'),
                        ),
                        const NavigationRailDestination(
                          icon: Icon(Icons.insights_outlined),
                          selectedIcon: Icon(Icons.insights_rounded),
                          label: Text('Financeiro'),
                        ),
                        const NavigationRailDestination(
                          icon: Icon(Icons.settings_outlined),
                          selectedIcon: Icon(Icons.settings_rounded),
                          label: Text('Configurações'),
                        ),
                      ],
                    ),
                    const VerticalDivider(width: 1, thickness: 1),
                    Expanded(
                      child: IndexedStack(
                        index: currentIndex,
                        children: _views,
                      ),
                    ),
                  ],
                )
              : IndexedStack(
                  index: currentIndex,
                  children: _views,
                ),
          bottomNavigationBar: isWide
              ? null
              : NavigationBar(
                  selectedIndex: currentIndex,
                  onDestinationSelected: (idx) {
                    ref.read(navigationTabProvider.notifier).setTab(idx);
                  },
                  destinations: [
                    const NavigationDestination(
                      icon: Icon(Icons.dashboard_outlined),
                      selectedIcon: Icon(Icons.dashboard_rounded),
                      label: 'Painel',
                    ),
                    NavigationDestination(
                      icon: Badge(
                        isLabelVisible: activeRentalsCount > 0,
                        label: Text('$activeRentalsCount'),
                        child: const Icon(Icons.timer_outlined),
                      ),
                      selectedIcon: Badge(
                        isLabelVisible: activeRentalsCount > 0,
                        label: Text('$activeRentalsCount'),
                        child: const Icon(Icons.timer_rounded),
                      ),
                      label: 'Aluguéis',
                    ),
                    const NavigationDestination(
                      icon: Icon(Icons.directions_bike_outlined),
                      selectedIcon: Icon(Icons.directions_bike_rounded),
                      label: 'Catálogo',
                    ),
                    const NavigationDestination(
                      icon: Icon(Icons.insights_outlined),
                      selectedIcon: Icon(Icons.insights_rounded),
                      label: 'Financeiro',
                    ),
                    const NavigationDestination(
                      icon: Icon(Icons.settings_outlined),
                      selectedIcon: Icon(Icons.settings_rounded),
                      label: 'Configurações',
                    ),
                  ],
                ),
        );
      },
    );
  }
}

/// Ícone de raio estilizado assinatura visual do AlugPlus+ (Roxo com Branco • Purple Edition)
class StylizedBoltBadge extends StatelessWidget {
  final double size;

  const StylizedBoltBadge({
    super.key,
    this.size = 34,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryLight, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.3),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.85),
          width: 1.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          Icons.bolt_rounded,
          color: Colors.white,
          size: size * 0.72,
        ),
      ),
    );
  }
}
