import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentcar00_ops/features/admin/data/admin_staff_repository.dart';
import 'package:rentcar00_ops/features/admin/domain/admin_staff_account.dart';
import 'package:rentcar00_ops/shared/config/supabase_providers.dart';

final adminStaffRepositoryProvider = Provider<AdminStaffRepository>((ref) {
  return AdminStaffRepository(ref.watch(supabaseClientProvider));
});

final adminStaffAccountsProvider = FutureProvider<List<AdminStaffAccount>>((
  ref,
) async {
  return ref.watch(adminStaffRepositoryProvider).fetchStaffAccounts();
});
