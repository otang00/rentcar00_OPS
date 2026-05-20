import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rentcar00_ops/app/router/app_routes.dart';
import 'package:rentcar00_ops/app/view/app_shell.dart';
import 'package:rentcar00_ops/features/admin/presentation/admin_home_page.dart';
import 'package:rentcar00_ops/features/admin/presentation/staff_management_page.dart';
import 'package:rentcar00_ops/features/auth/presentation/login_page.dart';
import 'package:rentcar00_ops/features/auth/presentation/staff_access_gate.dart';
import 'package:rentcar00_ops/features/auth/shared/auth_providers.dart';
import 'package:rentcar00_ops/shared/config/supabase_providers.dart';
import 'package:rentcar00_ops/features/reservations/detail/presentation/reservation_detail_page.dart';
import 'package:rentcar00_ops/features/search/presentation/search_page.dart';
import 'package:rentcar00_ops/features/status_board/detail/presentation/status_board_detail_page.dart';
import 'package:rentcar00_ops/features/sync/presentation/sync_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authRefreshListenable = ref.watch(authRefreshListenableProvider);

  return GoRouter(
    refreshListenable: authRefreshListenable,
    redirect: (context, state) {
      final session = ref.read(supabaseClientProvider).auth.currentSession;
      final isLoginRoute = state.matchedLocation == AppRoutes.login;

      if (session == null) {
        return isLoginRoute ? null : AppRoutes.login;
      }

      if (isLoginRoute) {
        return AppRoutes.home;
      }

      return null;
    },
    initialLocation: AppRoutes.home,
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const StaffAccessGate(child: AppShell()),
      ),
      GoRoute(
        path: AppRoutes.reservationDetail,
        builder: (context, state) {
          final reservationId = state.pathParameters['reservationId']!;
          return StaffAccessGate(
            child: ReservationDetailPage(reservationId: reservationId),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.statusBoardDetail,
        builder: (context, state) {
          final recordId = state.pathParameters['recordId']!;
          return StaffAccessGate(
            child: StatusBoardDetailPage(recordId: recordId),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.scheduleDetail,
        builder: (context, state) {
          final recordId = state.pathParameters['recordId']!;
          return StaffAccessGate(
            child: StatusBoardDetailPage(recordId: recordId),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.search,
        builder: (context, state) => const StaffAccessGate(child: SearchPage()),
      ),
      GoRoute(
        path: AppRoutes.sync,
        builder: (context, state) => const StaffAccessGate(child: SyncPage()),
      ),
      GoRoute(
        path: AppRoutes.admin,
        builder: (context, state) =>
            const StaffAccessGate(child: AdminHomePage()),
      ),
      GoRoute(
        path: AppRoutes.adminStaff,
        builder: (context, state) =>
            const StaffAccessGate(child: StaffManagementPage()),
      ),
    ],
  );
});
