import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentcar00_ops/data/models/action_log_entry.dart';
import 'package:rentcar00_ops/data/models/ops_state.dart';
import 'package:rentcar00_ops/data/models/outbox_entry.dart';
import 'package:rentcar00_ops/data/models/reservation_record.dart';
import 'package:rentcar00_ops/data/models/sync_run_entry.dart';
import 'package:rentcar00_ops/features/reservations/shared/domain/reservation_tab.dart';
import 'package:rentcar00_ops/shared/constants/action_keys.dart';
import 'package:rentcar00_ops/shared/constants/status_keys.dart';

final opsStateProvider = StateNotifierProvider<MockOpsRepository, OpsState>((
  ref,
) {
  return MockOpsRepository();
});

class MockOpsRepository extends StateNotifier<OpsState> {
  MockOpsRepository() : super(_seedState());

  void executeAction(String reservationId, String actionKey) {
    final now = DateTime.now();
    final reservations = [...state.reservations];
    final index = reservations.indexWhere(
      (item) => item.reservationId == reservationId,
    );

    if (index == -1) {
      return;
    }

    var reservation = reservations[index];
    final checks = Map<String, String>.from(reservation.checkPayload);
    final badges = [...reservation.primaryBadges];
    var nextTab = reservation.tab;
    var nextStatus = reservation.statusKey;
    OutboxEntry? outboxEntry;
    var logNote = '내부 상태만 갱신';

    switch (actionKey) {
      case ActionKeys.checkId:
        checks['id_verified'] = 'done';
        badges.remove('신분증 미확보');
        nextStatus = checks['address_verified'] == 'done'
            ? StatusKeys.pending
            : StatusKeys.waitingForAddress;
        break;
      case ActionKeys.checkAddress:
        checks['address_verified'] = 'done';
        badges.remove('주소 미확보');
        nextStatus = checks['id_verified'] == 'done'
            ? StatusKeys.pending
            : StatusKeys.waitingForId;
        break;
      case ActionKeys.markPickupReady:
        checks['pickup_ready'] = 'done';
        if (!badges.contains('준비 완료')) {
          badges.add('준비 완료');
        }
        nextStatus = StatusKeys.ready;
        break;
      case ActionKeys.sendPickupNotice:
        checks['pickup_notice_sent'] = 'done';
        nextStatus = StatusKeys.readyForDispatch;
        logNote = '고객 배차 안내 발송 처리';
        break;
      case ActionKeys.requestDelivery:
        checks['delivery_requested'] = 'done';
        nextStatus = reservation.tab == ReservationTab.returnDue
            ? StatusKeys.returnInProgress
            : StatusKeys.dispatchPrepared;
        logNote = 'outbox dry-run 생성';
        outboxEntry = _buildOutboxEntry(
          reservation: reservation,
          actionKey: actionKey,
          now: now,
        );
        break;
      case ActionKeys.createContract:
        checks['contract_created'] = 'done';
        nextStatus = StatusKeys.dispatchPrepared;
        break;
      case ActionKeys.sendSignatureNotice:
        checks['signature_notice_sent'] = 'done';
        nextStatus = StatusKeys.dispatchPrepared;
        break;
      case ActionKeys.confirmDispatchStart:
        checks['dispatch_started'] = 'done';
        nextTab = ReservationTab.inUse;
        nextStatus = StatusKeys.dispatchInProgress;
        badges
          ..remove('준비 미완료')
          ..add('이용 중');
        break;
      case ActionKeys.changeEndAt:
        checks['end_at_changed'] = 'done';
        nextStatus = StatusKeys.extensionReview;
        logNote = '반납일 변경 outbox dry-run 생성';
        outboxEntry = _buildOutboxEntry(
          reservation: reservation,
          actionKey: actionKey,
          now: now,
        );
        break;
      case ActionKeys.changeDropoffAddress:
        checks['dropoff_address_changed'] = 'done';
        nextStatus = StatusKeys.returnInProgress;
        logNote = '반납지 변경 outbox dry-run 생성';
        outboxEntry = _buildOutboxEntry(
          reservation: reservation,
          actionKey: actionKey,
          now: now,
        );
        break;
      case ActionKeys.completeReturn:
        checks['return_completed'] = 'done';
        nextTab = ReservationTab.completed;
        nextStatus = StatusKeys.done;
        badges
          ..clear()
          ..add('반납 완료');
        logNote = '반납완료 outbox dry-run 생성';
        outboxEntry = _buildOutboxEntry(
          reservation: reservation,
          actionKey: actionKey,
          now: now,
        );
        break;
      default:
        logNote = '로그만 기록';
    }

    reservation = reservation.copyWith(
      tab: nextTab,
      statusKey: nextStatus,
      primaryBadges: badges,
      checkPayload: checks,
      actionLogs: [
        ActionLogEntry(
          actionKey: actionKey,
          label: _actionLabel(actionKey),
          executedAt: now,
          note: logNote,
        ),
        ...reservation.actionLogs,
      ],
    );

    reservations[index] = reservation;

    state = state.copyWith(
      reservations: reservations,
      outboxEntries: outboxEntry == null
          ? state.outboxEntries
          : [outboxEntry, ...state.outboxEntries],
      syncRuns: [
        SyncRunEntry(
          id: 'sync-${now.millisecondsSinceEpoch}',
          title: '액션 반영 시뮬레이션',
          status: 'dry-run',
          note: '${reservation.reservationId} · ${_actionLabel(actionKey)}',
          executedAt: now,
        ),
        ...state.syncRuns,
      ],
    );
  }

  static OpsState _seedState() {
    return OpsState(
      reservations: [
        ReservationRecord(
          reservationId: 'R-1001',
          reservationNumber: '240508-001',
          customerName: '김태진',
          customerPhone: '010-1111-2222',
          carNumber: '123하4567',
          tab: ReservationTab.pending,
          statusKey: StatusKeys.waitingForId,
          startAt: DateTime(2026, 5, 9, 10),
          endAt: DateTime(2026, 5, 11, 10),
          locationSummary: '김해공항',
          noteText: '예약 탭 only 기준 원장 샘플',
          primaryBadges: const ['신분증 미확보', '주소 미확보'],
          checkPayload: const {
            'id_verified': 'pending',
            'address_verified': 'pending',
            'pickup_ready': 'pending',
          },
          actionLogs: const [],
        ),
        ReservationRecord(
          reservationId: 'R-1002',
          reservationNumber: '240508-002',
          customerName: '박서연',
          customerPhone: '010-2222-3333',
          carNumber: '234하5678',
          tab: ReservationTab.pickupToday,
          statusKey: StatusKeys.readyForDispatch,
          startAt: DateTime(2026, 5, 8, 16, 30),
          endAt: DateTime(2026, 5, 10, 11),
          locationSummary: '부산역',
          noteText: '준비 미완료 주황 경고 샘플',
          primaryBadges: const ['준비 미완료', '계약 미완료'],
          checkPayload: const {
            'pickup_notice_sent': 'pending',
            'delivery_requested': 'pending',
            'contract_created': 'pending',
            'signature_notice_sent': 'pending',
            'dispatch_started': 'pending',
          },
          actionLogs: const [],
        ),
        ReservationRecord(
          reservationId: 'R-1003',
          reservationNumber: '240508-003',
          customerName: '이준호',
          customerPhone: '010-3333-4444',
          carNumber: '345하6789',
          tab: ReservationTab.inUse,
          statusKey: StatusKeys.inUse,
          startAt: DateTime(2026, 5, 7, 9),
          endAt: DateTime(2026, 5, 10, 18),
          locationSummary: '해운대',
          noteText: '반납 하루 전 노랑 경고 샘플',
          primaryBadges: const ['반납 임박'],
          checkPayload: const {
            'dispatch_started': 'done',
            'signature_verified': 'pending',
            'return_notice_sent': 'pending',
            'end_at_changed': 'pending',
          },
          actionLogs: const [],
        ),
        ReservationRecord(
          reservationId: 'R-1004',
          reservationNumber: '240508-004',
          customerName: '최하늘',
          customerPhone: '010-4444-5555',
          carNumber: '456하7890',
          tab: ReservationTab.returnDue,
          statusKey: StatusKeys.returnDue,
          startAt: DateTime(2026, 5, 5, 13),
          endAt: DateTime(2026, 5, 8, 20),
          locationSummary: '서면',
          noteText: '반납 당일 처리 샘플',
          primaryBadges: const ['반납완료 직전 미처리'],
          checkPayload: const {
            'return_notice_sent': 'pending',
            'delivery_requested': 'pending',
            'dropoff_address_changed': 'pending',
            'return_completed': 'pending',
          },
          actionLogs: const [],
        ),
        ReservationRecord(
          reservationId: 'R-1005',
          reservationNumber: '240508-005',
          customerName: '정민수',
          customerPhone: '010-5555-6666',
          carNumber: '567하8901',
          tab: ReservationTab.completed,
          statusKey: StatusKeys.done,
          startAt: DateTime(2026, 5, 2, 10),
          endAt: DateTime(2026, 5, 8, 11, 10),
          locationSummary: '김해공항',
          noteText: '완료 후 7일 이내 조회 샘플',
          primaryBadges: const ['특이사항'],
          checkPayload: const {'return_completed': 'done'},
          actionLogs: [
            ActionLogEntry(
              actionKey: ActionKeys.completeReturn,
              label: '반납 완료',
              executedAt: DateTime(2026, 5, 8, 11, 10),
              note: '완료 처리 샘플 로그',
            ),
          ],
        ),
      ],
      outboxEntries: [
        OutboxEntry(
          id: 'outbox-1',
          reservationId: 'R-1005',
          actionKey: ActionKeys.completeReturn,
          sheetName: '예약',
          previewLines: const [
            'sheet=예약',
            'row_key=reservation_id:R-1005',
            'apply=false (dry-run)',
          ],
          createdAt: DateTime(2026, 5, 8, 11, 10),
        ),
      ],
      syncRuns: [
        SyncRunEntry(
          id: 'run-1',
          title: '초기 mock import',
          status: 'success',
          note: '예약/일정 raw import 시뮬레이션',
          executedAt: DateTime(2026, 5, 8, 15, 40),
        ),
      ],
    );
  }

  static OutboxEntry _buildOutboxEntry({
    required ReservationRecord reservation,
    required String actionKey,
    required DateTime now,
  }) {
    final sheetName = switch (actionKey) {
      ActionKeys.requestDelivery => '일정',
      ActionKeys.changeEndAt => '예약',
      ActionKeys.changeDropoffAddress => '예약',
      ActionKeys.completeReturn => '예약',
      _ => 'internal',
    };

    return OutboxEntry(
      id: 'outbox-${now.millisecondsSinceEpoch}',
      reservationId: reservation.reservationId,
      actionKey: actionKey,
      sheetName: sheetName,
      previewLines: [
        'sheet=$sheetName',
        'row_key=reservation_id:${reservation.reservationId}',
        'action=$actionKey',
        'apply=false (dry-run)',
      ],
      createdAt: now,
    );
  }

  static String _actionLabel(String actionKey) {
    return switch (actionKey) {
      ActionKeys.checkId => '신분증 확보 확인',
      ActionKeys.checkAddress => '주소 확보 확인',
      ActionKeys.markPickupReady => '배차준비완료',
      ActionKeys.sendPickupNotice => '배차 안내 문자',
      ActionKeys.requestDelivery => '탁송 요청',
      ActionKeys.createContract => '계약서 작성',
      ActionKeys.sendSignatureNotice => '서명 안내 문자',
      ActionKeys.confirmDispatchStart => '실제 출발 확인',
      ActionKeys.changeEndAt => '반납일 변경',
      ActionKeys.changeDropoffAddress => '반납지 변경',
      ActionKeys.completeReturn => '반납 완료',
      _ => actionKey,
    };
  }
}
