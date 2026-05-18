import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rentcar00_ops/app/app.dart';
import 'package:rentcar00_ops/app/router/app_router.dart';
import 'package:rentcar00_ops/app/view/app_shell.dart';
import 'package:rentcar00_ops/data/models/reservation_record.dart';
import 'package:rentcar00_ops/app/domain/ops_layer.dart';
import 'package:rentcar00_ops/features/reservations/detail/presentation/reservation_detail_page.dart';
import 'package:rentcar00_ops/features/reservations/shared/domain/reservation_tab.dart';
import 'package:rentcar00_ops/features/reservations/shared/providers/reservation_providers.dart';
import 'package:rentcar00_ops/shared/constants/status_keys.dart';

GoRouter _testRouter() {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const AppShell()),
      GoRoute(
        path: '/reservation/:reservationId',
        builder: (context, state) => ReservationDetailPage(
          reservationId: state.pathParameters['reservationId']!,
        ),
      ),
    ],
  );
}

void main() {
  final fakeReservations = [
    ReservationRecord(
      reservationId: 'R-TEST-1',
      reservationNumber: 'TEST-001',
      customerName: '테스트고객',
      customerPhone: '010-0000-0000',
      customerBirthDate: '1990-01-01',
      referralSource: '테스트',
      paymentAmount: '100000',
      carNumber: '123하4567',
      carName: 'K5',
      tab: ReservationTab.pending,
      statusKey: StatusKeys.pending,
      startAt: DateTime(2026, 5, 9, 10),
      endAt: DateTime(2026, 5, 10, 10),
      locationSummary: '김해공항',
      dropoffLocation: '김해공항',
      rawNoteText: '테스트 메모',
      noteText: '테스트 메모',
      primaryBadges: const ['연락처 미확인', '준비 미완료', '오늘 배차'],
      checkPayload: const {'customer_phone_verified': 'pending'},
      actionLogs: const [],
    ),
  ];

  testWidgets('앱이 5개 메인 탭을 표시한다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appRouterProvider.overrideWithValue(_testRouter()),
          selectedOpsLayerProvider.overrideWith((ref) => OpsLayer.reservations),
          allReservationsProvider.overrideWith((ref) async => fakeReservations),
        ],
        child: const Rentcar00OpsApp(),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byType(NavigationDestination), findsNWidgets(5));
    expect(ReservationTab.values.map((tab) => tab.label), [
      '예약중',
      '배차대기',
      '배차중',
      '반납일',
      '완료',
    ]);
  });

  testWidgets('카드가 압축형으로 보이고 미완료 아이콘만 남긴 채 상세 화면으로 이동한다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appRouterProvider.overrideWithValue(_testRouter()),
          selectedOpsLayerProvider.overrideWith((ref) => OpsLayer.reservations),
          allReservationsProvider.overrideWith((ref) async => fakeReservations),
        ],
        child: const Rentcar00OpsApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('123하4567'), findsOneWidget);
    expect(find.text('K5'), findsOneWidget);
    expect(find.text('26.05.09(토)'), findsOneWidget);
    expect(find.text('10:00'), findsNWidgets(2));
    expect(find.text('김해공항'), findsOneWidget);
    expect(find.text('연락처'), findsOneWidget);
    expect(find.text('준비'), findsOneWidget);
    expect(find.text('오늘배차'), findsOneWidget);

    await tester.tap(
      find
          .ancestor(of: find.text('123하4567'), matching: find.byType(InkWell))
          .first,
    );
    await tester.pumpAndSettle();

    expect(find.byType(ReservationDetailPage), findsOneWidget);
  });
}
