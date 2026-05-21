import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rentcar00_ops/app/router/app_routes.dart';
import 'package:rentcar00_ops/features/auth/shared/auth_providers.dart';

class AdminHomePage extends ConsumerWidget {
  const AdminHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffAsync = ref.watch(currentStaffAccountProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('관리자')),
      body: staffAsync.when(
        data: (staff) {
          if (staff?.isAdmin != true) {
            return const _AdminBlockedView();
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            children: const [
              _AdminHeaderCard(),
              SizedBox(height: 14),
              _AdminMenuCard(
                title: '직원관리',
                description: '직원 목록, 아이디/비밀번호, 권한/활성 상태 관리',
                icon: Icons.groups_2_outlined,
                route: AppRoutes.adminStaff,
              ),
              _AdminMenuCard(
                title: '차량관리',
                description: '차량 추가, 전체 컬럼 수정, 삭제 관리',
                icon: Icons.directions_car_filled_outlined,
                route: AppRoutes.adminVehicles,
              ),
              _AdminMenuCard(
                title: '작업로그',
                description: '누가 언제 어떤 작업을 했는지 확인',
                icon: Icons.manage_search_outlined,
                route: AppRoutes.adminActionLogs,
              ),
              _AdminMenuCard(
                title: '출근확인',
                description: 'Wi‑Fi 기반 출근 기록과 직원별 출근현황',
                icon: Icons.wifi_tethering_outlined,
              ),
              _AdminMenuCard(
                title: '앱푸시',
                description: '직원 기기 등록, 공지/알림 발송 준비',
                icon: Icons.notifications_active_outlined,
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('관리자 권한을 확인하지 못했습니다.\n$error'),
          ),
        ),
      ),
    );
  }
}

class _AdminBlockedView extends StatelessWidget {
  const _AdminBlockedView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline_rounded,
              size: 44,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              '관리자만 접근할 수 있습니다.',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminHeaderCard extends StatelessWidget {
  const _AdminHeaderCard();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: colorScheme.primaryContainer.withValues(alpha: 0.45),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '관리자 메뉴',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              '직원, 차량, 작업로그, 출근확인, 앱푸시 기능을 이곳에서 확장합니다.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminMenuCard extends StatelessWidget {
  const _AdminMenuCard({
    required this.title,
    required this.description,
    required this.icon,
    this.route,
  });

  final String title;
  final String description;
  final IconData icon;
  final String? route;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: colorScheme.surfaceContainerHighest,
          foregroundColor: colorScheme.primary,
          child: Icon(icon),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(description),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () {
          final targetRoute = route;
          if (targetRoute != null) {
            context.push(targetRoute);
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$title 기능은 다음 phase에서 연결합니다.')),
          );
        },
      ),
    );
  }
}
