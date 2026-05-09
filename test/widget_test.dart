import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rentcar00_ops/app/app.dart';
import 'package:rentcar00_ops/data/models/reservation_record.dart';
import 'package:rentcar00_ops/features/reservations/shared/domain/reservation_tab.dart';
import 'package:rentcar00_ops/features/reservations/shared/providers/reservation_providers.dart';
import 'package:rentcar00_ops/shared/constants/status_keys.dart';

void main() {
  final fakeReservations = [
    ReservationRecord(
      reservationId: 'R-TEST-1',
      reservationNumber: 'TEST-001',
      customerName: '테스트고객',
      customerPhone: '010-0000-0000',
      carNumber: '123하4567',
      tab: ReservationTab.pending,
      statusKey: StatusKeys.pending,
      startAt: DateTime(2026, 5, 9, 10),
      endAt: DateTime(2026, 5, 10, 10),
      locationSummary: '김해공항',
      noteText: '테스트 메모',
      primaryBadges: const ['연락처 미확인'],
      checkPayload: const {'customer_phone_verified': 'pending'},
      actionLogs: const [],
    ),
  ];

  testWidgets('앱이 5개 메인 탭을 표시한다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          allReservationsProvider.overrideWith((ref) async => fakeReservations),
        ],
        child: const Rentcar00OpsApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('예약중'), findsOneWidget);
    expect(find.text('오늘배차'), findsOneWidget);
    expect(find.text('배차중'), findsOneWidget);
    expect(find.text('반납일'), findsOneWidget);
    expect(find.text('완료'), findsOneWidget);
  });

  testWidgets('카드가 2~3줄 정보로 보이고 상세 화면으로 이동한다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          allReservationsProvider.overrideWith((ref) async => fakeReservations),
        ],
        child: const Rentcar00OpsApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('123하4567'), findsOneWidget);
    expect(find.text('테스트고객'), findsOneWidget);
    expect(find.text('김해공항'), findsOneWidget);
    expect(find.text('연락처'), findsOneWidget);

    await tester.tap(find.text('123하4567'));
    await tester.pumpAndSettle();

    expect(find.text('액션 영역'), findsOneWidget);
    expect(find.text('상태 요약'), findsOneWidget);

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
    await tester.pumpAndSettle();

    expect(find.text('체크 상태'), findsOneWidget);
  });
}
