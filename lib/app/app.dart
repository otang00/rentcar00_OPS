import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentcar00_ops/app/router/app_router.dart';
import 'package:rentcar00_ops/shared/theme/app_theme.dart';

class Rentcar00OpsApp extends ConsumerWidget {
  const Rentcar00OpsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'rentcar00 OPS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: router,
    );
  }
}
