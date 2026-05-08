import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentcar00_ops/app/app.dart';
import 'package:rentcar00_ops/app/bootstrap/app_bootstrap.dart';

Future<void> main() async {
  await bootstrapApp();
  runApp(const ProviderScope(child: Rentcar00OpsApp()));
}
