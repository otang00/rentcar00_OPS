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
  Timer? _retryTimer;
  StreamSubscription<AuthState>? _authSubscription;
  SupabaseClient? _client;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _attachAuthAndSubscribe(),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _ensureSubscribedOrRefresh();
    }
  }

  void _attachAuthAndSubscribe() {
    if (!mounted) return;
    try {
      if (!Supabase.instance.isInitialized) return;
    } catch (_) {
      return;
    }

    final client = ref.read(supabaseClientProvider);
    _client = client;
    _authSubscription ??= client.auth.onAuthStateChange.listen((_) {
      if (!mounted) return;
      if (client.auth.currentSession == null) {
        _unsubscribeCore();
        return;
      }
      _subscribeCore(force: true);
    });

    if (client.auth.currentSession != null) {
      _subscribeCore();
    }
  }

  void _ensureSubscribedOrRefresh() {
    final client = _client;
    if (client == null) {
      _attachAuthAndSubscribe();
      return;
    }
    if (client.auth.currentSession == null) return;
    if (_channels.isEmpty) {
      _subscribeCore();
      return;
    }
    _scheduleCoreRefresh();
  }

  void _subscribeCore({bool force = false}) {
    final client = _client;
    if (!mounted || client == null) return;
    if (client.auth.currentSession == null) return;
    if (_channels.isNotEmpty && !force) return;
    if (force) {
      _unsubscribeCore();
    }

    _retryTimer?.cancel();
    for (final table in _coreRealtimeTables) {
      final channel = client
          .channel('ops_core_${table}_${DateTime.now().microsecondsSinceEpoch}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: table,
            callback: (_) {
              debugPrint('ops realtime event: $table');
              _scheduleCoreRefresh();
            },
          )
          .subscribe((status, [error]) {
            debugPrint('ops realtime $table status: $status ${error ?? ''}');
            switch (status) {
              case RealtimeSubscribeStatus.subscribed:
                _scheduleCoreRefresh();
              case RealtimeSubscribeStatus.channelError:
              case RealtimeSubscribeStatus.timedOut:
              case RealtimeSubscribeStatus.closed:
                _scheduleRetry();
            }
          });
      _channels.add(channel);
    }
  }

  void _scheduleRetry() {
    if (!mounted) return;
    _retryTimer?.cancel();
    _retryTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      _subscribeCore(force: true);
    });
  }

  void _unsubscribeCore() {
    _retryTimer?.cancel();
    final client = _client;
    if (client != null) {
      for (final channel in _channels) {
        client.removeChannel(channel);
      }
    }
    _channels.clear();
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
    _authSubscription?.cancel();
    _refreshDebounce?.cancel();
    _unsubscribeCore();
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
