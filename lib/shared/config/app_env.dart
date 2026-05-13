import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppEnv {
  AppEnv({
    required this.projectName,
    required this.projectRef,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.supabasePublishableKey,
    required this.aiParserBaseUrl,
  });

  final String projectName;
  final String projectRef;
  final String supabaseUrl;
  final String supabaseAnonKey;
  final String supabasePublishableKey;
  final String aiParserBaseUrl;

  static AppEnv fromDotenv(DotEnv env) {
    String read(String key) {
      final value = env.maybeGet(key)?.trim();
      if (value == null || value.isEmpty) {
        throw StateError('Missing required env key: $key');
      }
      return value;
    }

    return AppEnv(
      projectName: read('SUPABASE_PROJECT_NAME'),
      projectRef: read('SUPABASE_PROJECT_REF'),
      supabaseUrl: read('SUPABASE_URL'),
      supabaseAnonKey: read('SUPABASE_ANON_KEY'),
      supabasePublishableKey: read('SUPABASE_PUBLISHABLE_KEY'),
      aiParserBaseUrl: env.maybeGet('AI_PARSER_BASE_URL')?.trim() ?? '',
    );
  }
}
