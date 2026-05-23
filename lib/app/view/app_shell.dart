import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rentcar00_ops/app/domain/ops_layer.dart';
import 'package:rentcar00_ops/features/auth/shared/auth_providers.dart';
import 'package:rentcar00_ops/app/router/app_routes.dart';
import 'package:rentcar00_ops/features/reservations/list/presentation/reservation_tab_page.dart';
import 'package:rentcar00_ops/features/reservations/shared/domain/reservation_tab.dart';
import 'package:rentcar00_ops/features/reservations/shared/providers/reservation_providers.dart';
import 'package:rentcar00_ops/features/status_board/list/presentation/status_board_tab_page.dart';
import 'package:rentcar00_ops/features/status_board/detail/presentation/status_board_detail_page.dart';
import 'package:rentcar00_ops/features/status_board/shared/domain/status_board_tab.dart';

String _reservationLabel(ReservationTab tab, int? count) {
  if (count == null) return tab.label;
  return '${tab.label}\n$count';
}

String _boardLabel(StatusBoardTab tab, int? count) {
  if (count == null) return tab.label;
  return '${tab.label}\n$count';
}

void _openAdminMenu(BuildContext context, WidgetRef ref) {
  final staff = ref.read(currentStaffAccountProvider).valueOrNull;
  if (staff?.isAdmin == true) {
    context.push(AppRoutes.admin);
    return;
  }

  ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('관리자만 접근할 수 있습니다.')));
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
    final homepagePending = ref
        .watch(homepagePendingReservationsProvider)
        .valueOrNull;
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
        actions: [
          if (homepagePending != null && homepagePending.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: TextButton.icon(
                onPressed: () {
                  ref.read(selectedOpsLayerProvider.notifier).state =
                      OpsLayer.reservations;
                  ref.read(selectedReservationTabProvider.notifier).state =
                      homepagePending.first.tab;
                  context.push(
                    '/reservation/${homepagePending.first.reservationId}',
                  );
                },
                icon: const Icon(Icons.language_outlined, size: 18),
                label: Text('홈페이지 ${homepagePending.length}'),
              ),
            ),
          IconButton(
            tooltip: '검색',
            icon: const Icon(Icons.search),
            onPressed: () => context.push(AppRoutes.search),
          ),
          IconButton(
            tooltip: '예약추가',
            icon: const Icon(Icons.add),
            onPressed: () =>
                showReservationCreateFlow(context: context, ref: ref),
          ),
        ],
        title: Row(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _openAdminMenu(context, ref),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
                child: Text(
                  '빵빵카',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    decoration: TextDecoration.underline,
                    decorationThickness: 1.5,
                  ),
                ),
              ),
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
      ),
      body: switch (layer) {
        OpsLayer.reservations => ReservationTabPage(tab: reservationTab),
        OpsLayer.statusBoard => StatusBoardTabPage(tab: statusBoardTab),
      },
      floatingActionButton:
          layer == OpsLayer.statusBoard &&
              statusBoardTab == StatusBoardTab.schedule
          ? const StatusBoardScheduleFab()
          : null,
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return TextStyle(
              fontSize: selected ? 10.5 : 10,
              height: 1.05,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            );
          }),
        ),
        child: NavigationBar(
          height: 72,
          selectedIndex: selectedIndex,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
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
      ),
    );
  }
}
