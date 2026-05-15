import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentcar00_ops/features/auth/shared/auth_providers.dart';

class StaffAccessGate extends ConsumerWidget {
  const StaffAccessGate({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffAccountAsync = ref.watch(currentStaffAccountProvider);

    return staffAccountAsync.when(
      data: (staffAccount) {
        if (staffAccount == null) {
          return const _SessionRejectedPage(message: '승인되지 않은 계정입니다.');
        }

        if (!staffAccount.isActive) {
          return const _SessionRejectedPage(message: '비활성화된 계정입니다.');
        }

        return child;
      },
      loading: () => const _GateLoadingPage(),
      error: (error, stackTrace) => _GateErrorPage(
        message: '계정 확인 중 오류가 발생했습니다.',
        onRetry: () => ref.invalidate(currentStaffAccountProvider),
      ),
    );
  }
}

class _SessionRejectedPage extends ConsumerStatefulWidget {
  const _SessionRejectedPage({required this.message});

  final String message;

  @override
  ConsumerState<_SessionRejectedPage> createState() =>
      _SessionRejectedPageState();
}

class _SessionRejectedPageState extends ConsumerState<_SessionRejectedPage> {
  bool _handled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_handled) {
      return;
    }

    _handled = true;
    Future.microtask(() async {
      await ref
          .read(authControllerProvider)
          .rejectCurrentSession(widget.message);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const _GateLoadingPage();
  }
}

class _GateLoadingPage extends StatelessWidget {
  const _GateLoadingPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _GateErrorPage extends StatelessWidget {
  const _GateErrorPage({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: onRetry, child: const Text('다시 시도')),
            ],
          ),
        ),
      ),
    );
  }
}
