import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rentcar00_ops/app/domain/ops_layer.dart';
import 'package:rentcar00_ops/features/auth/shared/auth_providers.dart';
import 'package:rentcar00_ops/app/router/app_routes.dart';
import 'package:rentcar00_ops/features/fines/presentation/fine_notice_page.dart';
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

IconData _layerIcon(OpsLayer layer) {
  return switch (layer) {
    OpsLayer.reservations => Icons.assignment_outlined,
    OpsLayer.statusBoard => Icons.directions_car_filled_outlined,
    OpsLayer.fines => Icons.receipt_long_outlined,
  };
}

String _layerLabel(OpsLayer layer) {
  return switch (layer) {
    OpsLayer.reservations => '예약',
    OpsLayer.statusBoard => '일정',
    OpsLayer.fines => '과태료',
  };
}

void _openAccountMenu(BuildContext context, WidgetRef ref) {
  final staff = ref.read(currentStaffAccountProvider).valueOrNull;
  if (staff?.isAdmin == true) {
    context.push(AppRoutes.admin);
    return;
  }

  context.push(AppRoutes.admin);
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
    final selectedIndex = switch (layer) {
      OpsLayer.reservations => ReservationTab.values.indexOf(reservationTab),
      OpsLayer.statusBoard => StatusBoardTab.values.indexOf(statusBoardTab),
      OpsLayer.fines => 0,
    };
    final destinations = switch (layer) {
      OpsLayer.reservations => [
        for (final tab in ReservationTab.values)
          NavigationDestination(
            icon: Icon(tab.icon),
            label: _reservationLabel(tab, reservationCounts?[tab]),
          ),
      ],
      OpsLayer.statusBoard => [
        for (final tab in StatusBoardTab.values)
          NavigationDestination(
            icon: Icon(tab.icon),
            label: _boardLabel(tab, boardCounts?[tab]),
          ),
      ],
      OpsLayer.fines => const <NavigationDestination>[],
    };

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
            tooltip: layer == OpsLayer.fines ? '과태료 등록' : '예약추가',
            icon: const Icon(Icons.add),
            onPressed: () {
              if (layer == OpsLayer.fines) {
                showFineNoticeCreateFlow(context: context, ref: ref);
                return;
              }
              showReservationCreateFlow(context: context, ref: ref);
            },
          ),
        ],
        title: Row(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _openAccountMenu(context, ref),
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
              child: Align(
                alignment: Alignment.centerLeft,
                child: _OpsLayerSwitcher(
                  selected: layer,
                  onSelected: (value) {
                    ref.read(selectedOpsLayerProvider.notifier).state = value;
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      body: switch (layer) {
        OpsLayer.reservations => ReservationTabPage(tab: reservationTab),
        OpsLayer.statusBoard => StatusBoardTabPage(tab: statusBoardTab),
        OpsLayer.fines => const FineNoticePage(),
      },
      floatingActionButton:
          layer == OpsLayer.statusBoard &&
              statusBoardTab == StatusBoardTab.schedule
          ? const StatusBoardScheduleFab()
          : null,
      bottomNavigationBar: destinations.isEmpty
          ? null
          : NavigationBarTheme(
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
                  } else if (layer == OpsLayer.statusBoard) {
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

class _OpsLayerSwitcher extends StatelessWidget {
  const _OpsLayerSwitcher({required this.selected, required this.onSelected});

  final OpsLayer selected;
  final ValueChanged<OpsLayer> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final layer in OpsLayer.values)
            Tooltip(
              message: _layerLabel(layer),
              child: Semantics(
                button: true,
                selected: selected == layer,
                label: _layerLabel(layer),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => onSelected(layer),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    width: 42,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected == layer
                          ? colorScheme.primaryContainer
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      _layerIcon(layer),
                      size: 20,
                      color: selected == layer
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
