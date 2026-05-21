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

    await _recordAdminAction(
      actionKey: 'staff.update',
      label: '직원 정보수정',
      targetRef: staffAccountId,
      messageText: '$displayName / $role / ${isActive ? '활성' : '비활성'}',
    );
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

    await _recordAdminAction(
      actionKey: 'staff.password_update',
      label: '직원 비밀번호수정',
      targetRef: staffAccountId,
      messageText: '관리자 표시 비밀번호 수정',
    );
  }

  Future<void> _recordAdminAction({
    required String actionKey,
    required String label,
    required String targetRef,
    required String messageText,
  }) async {
    try {
      final user = _client.auth.currentUser;
      var actorId = user?.id ?? 'unknown';
      var actorName = actorId;
      if (user != null) {
        final row = await _client
            .from('rc00_ops_staff_accounts')
            .select('login_id, display_name')
            .eq('auth_user_id', user.id)
            .maybeSingle();
        actorId = row?['login_id']?.toString().trim() ?? actorId;
        final displayName = row?['display_name']?.toString().trim() ?? '';
        actorName = displayName.isEmpty ? actorId : displayName;
      }

      await _client.from('rc00_ops_action_logs').insert({
        'target_type': 'staff',
        'target_ref': targetRef.trim(),
        'action_key': actionKey.trim(),
        'action_label': label.trim(),
        'actor_id': actorId,
        'actor_name': actorName,
        'message_text': messageText.trim(),
        'result_status': 'success',
        'meta_json': const {},
      });
    } catch (_) {
      // 로그 실패가 관리자 작업 자체를 막지 않게 둔다.
    }
  }
}
