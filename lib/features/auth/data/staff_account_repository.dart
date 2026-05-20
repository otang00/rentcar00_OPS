import 'package:rentcar00_ops/features/auth/domain/staff_account.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StaffAccountRepository {
  StaffAccountRepository(this._client);

  final SupabaseClient _client;

  Future<void> markCurrentStaffActivity() async {
    await _client.rpc<void>('rc00_ops_mark_current_staff_activity');
  }

  Future<StaffAccount?> fetchByAuthUserId(String authUserId) async {
    final row = await _client
        .from('rc00_ops_staff_accounts')
        .select('id, auth_user_id, login_id, display_name, role, is_active')
        .eq('auth_user_id', authUserId)
        .maybeSingle();

    if (row == null) {
      return null;
    }

    return StaffAccount.fromJson(row);
  }
}
