import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentcar00_ops/features/auth/data/staff_account_repository.dart';
import 'package:rentcar00_ops/features/auth/domain/staff_account.dart';
import 'package:rentcar00_ops/features/auth/shared/auth_alias.dart';
import 'package:rentcar00_ops/features/auth/shared/auth_exceptions.dart';
import 'package:rentcar00_ops/shared/config/supabase_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final authStatusMessageProvider = StateProvider<String?>((ref) => null);

final staffAccountRepositoryProvider = Provider<StaffAccountRepository>((ref) {
  return StaffAccountRepository(ref.watch(supabaseClientProvider));
});

final authRefreshListenableProvider = Provider<AuthRefreshListenable>((ref) {
  final listenable = AuthRefreshListenable(ref.watch(supabaseClientProvider));
  ref.onDispose(listenable.dispose);
  return listenable;
});

final currentStaffAccountProvider = FutureProvider<StaffAccount?>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final session = client.auth.currentSession;
  final user = session?.user;

  if (user == null) {
    return null;
  }

  return ref.watch(staffAccountRepositoryProvider).fetchByAuthUserId(user.id);
});

final authControllerProvider = Provider<AuthController>((ref) {
  return AuthController(ref);
});

class AuthController {
  AuthController(this._ref);

  final Ref _ref;

  SupabaseClient get _client => _ref.read(supabaseClientProvider);
  StaffAccountRepository get _staffRepository =>
      _ref.read(staffAccountRepositoryProvider);

  Future<StaffAccount> signIn({
    required String loginId,
    required String password,
  }) async {
    final normalizedLoginId = normalizeLoginId(loginId);
    final aliasEmail = buildAliasEmail(normalizedLoginId);

    _ref.read(authStatusMessageProvider.notifier).state = null;

    try {
      final response = await _client.auth.signInWithPassword(
        email: aliasEmail,
        password: password,
      );

      final user = response.user;
      if (user == null) {
        throw const AuthFlowException('아이디 또는 비밀번호가 올바르지 않습니다.');
      }

      final staffAccount = await _staffRepository.fetchByAuthUserId(user.id);
      if (staffAccount == null) {
        await rejectCurrentSession('승인되지 않은 계정입니다.');
        throw const StaffAccountNotApprovedException();
      }

      if (!staffAccount.isActive) {
        await rejectCurrentSession('비활성화된 계정입니다.');
        throw const StaffAccountInactiveException();
      }

      _ref.invalidate(currentStaffAccountProvider);
      return staffAccount;
    } on AuthException catch (_) {
      throw const AuthFlowException('아이디 또는 비밀번호가 올바르지 않습니다.');
    }
  }

  Future<void> signOut() async {
    _ref.read(authStatusMessageProvider.notifier).state = null;
    _ref.invalidate(currentStaffAccountProvider);
    await _client.auth.signOut();
  }

  Future<void> rejectCurrentSession(String message) async {
    _ref.read(authStatusMessageProvider.notifier).state = message;
    _ref.invalidate(currentStaffAccountProvider);
    await _client.auth.signOut();
  }
}

class AuthRefreshListenable extends ChangeNotifier {
  AuthRefreshListenable(SupabaseClient client) {
    _subscription = client.auth.onAuthStateChange.listen((_) {
      notifyListeners();
    });
  }

  late final StreamSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
