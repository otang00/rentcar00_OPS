import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rentcar00_ops/app/domain/ops_layer.dart';
import 'package:rentcar00_ops/data/models/reservation_record.dart';
import 'package:rentcar00_ops/features/auth/shared/auth_providers.dart';
import 'package:rentcar00_ops/app/router/app_routes.dart';
import 'package:rentcar00_ops/features/fines/presentation/fine_notice_page.dart';
import 'package:rentcar00_ops/features/reservations/list/presentation/reservation_tab_page.dart';
import 'package:rentcar00_ops/features/reservations/shared/domain/reservation_tab.dart';
import 'package:rentcar00_ops/features/reservations/shared/providers/reservation_providers.dart';
import 'package:rentcar00_ops/features/status_board/list/presentation/status_board_tab_page.dart';
import 'package:rentcar00_ops/features/status_board/detail/presentation/status_board_detail_page.dart';
import 'package:rentcar00_ops/features/status_board/shared/domain/status_board_tab.dart';
import 'package:url_launcher/url_launcher.dart';

const rentcar00HomepageUri = 'https://rentcar00.com';

final homepageLauncherProvider = Provider<Future<bool> Function(Uri)>((ref) {
  return (uri) => launchUrl(uri, mode: LaunchMode.externalApplication);
});

final _lastHomepagePendingCountProvider = StateProvider<int?>((ref) => null);

enum _HomepageQuickAction { openHomepage, reviewReservations }

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

Future<void> _openHomepageActionMenu(
  BuildContext context,
  WidgetRef ref,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final action = await showModalBottomSheet<_HomepageQuickAction>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '홈페이지 예약',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.open_in_new_outlined),
              title: const Text('홈페이지 진입'),
              subtitle: const Text('rentcar00.com 열기'),
              onTap: () =>
                  Navigator.of(context).pop(_HomepageQuickAction.openHomepage),
            ),
            ListTile(
              leading: const Icon(Icons.fact_check_outlined),
              title: const Text('예약확인'),
              subtitle: const Text('홈페이지 예약만 카드로 보기'),
              onTap: () => Navigator.of(
                context,
              ).pop(_HomepageQuickAction.reviewReservations),
            ),
          ],
        ),
      ),
    ),
  );
  if (action == null || !context.mounted) return;

  switch (action) {
    case _HomepageQuickAction.openHomepage:
      final launched = await ref.read(homepageLauncherProvider)(
        Uri.parse(rentcar00HomepageUri),
      );
      if (!launched && context.mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('홈페이지를 열 수 없습니다.')),
        );
      }
    case _HomepageQuickAction.reviewReservations:
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => const _HomepageReservationListSheet(),
      );
  }
}

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layer = ref.watch(selectedOpsLayerProvider);
    final staff = ref.watch(currentStaffAccountProvider).valueOrNull;
    final canAccessOwnerOnlyOps = staff?.canAccessOwnerOnlyOps == true;
    final safeLayer = !canAccessOwnerOnlyOps && layer == OpsLayer.fines
        ? OpsLayer.statusBoard
        : layer;
    final allowedLayers = [
      OpsLayer.reservations,
      OpsLayer.statusBoard,
      if (canAccessOwnerOnlyOps) OpsLayer.fines,
    ];
    final reservationTab = ref.watch(selectedReservationTabProvider);
    final statusBoardTab = ref.watch(selectedStatusBoardTabProvider);

    final reservationCounts = ref.watch(tabCountsProvider).valueOrNull;
    final boardCounts = ref.watch(statusBoardCountsProvider).valueOrNull;
    final homepagePending = ref
        .watch(homepagePendingReservationsProvider)
        .valueOrNull;
    ref.listen<AsyncValue<int>>(homepagePendingCountProvider, (_, next) {
      final current = next.valueOrNull;
      if (current == null) return;
      final previous = ref.read(_lastHomepagePendingCountProvider);
      ref.read(_lastHomepagePendingCountProvider.notifier).state = current;
      if (!canAccessOwnerOnlyOps || previous == null || current <= previous) {
        return;
      }
      final delta = current - previous;
      final message = delta == 1
          ? '홈페이지 예약이 새로 들어왔습니다.'
          : '홈페이지 예약 $delta건이 새로 들어왔습니다.';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    });
    if (safeLayer != layer) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          ref.read(selectedOpsLayerProvider.notifier).state = safeLayer;
        }
      });
    }

    final selectedIndex = switch (safeLayer) {
      OpsLayer.reservations => ReservationTab.values.indexOf(reservationTab),
      OpsLayer.statusBoard => StatusBoardTab.values.indexOf(statusBoardTab),
      OpsLayer.fines => 0,
    };
    final destinations = switch (safeLayer) {
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
          if (canAccessOwnerOnlyOps)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: _HomepagePendingButton(
                count: homepagePending?.length ?? 0,
                onPressed: () => _openHomepageActionMenu(context, ref),
              ),
            ),
          IconButton(
            tooltip: '검색',
            icon: const Icon(Icons.search),
            onPressed: () => context.push(AppRoutes.search),
          ),
          IconButton(
            tooltip: safeLayer == OpsLayer.fines ? '과태료 등록' : '예약추가',
            icon: const Icon(Icons.add),
            onPressed: () {
              if (safeLayer == OpsLayer.fines) {
                if (!canAccessOwnerOnlyOps) return;
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
                  selected: safeLayer,
                  layers: allowedLayers,
                  onSelected: (value) {
                    ref.read(selectedOpsLayerProvider.notifier).state = value;
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      body: switch (safeLayer) {
        OpsLayer.reservations => ReservationTabPage(tab: reservationTab),
        OpsLayer.statusBoard => StatusBoardTabPage(tab: statusBoardTab),
        OpsLayer.fines => const FineNoticePage(),
      },
      floatingActionButton:
          safeLayer == OpsLayer.statusBoard &&
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
                  if (safeLayer == OpsLayer.reservations) {
                    ref.read(selectedReservationTabProvider.notifier).state =
                        ReservationTab.values[index];
                  } else if (safeLayer == OpsLayer.statusBoard) {
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

class _HomepagePendingButton extends StatelessWidget {
  const _HomepagePendingButton({required this.count, required this.onPressed});

  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: count > 0 ? '홈페이지 확인 $count건' : '홈페이지 열기',
      onPressed: onPressed,
      icon: count > 0
          ? Badge.count(
              count: count,
              backgroundColor: colorScheme.error,
              child: const Icon(Icons.language_outlined),
            )
          : const Icon(Icons.language_outlined),
    );
  }
}

class _HomepageReservationListSheet extends ConsumerWidget {
  const _HomepageReservationListSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reservationsAsync = ref.watch(homepagePendingReservationsProvider);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.72,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '홈페이지 예약확인',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: reservationsAsync.when(
                  data: (items) => items.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 32),
                            child: Text('확인할 홈페이지 예약이 없습니다.'),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: items.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) =>
                              _HomepageReservationCard(
                                reservation: items[index],
                              ),
                        ),
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (error, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Text('홈페이지 예약을 불러오지 못했습니다.\n$error'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomepageReservationCard extends StatelessWidget {
  const _HomepageReservationCard({required this.reservation});

  final ReservationRecord reservation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final carLabel = [
      reservation.carNumber,
      reservation.carName,
    ].where((item) => item.trim().isNotEmpty).join(' · ');
    final period =
        '${_formatHomepageReservationDateTime(reservation.startAt)} → ${_formatHomepageReservationDateTime(reservation.endAt)}';
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          final router = GoRouter.of(context);
          Navigator.of(context).pop();
          router.push('/reservation/${reservation.reservationId}');
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      reservation.customerName.trim().isEmpty
                          ? '고객명 미확인'
                          : reservation.customerName.trim(),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Badge(label: Text('홈페이지 확인')),
                ],
              ),
              const SizedBox(height: 6),
              if (reservation.customerPhone.trim().isNotEmpty)
                Text(reservation.customerPhone.trim()),
              if (carLabel.isNotEmpty) Text(carLabel),
              Text(period),
              if (reservation.reservationNumber.trim().isNotEmpty)
                Text('예약번호 ${reservation.reservationNumber.trim()}'),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatHomepageReservationDateTime(DateTime value) {
  String two(int input) => input.toString().padLeft(2, '0');
  return '${value.month}/${value.day} ${two(value.hour)}:${two(value.minute)}';
}

class _OpsLayerSwitcher extends StatelessWidget {
  const _OpsLayerSwitcher({
    required this.selected,
    required this.layers,
    required this.onSelected,
  });

  final OpsLayer selected;
  final List<OpsLayer> layers;
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
          for (final layer in layers)
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
