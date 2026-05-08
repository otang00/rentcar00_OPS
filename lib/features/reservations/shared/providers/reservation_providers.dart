import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentcar00_ops/data/models/action_log_entry.dart';
import 'package:rentcar00_ops/data/models/outbox_entry.dart';
import 'package:rentcar00_ops/data/models/reservation_action_definition.dart';
import 'package:rentcar00_ops/data/models/reservation_record.dart';
import 'package:rentcar00_ops/data/models/sync_run_entry.dart';
import 'package:rentcar00_ops/data/repositories/mock_ops_repository.dart';
import 'package:rentcar00_ops/features/reservations/shared/domain/reservation_summary.dart';
import 'package:rentcar00_ops/features/reservations/shared/domain/reservation_tab.dart';
import 'package:rentcar00_ops/shared/constants/action_keys.dart';

final searchQueryProvider = StateProvider<String>((ref) => '');

final allReservationsProvider = Provider<List<ReservationRecord>>((ref) {
  return ref.watch(opsStateProvider).reservations;
});

final tabListProvider =
    Provider.family<List<ReservationSummary>, ReservationTab>((ref, tab) {
      return ref
          .watch(allReservationsProvider)
          .where((item) => item.tab == tab)
          .map(_toSummary)
          .toList();
    });

final tabCountsProvider = Provider<Map<ReservationTab, int>>((ref) {
  final reservations = ref.watch(allReservationsProvider);
  return {
    for (final tab in ReservationTab.values)
      tab: reservations.where((item) => item.tab == tab).length,
  };
});

final reservationDetailProvider = Provider.family<ReservationRecord?, String>((
  ref,
  reservationId,
) {
  for (final item in ref.watch(allReservationsProvider)) {
    if (item.reservationId == reservationId) {
      return item;
    }
  }
  return null;
});

final reservationActionsProvider =
    Provider.family<List<ReservationActionDefinition>, String>((
      ref,
      reservationId,
    ) {
      final reservation = ref.watch(reservationDetailProvider(reservationId));
      if (reservation == null) {
        return const [];
      }

      return switch (reservation.tab) {
        ReservationTab.pending => const [
          ReservationActionDefinition(
            key: ActionKeys.checkId,
            label: '신분증 확보 확인',
            description: '신분증 확보 체크를 done 으로 바꿉니다.',
          ),
          ReservationActionDefinition(
            key: ActionKeys.checkAddress,
            label: '주소 확보 확인',
            description: '주소 확보 체크를 done 으로 바꿉니다.',
          ),
          ReservationActionDefinition(
            key: ActionKeys.markPickupReady,
            label: '배차준비완료',
            description: '예약중 준비 상태를 ready 로 갱신합니다.',
          ),
        ],
        ReservationTab.pickupToday => const [
          ReservationActionDefinition(
            key: ActionKeys.sendPickupNotice,
            label: '배차 안내 문자',
            description: '배차 안내 발송 체크를 갱신합니다.',
          ),
          ReservationActionDefinition(
            key: ActionKeys.requestDelivery,
            label: '탁송 요청',
            description: 'dry-run outbox 를 생성합니다.',
            createsOutbox: true,
          ),
          ReservationActionDefinition(
            key: ActionKeys.createContract,
            label: '계약서 작성',
            description: '계약 준비 체크를 갱신합니다.',
          ),
          ReservationActionDefinition(
            key: ActionKeys.sendSignatureNotice,
            label: '서명 안내 문자',
            description: '서명 안내 체크를 갱신합니다.',
          ),
          ReservationActionDefinition(
            key: ActionKeys.confirmDispatchStart,
            label: '실제 출발 확인',
            description: '배차중 탭으로 전이합니다.',
          ),
        ],
        ReservationTab.inUse => const [
          ReservationActionDefinition(
            key: ActionKeys.changeEndAt,
            label: '반납일 변경',
            description: '연장 검토 상태와 dry-run outbox 를 생성합니다.',
            createsOutbox: true,
          ),
        ],
        ReservationTab.returnDue => const [
          ReservationActionDefinition(
            key: ActionKeys.requestDelivery,
            label: '회수 탁송 요청',
            description: '회수용 dry-run outbox 를 생성합니다.',
            createsOutbox: true,
          ),
          ReservationActionDefinition(
            key: ActionKeys.changeDropoffAddress,
            label: '반납지 변경',
            description: '반납지 변경 dry-run outbox 를 생성합니다.',
            createsOutbox: true,
          ),
          ReservationActionDefinition(
            key: ActionKeys.completeReturn,
            label: '반납 완료',
            description: '완료 탭으로 전이합니다.',
            createsOutbox: true,
          ),
        ],
        ReservationTab.completed => const [],
      };
    });

final actionLogsProvider = Provider.family<List<ActionLogEntry>, String>((
  ref,
  reservationId,
) {
  return ref.watch(reservationDetailProvider(reservationId))?.actionLogs ??
      const [];
});

final outboxPreviewProvider = Provider.family<List<String>, String>((
  ref,
  reservationId,
) {
  final entries = ref
      .watch(opsStateProvider)
      .outboxEntries
      .where((item) => item.reservationId == reservationId)
      .toList();

  if (entries.isEmpty) {
    return const ['outbox 없음', 'dry_run=true', 'Google Sheets apply는 아직 비활성화'];
  }

  return entries.first.previewLines;
});

final outboxEntriesProvider = Provider<List<OutboxEntry>>((ref) {
  return ref.watch(opsStateProvider).outboxEntries;
});

final syncRunsProvider = Provider<List<SyncRunEntry>>((ref) {
  return ref.watch(opsStateProvider).syncRuns;
});

final filteredReservationsProvider = Provider<List<ReservationSummary>>((ref) {
  final query = ref.watch(searchQueryProvider).trim().toLowerCase();
  final items = ref.watch(allReservationsProvider).map(_toSummary).toList();

  if (query.isEmpty) {
    return items;
  }

  return items.where((item) {
    return item.customerName.toLowerCase().contains(query) ||
        item.carNumber.toLowerCase().contains(query) ||
        item.reservationId.toLowerCase().contains(query) ||
        item.reservationNumber.toLowerCase().contains(query);
  }).toList();
});

ReservationSummary _toSummary(ReservationRecord item) {
  final baseTime = switch (item.tab) {
    ReservationTab.pending || ReservationTab.pickupToday => item.startAt,
    ReservationTab.inUse ||
    ReservationTab.returnDue ||
    ReservationTab.completed => item.endAt,
  };

  return ReservationSummary(
    reservationId: item.reservationId,
    reservationNumber: item.reservationNumber,
    customerName: item.customerName,
    customerPhone: item.customerPhone,
    carNumber: item.carNumber,
    tab: item.tab,
    statusKey: item.statusKey,
    timeLabel: _formatDateTime(baseTime),
    locationSummary: item.locationSummary,
    noteText: item.noteText,
    primaryBadges: item.primaryBadges,
  );
}

String _formatDateTime(DateTime value) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(value.month)}/${two(value.day)} ${two(value.hour)}:${two(value.minute)}';
}
