import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentcar00_ops/features/reservations/shared/providers/reservation_providers.dart';
import 'package:rentcar00_ops/shared/config/supabase_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OpsRealtimeRefreshBridge extends ConsumerStatefulWidget {
  const OpsRealtimeRefreshBridge({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<OpsRealtimeRefreshBridge> createState() =>
      _OpsRealtimeRefreshBridgeState();
}

class _OpsRealtimeRefreshBridgeState
    extends ConsumerState<OpsRealtimeRefreshBridge>
    with WidgetsBindingObserver {
  final List<RealtimeChannel> _channels = [];
  Timer? _refreshDebounce;
  SupabaseClient? _client;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _subscribe());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _scheduleCoreRefresh();
    }
  }

  void _subscribe() {
    if (!mounted || _channels.isNotEmpty) return;
    try {
      if (!Supabase.instance.isInitialized) return;
    } catch (_) {
      return;
    }

    final client = ref.read(supabaseClientProvider);
    _client = client;
    for (final table in _coreRealtimeTables) {
      final channel = client
          .channel('ops_core_$table')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: table,
            callback: (_) => _scheduleCoreRefresh(),
          )
          .subscribe();
      _channels.add(channel);
    }
  }

  void _scheduleCoreRefresh() {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      ref.invalidate(allReservationsProvider);
      ref.invalidate(allStatusBoardRecordsProvider);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshDebounce?.cancel();
    final client = _client;
    if (client == null) {
      super.dispose();
      return;
    }
    for (final channel in _channels) {
      client.removeChannel(channel);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

const _coreRealtimeTables = [
  'rc00_ops_reservations',
  'rc00_ops_reservation_states',
  'rc00_ops_schedules',
  'rc00_ops_cars',
];
