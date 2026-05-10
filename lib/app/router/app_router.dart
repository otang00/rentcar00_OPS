import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rentcar00_ops/app/router/app_routes.dart';
import 'package:rentcar00_ops/app/view/app_shell.dart';
import 'package:rentcar00_ops/features/reservations/detail/presentation/reservation_detail_page.dart';
import 'package:rentcar00_ops/features/search/presentation/search_page.dart';
import 'package:rentcar00_ops/features/status_board/detail/presentation/status_board_detail_page.dart';
import 'package:rentcar00_ops/features/sync/presentation/sync_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const AppShell(),
      ),
      GoRoute(
        path: AppRoutes.reservationDetail,
        builder: (context, state) {
          final reservationId = state.pathParameters['reservationId']!;
          return ReservationDetailPage(reservationId: reservationId);
        },
      ),
      GoRoute(
        path: AppRoutes.statusBoardDetail,
        builder: (context, state) {
          final recordId = state.pathParameters['recordId']!;
          return StatusBoardDetailPage(recordId: recordId);
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
