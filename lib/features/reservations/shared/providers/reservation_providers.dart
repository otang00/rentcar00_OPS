import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentcar00_ops/app/domain/ops_layer.dart';
import 'package:rentcar00_ops/data/models/action_log_entry.dart';
import 'package:rentcar00_ops/data/models/external_reservation_link.dart';
import 'package:rentcar00_ops/data/models/outbox_entry.dart';
import 'package:rentcar00_ops/data/models/reservation_action_definition.dart';
import 'package:rentcar00_ops/data/models/reservation_record.dart';
import 'package:rentcar00_ops/data/models/status_board_record.dart';
import 'package:rentcar00_ops/data/repositories/supabase_ops_repository.dart';
import 'package:rentcar00_ops/features/reservations/shared/domain/reservation_summary.dart';
import 'package:rentcar00_ops/features/reservations/shared/domain/reservation_tab.dart';
import 'package:rentcar00_ops/features/status_board/shared/domain/status_board_tab.dart';
import 'package:rentcar00_ops/shared/config/supabase_providers.dart';
import 'package:rentcar00_ops/shared/constants/action_keys.dart';
import 'package:rentcar00_ops/shared/utils/ops_kst_datetime.dart';

final selectedOpsLayerProvider = StateProvider<OpsLayer>(
  (ref) => OpsLayer.statusBoard,
);
final selectedReservationTabProvider = StateProvider<ReservationTab>(
  (ref) => ReservationTab.pending,
);
final selectedStatusBoardTabProvider = StateProvider<StatusBoardTab>(
  (ref) => StatusBoardTab.idle,
);
final searchQueryProvider = StateProvider<String>((ref) => '');

final supabaseOpsRepositoryProvider = Provider<SupabaseOpsRepository>((ref) {
  return SupabaseOpsRepository(ref.watch(supabaseClientProvider));
});

final allReservationsProvider = FutureProvider<List<ReservationRecord>>((
  ref,
) async {
  return ref.watch(supabaseOpsRepositoryProvider).fetchReservations();
});

final allStatusBoardRecordsProvider = FutureProvider<List<StatusBoardRecord>>((
  ref,
) async {
  return ref.watch(supabaseOpsRepositoryProvider).fetchStatusBoardRecords();
});

final tabListProvider =
    Provider.family<AsyncValue<List<ReservationSummary>>, ReservationTab>((
      ref,
      tab,
    ) {
      final reservationsAsync = ref.watch(allReservationsProvider);
      return reservationsAsync.whenData(
        (items) =>
            items.where((item) => item.tab == tab).map(_toSummary).toList(),
      );
    });

final tabCountsProvider = Provider<AsyncValue<Map<ReservationTab, int>>>((ref) {
  final reservationsAsync = ref.watch(allReservationsProvider);
  return reservationsAsync.whenData((reservations) {
    return {
      for (final tab in ReservationTab.values)
        tab: reservations.where((item) => item.tab == tab).length,
    };
  });
});

final homepagePendingReservationsProvider =
    Provider<AsyncValue<List<ReservationRecord>>>((ref) {
      final reservationsAsync = ref.watch(allReservationsProvider);
      return reservationsAsync.whenData(
        (reservations) => reservations
            .where((item) => item.checkPayload['homepage_review'] == 'pending')
            .toList(),
      );
    });

final homepagePendingCountProvider = Provider<AsyncValue<int>>((ref) {
  return ref
      .watch(homepagePendingReservationsProvider)
      .whenData((items) => items.length);
});

final reservationDetailProvider =
    Provider.family<AsyncValue<ReservationRecord?>, String>((
      ref,
      reservationId,
    ) {
      final reservationsAsync = ref.watch(allReservationsProvider);
      return reservationsAsync.whenData((items) {
        for (final item in items) {
          if (item.reservationId == reservationId) {
            return item;
          }
        }
        return null;
      });
    });

final externalReservationLinkProvider =
    FutureProvider.family<ExternalReservationLink?, String>((
      ref,
      reservationId,
    ) {
      return ref
          .watch(supabaseOpsRepositoryProvider)
          .fetchExternalReservationLink(reservationId: reservationId);
    });

final reservationActionsProvider =
    Provider.family<AsyncValue<List<ReservationActionDefinition>>, String>((
      ref,
      reservationId,
    ) {
      final reservationAsync = ref.watch(
        reservationDetailProvider(reservationId),
      );
      return reservationAsync.whenData((reservation) {
        if (reservation == null) {
          return const [];
        }

        return switch (reservation.tab) {
          ReservationTab.pending => const [
            ReservationActionDefinition(
              key: ActionKeys.checkId,
              label: '신분증 확보 확인',
              description: '쓰기 로직 연결 전까지는 read-only 상태입니다.',
            ),
            ReservationActionDefinition(
              key: ActionKeys.checkAddress,
              label: '주소 확보 확인',
              description: '쓰기 로직 연결 전까지는 read-only 상태입니다.',
            ),
            ReservationActionDefinition(
              key: ActionKeys.markPickupReady,
              label: '배차준비완료',
              description: '쓰기 로직 연결 전까지는 read-only 상태입니다.',
            ),
          ],
          ReservationTab.pickupToday => const [
            ReservationActionDefinition(
              key: ActionKeys.sendPickupNotice,
              label: '배차 안내 문자',
              description: '쓰기 로직 연결 전까지는 read-only 상태입니다.',
            ),
            ReservationActionDefinition(
              key: ActionKeys.requestDelivery,
              label: '탁송 요청',
              description: '쓰기 로직 연결 전까지는 read-only 상태입니다.',
              createsOutbox: true,
            ),
          ],
          ReservationTab.inUse => const [
            ReservationActionDefinition(
              key: ActionKeys.changeEndAt,
              label: '반납일 변경',
              description: '쓰기 로직 연결 전까지는 read-only 상태입니다.',
              createsOutbox: true,
            ),
          ],
          ReservationTab.returnDue => const [
            ReservationActionDefinition(
              key: ActionKeys.requestDelivery,
              label: '회수 탁송 요청',
              description: '쓰기 로직 연결 전까지는 read-only 상태입니다.',
              createsOutbox: true,
            ),
            ReservationActionDefinition(
              key: ActionKeys.completeReturn,
              label: '반납 완료',
              description: '쓰기 로직 연결 전까지는 read-only 상태입니다.',
              createsOutbox: true,
            ),
          ],
          ReservationTab.completed => const [],
        };
      });
    });

final actionLogsProvider =
    Provider.family<AsyncValue<List<ActionLogEntry>>, String>((
      ref,
      reservationId,
    ) {
      return const AsyncValue.data([]);
    });

final outboxPreviewProvider = Provider.family<AsyncValue<List<String>>, String>(
  (ref, reservationId) {
    return const AsyncValue.data([
      'outbox 없음',
      'dry_run=true',
      'Google Sheets apply는 아직 비활성화',
    ]);
  },
);

final outboxEntriesProvider = Provider<AsyncValue<List<OutboxEntry>>>((ref) {
  return const AsyncValue.data([]);
});

final filteredReservationsProvider =
    Provider<AsyncValue<List<ReservationSummary>>>((ref) {
      final query = ref.watch(searchQueryProvider).trim().toLowerCase();
      final reservationsAsync = ref.watch(allReservationsProvider);

      return reservationsAsync.whenData((items) {
        final summaries = items.map(_toSummary).toList();
        if (query.isEmpty) {
          return summaries;
        }

        return summaries.where((item) {
          return item.customerName.toLowerCase().contains(query) ||
              item.carNumber.toLowerCase().contains(query) ||
              item.carName.toLowerCase().contains(query) ||
              item.reservationId.toLowerCase().contains(query) ||
              item.reservationNumber.toLowerCase().contains(query);
        }).toList();
      });
    });

final statusBoardListProvider =
    Provider.family<AsyncValue<List<StatusBoardRecord>>, StatusBoardTab>((
      ref,
      tab,
    ) {
      final boardAsync = ref.watch(allStatusBoardRecordsProvider);
      return boardAsync.whenData(
        (items) => items.where((item) => item.tab == tab).toList(),
      );
    });

final statusBoardCountsProvider =
    Provider<AsyncValue<Map<StatusBoardTab, int>>>((ref) {
      final boardAsync = ref.watch(allStatusBoardRecordsProvider);
      return boardAsync.whenData((items) {
        return {
          for (final tab in StatusBoardTab.values)
            tab: items.where((item) => item.tab == tab).length,
        };
      });
    });

final statusBoardDetailProvider =
    Provider.family<AsyncValue<StatusBoardRecord?>, String>((ref, recordId) {
      final boardAsync = ref.watch(allStatusBoardRecordsProvider);
      return boardAsync.whenData((items) {
        for (final item in items) {
          if (item.recordId == recordId) {
            return item;
          }
        }
        return null;
      });
    });

final relatedSchedulesProvider =
    Provider.family<AsyncValue<List<StatusBoardRecord>>, String>((
      ref,
      recordId,
    ) {
      final boardAsync = ref.watch(allStatusBoardRecordsProvider);
      return boardAsync.whenData((items) {
        StatusBoardRecord? target;
        for (final item in items) {
          if (item.recordId == recordId) {
            target = item;
            break;
          }
        }
        if (target == null) {
          return const [];
        }

        final startOfToday = DateTime.now();
        final todayFloor = DateTime(
          startOfToday.year,
          startOfToday.month,
          startOfToday.day,
        );

        return items.where((item) {
          if (!item.isScheduleEntry) return false;
          if (item.carNumber.isEmpty || item.carNumber != target!.carNumber) {
            return false;
          }
          final sortAt = item.sortAt;
          if (sortAt == null) {
            return true;
          }
          return !sortAt.isBefore(todayFloor);
        }).toList();
      });
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
    carName: item.carName,
    tab: item.tab,
    statusKey: item.statusKey,
    startAt: item.startAt,
    endAt: item.endAt,
    displayAt: baseTime,
    timeLabel: _formatDateTime(baseTime),
    locationSummary: item.locationSummary,
    noteText: item.noteText,
    primaryBadges: _prioritizeBadges(item.primaryBadges),
  );
}

List<String> _prioritizeBadges(List<String> badges) {
  final visible = <String>[];
  for (final badge in badges) {
    if (_isCompletedBadge(badge)) {
      continue;
    }
    if (!visible.contains(badge)) {
      visible.add(badge);
    }
  }

  visible.sort((a, b) => _badgePriority(a).compareTo(_badgePriority(b)));
  return visible.take(3).toList();
}

bool _isCompletedBadge(String badge) {
  return switch (badge) {
    '반납 완료' || '이상 없음' => true,
    _ => false,
  };
}

int _badgePriority(String badge) {
  return switch (badge) {
    '홈페이지 확인' || '확인 필요' || '특이사항' || '반납완료 직전 미처리' => 0,
    '신분증 미확보' ||
    '주소 미확보' ||
    '고객명 미확인' ||
    '연락처 미확인' ||
    '위치 미확인' ||
    '준비 미완료' ||
    '계약 미완료' => 1,
    '배차 지연' || '반납 지연' => 0,
    '오늘 배차' || '오늘 반납' || '반납 임박' || '연장·이슈' => 2,
    '배차일+1' => 2,
    '배차일+2' => 3,
    '배차일+3' || '반납 완료' => 4,
    _ => 4,
  };
}

String _formatDateTime(DateTime value) {
  final kst = opsAsKstWallTime(value);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(kst.month)}/${two(kst.day)}(${opsKoreanWeekday(kst)}) ${two(kst.hour)}:${two(kst.minute)}';
}
