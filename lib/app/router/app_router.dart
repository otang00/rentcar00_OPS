import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rentcar00_ops/app/router/app_routes.dart';
import 'package:rentcar00_ops/app/view/app_shell.dart';
import 'package:rentcar00_ops/features/reservations/detail/presentation/reservation_detail_page.dart';
import 'package:rentcar00_ops/features/reservations/list/presentation/reservation_tab_page.dart';
import 'package:rentcar00_ops/features/reservations/shared/domain/reservation_tab.dart';
import 'package:rentcar00_ops/features/search/presentation/search_page.dart';
import 'package:rentcar00_ops/features/sync/presentation/sync_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.pending,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.pending,
                builder: (context, state) => const ReservationTabPage(
                  tab: ReservationTab.pending,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.pickupToday,
                builder: (context, state) => const ReservationTabPage(
                  tab: ReservationTab.pickupToday,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.inUse,
                builder: (context, state) => const ReservationTabPage(
                  tab: ReservationTab.inUse,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.returnDue,
                builder: (context, state) => const ReservationTabPage(
                  tab: ReservationTab.returnDue,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.completed,
                builder: (context, state) => const ReservationTabPage(
                  tab: ReservationTab.completed,
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/reservation/:reservationId',
        builder: (context, state) {
          final reservationId = state.pathParameters['reservationId']!;
          return ReservationDetailPage(reservationId: reservationId);
        },
      ),
      GoRoute(
        path: AppRoutes.search,
        builder: (context, state) => const SearchPage(),
      ),
      GoRoute(
        path: AppRoutes.sync,
        builder: (context, state) => const SyncPage(),
      ),
    ],
  );
});
