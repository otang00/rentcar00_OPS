import 'package:rentcar00_ops/features/admin/domain/admin_staff_account.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminStaffRepository {
  AdminStaffRepository(this._client);

  final SupabaseClient _client;

  Future<List<AdminStaffAccount>> fetchStaffAccounts() async {
    final rows = await _client
        .from('rc00_ops_staff_accounts')
        .select(
          'id, auth_user_id, login_id, display_name, role, is_active, phone_number, last_activity_at, last_login_at, last_location_text, last_lat, last_lng',
        )
        .order('role')
        .order('login_id');

    final passwordRows = await _client
        .from('rc00_ops_staff_passwords')
        .select('staff_account_id, password_text');
    final passwordByStaffId = {
      for (final row in passwordRows)
        row['staff_account_id'] as String:
            (row['password_text'] as String?) ?? '',
    };

    return rows
        .map<AdminStaffAccount>(
          (row) => AdminStaffAccount.fromJson(
            row,
            adminVisiblePassword: passwordByStaffId[row['id'] as String] ?? '',
          ),
        )
        .toList();
  }

  Future<void> updateStaffAccount({
    required String staffAccountId,
    required String displayName,
    required String phoneNumber,
    required String role,
    required bool isActive,
  }) async {
    await _client
        .from('rc00_ops_staff_accounts')
        .update({
          'display_name': displayName.trim(),
          'phone_number': phoneNumber.trim(),
          'role': role.trim().toLowerCase() == 'admin' ? 'admin' : 'staff',
          'is_active': isActive,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', staffAccountId.trim());
  }

  Future<void> upsertAdminVisiblePassword({
    required String staffAccountId,
    required String password,
  }) async {
    await _client.from('rc00_ops_staff_passwords').upsert({
      'staff_account_id': staffAccountId.trim(),
      'password_text': password.trim(),
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'staff_account_id');
  }
}
