import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentcar00_ops/data/models/action_log_entry.dart';
import 'package:rentcar00_ops/data/models/outbox_entry.dart';
import 'package:rentcar00_ops/data/models/reservation_record.dart';
import 'package:rentcar00_ops/data/models/sync_run_entry.dart';
import 'package:rentcar00_ops/features/reservations/shared/domain/reservation_tab.dart';
import 'package:rentcar00_ops/shared/constants/action_keys.dart';
import 'package:rentcar00_ops/shared/constants/status_keys.dart';

class OpsState {
  const OpsState({
    required this.reservations,
    required this.outboxEntries,
    required this.syncRuns,
  });

  final List<ReservationRecord> reservations;
  final List<OutboxEntry> outboxEntries;
  final List<SyncRunEntry> syncRuns;

  OpsState copyWith({
    List<ReservationRecord>? reservations,
    List<OutboxEntry>? outboxEntries,
    List<SyncRunEntry>? syncRuns,
  }) {
    return OpsState(
      reservations: reservations ?? this.reservations,
      outboxEntries: outboxEntries ?? this.outboxEntries,
      syncRuns: syncRuns ?? this.syncRuns,
    );
  }
}

class MockOpsRepository extends StateNotifier<OpsState> {
  MockOpsRepository() : super(_seedState());

  Future<List<ReservationRecord>> fetchReservations() async {
    return state.reservations;
  }

  Future<List<SyncRunEntry>> fetchSyncRuns() async {
    return state.syncRuns;
  }

  Future<void> runAction({
    required String reservationId,
    required String actionKey,
  }) async {
    final reservation = state.reservations.firstWhere(
      (item) => item.reservationId == reservationId,
    );
    final now = DateTime.now();

    final updatedReservation = reservation.copyWith(
      noteText: '${reservation.noteText} · ${_actionLabel(actionKey)} 실행',
      actionLogs: [
        ActionLogEntry(
          actionKey: actionKey,
          label: _actionLabel(actionKey),
          executedAt: now,
          note: 'read-only mock action',
        ),
        ...reservation.actionLogs,
      ],
    );

    final updatedReservations = [
      for (final item in state.reservations)
        if (item.reservationId == reservationId) updatedReservation else item,
    ];

    state = state.copyWith(
      reservations: updatedReservations,
      syncRuns: [
        SyncRunEntry(
          id: 'sync-${now.microsecondsSinceEpoch}',
          title: 'Mock action run',
          status: 'success',
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
          customerBirthDate: '1990-01-01',
          referralSource: '전화문의',
          paymentAmount: '120000',
          carNumber: '123하4567',
          carName: 'K5',
          tab: ReservationTab.pending,
          statusKey: StatusKeys.waitingForId,
          startAt: DateTime(2026, 5, 9, 10),
          endAt: DateTime(2026, 5, 11, 10),
          locationSummary: '김해공항 국내선 1층',
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
          customerBirthDate: '1992-02-02',
          referralSource: '소개',
          paymentAmount: '135000',
          carNumber: '234하5678',
          carName: '아반떼',
          tab: ReservationTab.pickupToday,
          statusKey: StatusKeys.readyForDispatch,
          startAt: DateTime(2026, 5, 8, 16, 30),
          endAt: DateTime(2026, 5, 10, 11),
          locationSummary: '부산역 1번 출구',
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
          customerBirthDate: '1988-03-03',
          referralSource: '네이버',
          paymentAmount: '148000',
          carNumber: '345하6789',
          carName: '쏘렌토',
          tab: ReservationTab.inUse,
          statusKey: StatusKeys.inUse,
          startAt: DateTime(2026, 5, 7, 9),
          endAt: DateTime(2026, 5, 10, 18),
          locationSummary: '해운대 그랜드조선 앞',
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
          customerBirthDate: '1995-04-04',
          referralSource: '재이용',
          paymentAmount: '99000',
          carNumber: '456하7890',
          carName: '캐스퍼',
          tab: ReservationTab.returnDue,
          statusKey: StatusKeys.returnDue,
          startAt: DateTime(2026, 5, 5, 13),
          endAt: DateTime(2026, 5, 8, 20),
          locationSummary: '서면 롯데백화점 후문',
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
          customerBirthDate: '1986-05-05',
          referralSource: '보험사',
          paymentAmount: '210000',
          carNumber: '567하8901',
          carName: '스타리아',
          tab: ReservationTab.completed,
          statusKey: StatusKeys.done,
          startAt: DateTime(2026, 5, 2, 10),
          endAt: DateTime(2026, 5, 8, 11, 10),
          locationSummary: '김해공항 국제선 3번 게이트',
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
          id: 'sync-1',
          title: 'Google Sheets raw import',
          status: 'success',
          note: '예약 raw 79 / 일정 raw 78',
          executedAt: DateTime(2026, 5, 8, 9, 30),
        ),
      ],
    );
  }
}

String _actionLabel(String actionKey) {
  return switch (actionKey) {
    ActionKeys.checkId => '신분증 확보 확인',
    ActionKeys.checkAddress => '주소 확보 확인',
    ActionKeys.markPickupReady => '배차준비완료',
    ActionKeys.sendPickupNotice => '배차 안내 문자',
    ActionKeys.requestDelivery => '탁송 요청',
    ActionKeys.changeEndAt => '반납일 변경',
    ActionKeys.completeReturn => '반납 완료',
    _ => actionKey,
  };
}
