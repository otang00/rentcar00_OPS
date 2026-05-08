import 'package:rentcar00_ops/data/models/reservation_record.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseOpsRepository {
  SupabaseOpsRepository(this._client);

  final SupabaseClient _client;

  SupabaseClient get client => _client;

  Future<List<ReservationRecord>> fetchReservations() async {
    // Phase 1 skeleton only.
    // Actual mapping starts after rc00_ops_* tables are created.
    return const [];
  }
}
