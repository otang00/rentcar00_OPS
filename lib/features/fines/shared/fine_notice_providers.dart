import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentcar00_ops/features/fines/data/fine_notice_repository.dart';
import 'package:rentcar00_ops/features/fines/domain/fine_notice_models.dart';
import 'package:rentcar00_ops/shared/config/supabase_providers.dart';

final fineNoticeRepositoryProvider = Provider<FineNoticeRepository>((ref) {
  return FineNoticeRepository(ref.watch(supabaseClientProvider));
});

final fineNoticeCasesProvider = FutureProvider<List<FineNoticeCase>>((ref) {
  return ref.watch(fineNoticeRepositoryProvider).fetchCases();
});
