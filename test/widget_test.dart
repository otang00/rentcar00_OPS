import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentcar00_ops/app/app.dart';

void main() {
  testWidgets('앱이 5개 메인 탭을 표시한다', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: Rentcar00OpsApp(),
      ),
    );

    expect(find.text('예약중'), findsOneWidget);
    expect(find.text('오늘배차'), findsOneWidget);
    expect(find.text('배차중'), findsOneWidget);
    expect(find.text('반납일'), findsOneWidget);
    expect(find.text('완료'), findsOneWidget);
  });

  testWidgets('상세 화면으로 이동하면 핵심 섹션이 보인다', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: Rentcar00OpsApp(),
      ),
    );

    await tester.tap(find.textContaining('김태진 · 123하4567'));
    await tester.pumpAndSettle();

    expect(find.text('액션 영역'), findsOneWidget);
    expect(find.text('상태 요약'), findsOneWidget);

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
    await tester.pumpAndSettle();

    expect(find.text('체크 상태'), findsOneWidget);
  });
}
