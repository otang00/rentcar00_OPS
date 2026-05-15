import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentcar00_ops/data/models/external_reservation_link.dart';
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
  bool _bindingUpdating = false;

  Future<void> _submitImsReservation() async {
    if (_imsSubmitting) return;

    final reservation = ref
        .read(reservationDetailProvider(widget.reservationId))
        .valueOrNull;
    if (reservation == null) return;

    final binding = ref
        .read(externalReservationLinkProvider(widget.reservationId))
        .valueOrNull;
    if (binding?.isActiveBinding == true) {
      _showSnack(
        '이미 IMS 예약과 연동되어 있습니다.',
        backgroundColor: Colors.orange.shade700,
      );
      return;
    }

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

  Future<void> _startImsBindingSelection() async {
    _showSnack(
      'IMS연동 목록 선택은 다음 단계에서 연결합니다.',
      backgroundColor: Colors.blueGrey.shade700,
    );
  }

  Future<void> _unlinkImsReservationBinding() async {
    if (_bindingUpdating) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('IMS 연동해제'),
          content: const Text(
            'IMS 예약은 삭제되지 않습니다.\n현재 OPS 예약과 IMS 예약의 연결만 해제할까요?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('연동해제'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() => _bindingUpdating = true);
    try {
      await ref
          .read(supabaseOpsRepositoryProvider)
          .markExternalReservationLinkUnlinked(
            reservationId: widget.reservationId,
          );
      ref.invalidate(externalReservationLinkProvider(widget.reservationId));
      if (!mounted) return;
      _showSnack('IMS 연동을 해제했습니다.', backgroundColor: Colors.green.shade700);
    } catch (error) {
      if (!mounted) return;
      _showSnack('IMS 연동해제 실패($error)', backgroundColor: Colors.red.shade700);
    } finally {
      if (mounted) setState(() => _bindingUpdating = false);
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
    final externalLinkAsync = ref.watch(
      externalReservationLinkProvider(widget.reservationId),
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
        final externalLink = externalLinkAsync.valueOrNull;
        final hasActiveImsBinding = externalLink?.isActiveBinding == true;

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
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 4,
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 6,
                    childAspectRatio: 1.05,
                    children: [
                      if (hasPhone)
                        _DetailActionButton(
                          label: '전화',
                          icon: Icons.call_outlined,
                          onPressed: () => tryLaunchPhoneCall(
                            context,
                            reservation.customerPhone,
                          ),
                        ),
                      if (hasPhone)
                        _DetailActionButton(
                          label: '문자',
                          icon: Icons.sms_outlined,
                          onPressed: () =>
                              tryLaunchSms(context, reservation.customerPhone),
                        ),
                      if (hasActiveImsBinding)
                        const _DetailActionButton(
                          label: 'IMS연동됨',
                          icon: Icons.link_outlined,
                          onPressed: null,
                        )
                      else ...[
                        _DetailActionButton(
                          label: 'IMS추가',
                          icon: Icons.cloud_upload_outlined,
                          emphasis: true,
                          loading: _imsSubmitting,
                          onPressed: _imsSubmitting
                              ? null
                              : _submitImsReservation,
                        ),
                        _DetailActionButton(
                          label: 'IMS연동',
                          icon: Icons.add_link_outlined,
                          onPressed: _startImsBindingSelection,
                        ),
                      ],
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
              title: 'IMS 연동 정보',
              child: _ImsBindingInfo(
                link: externalLink,
                isLoading: externalLinkAsync.isLoading,
                isUpdating: _bindingUpdating,
                onCreate: hasActiveImsBinding || _imsSubmitting
                    ? null
                    : _submitImsReservation,
                onBind: hasActiveImsBinding ? null : _startImsBindingSelection,
                onUnlink: hasActiveImsBinding && !_bindingUpdating
                    ? _unlinkImsReservationBinding
                    : null,
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

class _ImsBindingInfo extends StatelessWidget {
  const _ImsBindingInfo({
    required this.link,
    required this.isLoading,
    required this.isUpdating,
    required this.onCreate,
    required this.onBind,
    required this.onUnlink,
  });

  final ExternalReservationLink? link;
  final bool isLoading;
  final bool isUpdating;
  final VoidCallback? onCreate;
  final VoidCallback? onBind;
  final VoidCallback? onUnlink;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final active = link?.isActiveBinding == true;
    final failed = link?.isFailed == true;
    final unlinked = link?.isUnlinked == true;
    final deleted = link?.isDeleted == true;
    final statusLabel = active
        ? '연동됨'
        : failed
        ? '연동 실패'
        : unlinked
        ? '해제됨'
        : deleted
        ? '삭제됨'
        : '미연동';
    final statusColor = active
        ? Colors.green.shade700
        : failed
        ? Colors.red.shade700
        : Colors.blueGrey.shade700;

    if (isLoading && link == null) {
      return const Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 10),
          Text('IMS 연동 상태 확인 중'),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: statusColor.withValues(alpha: 0.35)),
          ),
          child: Text(
            '상태: $statusLabel',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: statusColor,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (active) ...[
          _DetailField(
            label: 'IMS ID',
            value: link?.externalReservationId ?? '',
            emphasize: true,
          ),
          _DetailField(label: 'detail ID', value: link?.externalDetailId ?? ''),
          _DetailField(label: '연동키', value: link?.linkKey ?? ''),
          _DetailField(
            label: '마지막 확인시각',
            value: _formatOptionalDateTime(link?.lastCheckedAt),
          ),
          if ((link?.errorText ?? '').trim().isNotEmpty)
            _DetailField(label: '오류', value: link?.errorText ?? ''),
          const Text('IMS 예약은 삭제되지 않고, OPS 예약과의 연결만 해제됩니다.'),
          const SizedBox(height: 10),
          FilledButton.tonalIcon(
            onPressed: isUpdating ? null : onUnlink,
            icon: isUpdating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.link_off_outlined),
            label: const Text('연동해제'),
          ),
        ] else ...[
          Text(
            failed
                ? 'IMS 예약 바인딩에 실패했습니다. IMS 예약을 새로 추가하거나 기존 IMS 예약과 연동할 수 있습니다.'
                : 'IMS 예약을 새로 추가하거나 기존 IMS 예약과 연동할 수 있습니다.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          if ((link?.errorText ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            _DetailField(label: '오류', value: link?.errorText ?? ''),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.cloud_upload_outlined),
                label: const Text('IMS추가'),
              ),
              FilledButton.tonalIcon(
                onPressed: onBind,
                icon: const Icon(Icons.add_link_outlined),
                label: const Text('IMS연동'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _DetailActionButton extends StatelessWidget {
  const _DetailActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.emphasis = false,
    this.loading = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool emphasis;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = emphasis ? colorScheme.onPrimary : colorScheme.primary;
    final background = emphasis ? colorScheme.primary : const Color(0xFFEAF5FF);
    final borderColor = emphasis
        ? colorScheme.primary
        : const Color(0xFFBBDEFB);

    return SizedBox.expand(
      child: FilledButton.tonal(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          disabledBackgroundColor: colorScheme.surfaceContainerHighest,
          disabledForegroundColor: colorScheme.onSurfaceVariant,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          minimumSize: const Size(0, 0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: borderColor),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              SizedBox(
                width: 21,
                height: 21,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: foreground,
                ),
              )
            else
              Icon(icon, size: 21),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: foreground,
                fontSize: 12,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
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

String _formatOptionalDateTime(DateTime? value) {
  if (value == null) return '';
  return _formatDateTime(value);
}

String _displayValue(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? '-' : trimmed;
}
