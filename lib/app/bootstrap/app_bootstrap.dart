import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:rentcar00_ops/shared/config/app_env.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<AppEnv> bootstrapApp() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  final env = AppEnv.fromDotenv(dotenv);

  await Supabase.initialize(url: env.supabaseUrl, anonKey: env.supabaseAnonKey);

  return env;
}
