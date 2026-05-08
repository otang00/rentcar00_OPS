import 'package:rentcar00_ops/data/models/outbox_entry.dart';
import 'package:rentcar00_ops/data/models/reservation_record.dart';
import 'package:rentcar00_ops/data/models/sync_run_entry.dart';

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
