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

String _reservationLabel(ReservationTab tab, int? count) {
  if (count == null) return tab.label;
  return '${tab.label}($count)';
}

String _boardLabel(StatusBoardTab tab, int? count) {
  if (count == null) return tab.label;
  return '${tab.label}($count)';
}

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layer = ref.watch(selectedOpsLayerProvider);
    final reservationTab = ref.watch(selectedReservationTabProvider);
    final statusBoardTab = ref.watch(selectedStatusBoardTabProvider);

    final reservationCounts = ref.watch(tabCountsProvider).valueOrNull;
    final boardCounts = ref.watch(statusBoardCountsProvider).valueOrNull;
    final selectedIndex = layer == OpsLayer.reservations
        ? ReservationTab.values.indexOf(reservationTab)
        : StatusBoardTab.values.indexOf(statusBoardTab);
    final destinations = layer == OpsLayer.reservations
        ? [
            for (final tab in ReservationTab.values)
              NavigationDestination(
                icon: Icon(tab.icon),
                label: _reservationLabel(tab, reservationCounts?[tab]),
              ),
          ]
        : [
            for (final tab in StatusBoardTab.values)
              NavigationDestination(
                icon: Icon(tab.icon),
                label: _boardLabel(tab, boardCounts?[tab]),
              ),
          ];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 10,
        title: Row(
          children: [
            Text(
              '빵빵카',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SegmentedButton<OpsLayer>(
                showSelectedIcon: false,
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                segments: const [
                  ButtonSegment(
                    value: OpsLayer.reservations,
                    label: Text('예약'),
                    icon: Icon(Icons.assignment_outlined, size: 18),
                  ),
                  ButtonSegment(
                    value: OpsLayer.statusBoard,
                    label: Text('현황판'),
                    icon: Icon(Icons.directions_car_filled_outlined, size: 18),
                  ),
                ],
                selected: {layer},
                onSelectionChanged: (selection) {
                  ref.read(selectedOpsLayerProvider.notifier).state =
                      selection.first;
                },
              ),
            ),
          ],
        ),
        actions: [
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
