import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentcar00_ops/shared/config/app_env.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final appEnvProvider = Provider<AppEnv>((ref) {
  return AppEnv.fromDotenv(dotenv);
});

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});
