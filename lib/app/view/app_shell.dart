import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rentcar00_ops/app/domain/ops_layer.dart';
import 'package:rentcar00_ops/app/router/app_routes.dart';
import 'package:rentcar00_ops/features/reservations/list/presentation/reservation_tab_page.dart';
import 'package:rentcar00_ops/features/reservations/shared/domain/reservation_tab.dart';
import 'package:rentcar00_ops/features/reservations/shared/providers/reservation_providers.dart';
import 'package:rentcar00_ops/features/status_board/list/presentation/status_board_tab_page.dart';
import 'package:rentcar00_ops/features/status_board/shared/domain/status_board_tab.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layer = ref.watch(selectedOpsLayerProvider);
    final reservationTab = ref.watch(selectedReservationTabProvider);
    final statusBoardTab = ref.watch(selectedStatusBoardTabProvider);

    final selectedIndex = layer == OpsLayer.reservations
        ? ReservationTab.values.indexOf(reservationTab)
        : StatusBoardTab.values.indexOf(statusBoardTab);
    final destinations = layer == OpsLayer.reservations
        ? [
            for (final tab in ReservationTab.values)
              NavigationDestination(icon: Icon(tab.icon), label: tab.label),
          ]
        : [
            for (final tab in StatusBoardTab.values)
              NavigationDestination(icon: Icon(tab.icon), label: tab.label),
          ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('rentcar00 OPS'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<OpsLayer>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: OpsLayer.reservations,
                    label: Text('예약'),
                    icon: Icon(Icons.assignment_outlined),
                  ),
                  ButtonSegment(
                    value: OpsLayer.statusBoard,
                    label: Text('현황판'),
                    icon: Icon(Icons.directions_car_filled_outlined),
                  ),
                ],
                selected: {layer},
                onSelectionChanged: (selection) {
                  ref.read(selectedOpsLayerProvider.notifier).state =
                      selection.first;
                },
              ),
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: '검색',
            onPressed: () => context.push(AppRoutes.search),
            icon: const Icon(Icons.search),
          ),
          IconButton(
            tooltip: 'sync',
            onPressed: () => context.push(AppRoutes.sync),
            icon: const Icon(Icons.sync),
          ),
        ],
      ),
      body: switch (layer) {
        OpsLayer.reservations => ReservationTabPage(tab: reservationTab),
        OpsLayer.statusBoard => StatusBoardTabPage(tab: statusBoardTab),
      },
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          if (layer == OpsLayer.reservations) {
            ref.read(selectedReservationTabProvider.notifier).state =
                ReservationTab.values[index];
          } else {
            ref.read(selectedStatusBoardTabProvider.notifier).state =
                StatusBoardTab.values[index];
          }
        },
        destinations: destinations,
      ),
    );
  }
}
