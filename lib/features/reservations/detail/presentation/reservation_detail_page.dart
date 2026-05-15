import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentcar00_ops/features/reservations/detail/data/ims_reservation_client.dart';
import 'package:rentcar00_ops/features/reservations/detail/data/ims_reservation_payload.dart';
import 'package:rentcar00_ops/features/reservations/shared/providers/reservation_providers.dart';
import 'package:rentcar00_ops/shared/config/supabase_providers.dart';
import 'package:rentcar00_ops/shared/utils/contact_launcher.dart';

class ReservationDetailPage extends ConsumerWidget {
  const ReservationDetailPage({super.key, required this.reservationId});

  final String reservationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reservationAsync = ref.watch(
      reservationDetailProvider(reservationId),
    );

    return Scaffold(
      appBar: AppBar(title: Text('예약 상세 · $reservationId')),
      body: reservationAsync.when(
        data: (reservation) {
          if (reservation == null) {
            return const Center(child: Text('예약 정보를 찾을 수 없습니다.'));
          }
          return _ReservationDetailBody(reservationId: reservationId);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            Center(child: Text('예약 상세를 불러오지 못했습니다.\n$error')),
      ),
    );
  }
}

class _ReservationDetailBody extends ConsumerStatefulWidget {
  const _ReservationDetailBody({required this.reservationId});

  final String reservationId;

  @override
  ConsumerState<_ReservationDetailBody> createState() =>
      _ReservationDetailBodyState();
}

class _ReservationDetailBodyState
    extends ConsumerState<_ReservationDetailBody> {
  bool _imsSubmitting = false;

  Future<void> _submitImsReservation() async {
    if (_imsSubmitting) return;

    final reservation = ref
        .read(reservationDetailProvider(widget.reservationId))
        .valueOrNull;
    if (reservation == null) return;

    final buildResult = buildImsReservationPayload(reservation);
    if (!buildResult.isValid) {
      _showSnack(
        'IMS 예약실패(${buildResult.errors.map(imsPayloadErrorLabel).join(', ')})',
        backgroundColor: Colors.red.shade700,
      );
      return;
    }

    final appEnv = ref.read(appEnvProvider);
    setState(() => _imsSubmitting = true);

    try {
      final client = ImsReservationClient(baseUrl: appEnv.aiParserBaseUrl);
      final result = await client.createReservation(buildResult.payload);
      if (!mounted) return;

      if (result.isSuccess) {
        _showSnack(
          'IMS 예약성공(${reservation.carNumber}, ${_formatDateTime(reservation.startAt)})',
          backgroundColor: Colors.green.shade700,
        );
        return;
      }

      _showSnack(
        'IMS 예약실패(${result.message.isEmpty ? result.code : result.message})',
        backgroundColor: Colors.red.shade700,
      );
    } on ImsReservationClientException catch (error) {
      if (!mounted) return;
      _showSnack(
        'IMS 예약실패(${error.message})',
        backgroundColor: Colors.red.shade700,
      );
    } catch (error) {
      if (!mounted) return;
      _showSnack('IMS 예약실패($error)', backgroundColor: Colors.red.shade700);
    } finally {
      if (mounted) setState(() => _imsSubmitting = false);
    }
  }

  void _showSnack(String message, {required Color backgroundColor}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: backgroundColor),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reservationAsync = ref.watch(
      reservationDetailProvider(widget.reservationId),
    );
    final actionsAsync = ref.watch(
      reservationActionsProvider(widget.reservationId),
    );
    final logsAsync = ref.watch(actionLogsProvider(widget.reservationId));
    final outboxPreviewAsync = ref.watch(
      outboxPreviewProvider(widget.reservationId),
    );

    return reservationAsync.when(
      data: (reservation) {
        if (reservation == null) {
          return const Center(child: Text('예약 정보를 찾을 수 없습니다.'));
        }

        final actions = actionsAsync.valueOrNull ?? const [];
        final logs = logsAsync.valueOrNull ?? const [];
        final outboxPreview = outboxPreviewAsync.valueOrNull ?? const [];
        final hasPhone = hasCallablePhone(reservation.customerPhone);

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          children: [
            Text(
              reservation.customerName.isEmpty
                  ? '(고객명없음)'
                  : reservation.customerName,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              reservation.carNumber.isEmpty
                  ? '차량번호 미확인'
                  : reservation.carNumber,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                reservation.statusKey.isEmpty
                    ? reservation.tab.label
                    : '${reservation.tab.label} · ${reservation.statusKey}',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 14),
            _SectionCard(
              title: '기능',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (hasPhone)
                        FilledButton.tonalIcon(
                          onPressed: () => tryLaunchPhoneCall(
                            context,
                            reservation.customerPhone,
                          ),
                          icon: const Icon(Icons.call_outlined),
                          label: const Text('전화'),
                        ),
                      if (hasPhone)
                        FilledButton.tonalIcon(
                          onPressed: () =>
                              tryLaunchSms(context, reservation.customerPhone),
                          icon: const Icon(Icons.sms_outlined),
                          label: const Text('문자'),
                        ),
                      FilledButton.tonalIcon(
                        onPressed: _imsSubmitting
                            ? null
                            : _submitImsReservation,
                        icon: _imsSubmitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.cloud_upload_outlined),
                        label: const Text('IMS 예약추가'),
                      ),
                    ],
                  ),
                  if (actions.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    for (final action in actions)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: FilledButton.tonal(
                          onPressed: null,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(action.label),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            _SectionCard(
              title: '예약 정보',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DetailField(
                    label: '예약ID',
                    value: reservation.reservationId,
                    emphasize: true,
                  ),
                  _DetailField(
                    label: '외부예약번호',
                    value: reservation.reservationNumber,
                  ),
                  _DetailField(label: '차종', value: reservation.carName),
                  _DetailField(label: '소개처', value: reservation.referralSource),
                  _DetailField(label: '가격', value: reservation.paymentAmount),
                  _DetailField(
                    label: '생년월일',
                    value: reservation.customerBirthDate,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _SectionCard(
              title: '운행 정보',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DetailField(
                    label: '고객번호',
                    value: reservation.customerPhone,
                    emphasize: true,
                  ),
                  _DetailField(
                    label: '배차',
                    value: _formatDateTime(reservation.startAt),
                  ),
                  _DetailField(
                    label: '반납',
                    value: _formatDateTime(reservation.endAt),
                  ),
                  _DetailField(label: '위치', value: reservation.locationSummary),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (reservation.primaryBadges.isNotEmpty)
              _SectionCard(
                title: '체크 상태',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final badge in reservation.primaryBadges)
                      Chip(label: Text(badge)),
                    for (final entry in reservation.checkPayload.entries)
                      Chip(label: Text('${entry.key}: ${entry.value}')),
                  ],
                ),
              ),
            if (reservation.primaryBadges.isNotEmpty)
              const SizedBox(height: 14),
            if (logs.isNotEmpty)
              _SectionCard(
                title: '업무 로그',
                child: Column(
                  children: [
                    for (final log in logs)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(log.label),
                        subtitle: Text(
                          '${_formatDateTime(log.executedAt)} · ${log.note}',
                        ),
                      ),
                  ],
                ),
              ),
            if (logs.isNotEmpty) const SizedBox(height: 14),
            if (outboxPreview.isNotEmpty)
              _SectionCard(
                title: 'outbox dry-run',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [for (final line in outboxPreview) Text('• $line')],
                ),
              ),
            if (outboxPreview.isNotEmpty) const SizedBox(height: 14),
            _SectionCard(
              title: '메모',
              child: Text(_displayValue(reservation.noteText)),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) =>
          Center(child: Text('예약 정보를 불러오지 못했습니다.\n$error')),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _DetailField extends StatelessWidget {
  const _DetailField({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            _displayValue(value),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: (emphasize ? textTheme.titleMedium : textTheme.bodyLarge)
                ?.copyWith(
                  fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
                  height: 1.3,
                ),
          ),
        ],
      ),
    );
  }
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.month)}/${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
}

String _displayValue(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? '-' : trimmed;
}
