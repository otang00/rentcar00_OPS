import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:rentcar00_ops/data/models/reservation_record.dart';
import 'package:rentcar00_ops/data/models/external_reservation_link.dart';
import 'package:rentcar00_ops/data/models/status_board_record.dart';
import 'package:rentcar00_ops/features/reservations/detail/data/ims_reservation_client.dart';
import 'package:rentcar00_ops/features/reservations/detail/data/ims_reservation_payload.dart';
import 'package:rentcar00_ops/features/reservations/shared/domain/reservation_tab.dart';
import 'package:rentcar00_ops/features/reservations/shared/providers/reservation_providers.dart';
import 'package:rentcar00_ops/shared/config/supabase_providers.dart';
import 'package:rentcar00_ops/shared/input/ops_input_formatters.dart';
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
  bool _registrationUpdating = false;
  bool _reservationUpdating = false;
  bool _lifecycleUpdating = false;

  Future<void> _editReservation(ReservationRecord reservation) async {
    if (_reservationUpdating) return;

    final form = await showDialog<_ReservationEditResult>(
      context: context,
      builder: (context) => _ReservationEditDialog(reservation: reservation),
    );
    if (form == null) return;

    setState(() => _reservationUpdating = true);
    try {
      await ref
          .read(supabaseOpsRepositoryProvider)
          .updateReservationAndLinkedSchedules(
            reservationId: reservation.reservationId,
            reservationNumber: form.reservationNumber,
            customerName: form.customerName,
            customerPhone: form.customerPhone,
            customerBirthDate: form.customerBirthDate,
            referralSource: form.referralSource,
            paymentAmount: form.paymentAmount,
            startAt: form.startAt,
            endAt: form.endAt,
            pickupLocation: form.pickupLocation,
            dropoffLocation: form.dropoffLocation,
            noteText: form.noteText,
          );
      ref.invalidate(allReservationsProvider);
      ref.invalidate(allStatusBoardRecordsProvider);
      ref.invalidate(
        externalReservationLinkProvider(reservation.reservationId),
      );
      if (!mounted) return;
      _showSnack('예약 정보를 수정했습니다.', backgroundColor: Colors.green.shade700);
    } catch (error) {
      if (!mounted) return;
      _showSnack('예약 수정 실패($error)', backgroundColor: Colors.red.shade700);
    } finally {
      if (mounted) setState(() => _reservationUpdating = false);
    }
  }

  Future<void> _changeVehicle(
    ReservationRecord reservation,
    ExternalReservationLink? externalLink,
  ) async {
    if (_reservationUpdating) return;

    final cars = ref
        .read(allStatusBoardRecordsProvider)
        .valueOrNull
        ?.where(
          (item) =>
              item.sourceKind == 'car' && item.carNumber.trim().isNotEmpty,
        )
        .toList();
    if (cars == null || cars.isEmpty) {
      _showSnack('차량 목록을 아직 불러오지 못했습니다.', backgroundColor: Colors.red.shade700);
      return;
    }

    final selectedCar = await showDialog<StatusBoardRecord>(
      context: context,
      builder: (context) => _VehicleChangeDialog(
        cars: cars,
        currentCarNumber: reservation.carNumber,
      ),
    );
    if (selectedCar == null || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('차량변경'),
        content: Text(
          '${reservation.carNumber} → ${selectedCar.carNumber} 차량 변경하시겠습니까?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('변경'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _reservationUpdating = true);
    try {
      final overlaps = await ref
          .read(supabaseOpsRepositoryProvider)
          .fetchReservationVehicleOverlaps(
            reservationId: reservation.reservationId,
            carNumber: selectedCar.carNumber,
            startAt: reservation.startAt,
            endAt: reservation.endAt,
          );
      if (overlaps.isNotEmpty) {
        final first = overlaps.first;
        if (!mounted) return;
        _showSnack(
          '차량변경 실패: ${selectedCar.carNumber} 예약시간 중복(${first['reservation_id'] ?? ''})',
          backgroundColor: Colors.red.shade700,
        );
        return;
      }

      if (externalLink?.isActiveBinding == true) {
        final scheduleId = externalLink!.externalReservationId.trim();
        if (scheduleId.isEmpty) {
          if (!mounted) return;
          _showSnack(
            'IMS schedule_id가 없어 차량변경을 중단했습니다.',
            backgroundColor: Colors.red.shade700,
          );
          return;
        }

        final buildResult = buildImsReservationPayload(reservation);
        final targetPayload = ImsReservationPayload(
          rentalAt: buildResult.payload.rentalAt,
          returnAt: buildResult.payload.returnAt,
          carNumber: selectedCar.carNumber,
          totalFee: buildResult.payload.totalFee,
          customerName: buildResult.payload.customerName,
          customerPhone: buildResult.payload.customerPhone,
          address: buildResult.payload.address,
          useDelivery: buildResult.payload.useDelivery,
          memo: buildResult.payload.memo,
          reservationId: buildResult.payload.reservationId,
        );

        try {
          final appEnv = ref.read(appEnvProvider);
          final client = ImsReservationClient(baseUrl: appEnv.aiParserBaseUrl);
          final imsResult = await client.changeReservationCar(
            payload: targetPayload,
            scheduleId: scheduleId,
          );
          if (!imsResult.hasLinkedExternalId) {
            throw ImsReservationClientException(
              imsResult.message.isEmpty ? imsResult.code : imsResult.message,
            );
          }
          await ref
              .read(supabaseOpsRepositoryProvider)
              .upsertExternalReservationLink(
                reservationId: reservation.reservationId,
                externalReservationId: imsResult.externalReservationId,
                externalDetailId: externalLink.externalDetailId,
                externalStatus: 'linked',
                linkKey: imsResult.linkKey.trim().isEmpty
                    ? externalLink.linkKey
                    : imsResult.linkKey.trim(),
                lastPayloadJson: targetPayload.toJson(),
                lastResultJson: imsResult.resultJson,
                errorText: null,
              );
        } catch (error) {
          if (!mounted) return;
          final decision = await showDialog<_ImsChangeFailureDecision>(
            context: context,
            builder: (context) => _ImsChangeFailureDialog(message: '$error'),
          );
          if (decision != _ImsChangeFailureDecision.unlinkAndChange) {
            return;
          }
          await ref
              .read(supabaseOpsRepositoryProvider)
              .markExternalReservationLinkUnlinked(
                reservationId: reservation.reservationId,
              );
        }
      }

      await ref
          .read(supabaseOpsRepositoryProvider)
          .changeReservationVehicle(
            reservationId: reservation.reservationId,
            carNumber: selectedCar.carNumber,
            carName: selectedCar.carName,
          );
      ref.invalidate(allReservationsProvider);
      ref.invalidate(allStatusBoardRecordsProvider);
      if (!mounted) return;
      _showSnack(
        '차량을 ${selectedCar.carNumber}로 변경했습니다.',
        backgroundColor: Colors.green.shade700,
      );
    } catch (error) {
      if (!mounted) return;
      _showSnack('차량변경 실패($error)', backgroundColor: Colors.red.shade700);
    } finally {
      if (mounted) setState(() => _reservationUpdating = false);
    }
  }

  Future<void> _completeReservationLifecycle({
    required ReservationRecord reservation,
    required List<StatusBoardRecord> linkedSchedules,
    required String scheduleType,
    required ExternalReservationLink? externalLink,
  }) async {
    if (_lifecycleUpdating) return;

    final normalizedType = scheduleType.trim();
    StatusBoardRecord? target;
    for (final item in linkedSchedules) {
      if (item.scheduleType.trim() == normalizedType &&
          !_isTruthy(item.scheduleDone)) {
        target = item;
        break;
      }
    }

    if (target == null) {
      _showSnack(
        '완료 처리할 $normalizedType 일정이 없습니다.',
        backgroundColor: Colors.red.shade700,
      );
      return;
    }

    final scheduleRowId = _extractRawRowId(target.recordId, 'schedule');
    if (scheduleRowId == null) {
      _showSnack('일정 row id를 찾지 못했습니다.', backgroundColor: Colors.red.shade700);
      return;
    }

    final isReturn = normalizedType == '반납';
    final imsActive = isReturn && externalLink?.isActiveBinding == true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isReturn ? '반납완료' : '배차완료'),
        content: Text(
          isReturn
              ? '연결된 반납 일정을 완료 처리하고 차량을 대기중으로 전환합니다.${imsActive ? '\n\nIMS 연결 예약도 확인합니다.' : ''}'
              : '연결된 배차 일정을 완료 처리하고 차량을 일반 상태로 전환합니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('완료'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _lifecycleUpdating = true);
    try {
      await ref
          .read(supabaseOpsRepositoryProvider)
          .completeSchedule(
            scheduleRowId: scheduleRowId,
            scheduleType: target.scheduleType,
            reservationId: reservation.reservationId,
            carNumber: target.carNumber.trim().isEmpty
                ? reservation.carNumber
                : target.carNumber,
          );

      var imsMessage = '';
      var imsSucceeded = false;
      if (imsActive) {
        final contractId = _resolveImsReturnContractId(externalLink);
        if (contractId.isEmpty) {
          imsMessage = ' IMS 반납완료는 실패했습니다(IMS 계약 ID 없음).';
        } else {
          try {
            final appEnv = ref.read(appEnvProvider);
            final imsResult =
                await ImsReservationClient(
                  baseUrl: appEnv.aiParserBaseUrl,
                ).completeReservationReturn(
                  contractId: contractId,
                  reservationId: reservation.reservationId,
                  doneAt: DateTime.now(),
                );
            imsSucceeded = imsResult.isSuccess;
            imsMessage = imsSucceeded
                ? ' IMS도 반납완료 처리했습니다.'
                : ' IMS 반납완료는 실패했습니다(${imsResult.message.isEmpty ? imsResult.code : imsResult.message}).';
          } catch (error) {
            imsMessage = ' IMS 반납완료는 실패했습니다($error).';
          }
        }
      }

      ref.invalidate(allReservationsProvider);
      ref.invalidate(allStatusBoardRecordsProvider);
      ref.invalidate(reservationDetailProvider(widget.reservationId));
      ref.invalidate(externalReservationLinkProvider(widget.reservationId));

      if (!mounted) return;
      _showSnack(
        '${isReturn ? '반납완료' : '배차완료'} 처리했습니다.$imsMessage',
        backgroundColor: imsActive && !imsSucceeded
            ? Colors.orange.shade800
            : Colors.green.shade700,
      );
    } catch (error) {
      if (!mounted) return;
      _showSnack(
        '${isReturn ? '반납완료' : '배차완료'} 실패($error)',
        backgroundColor: Colors.red.shade700,
      );
    } finally {
      if (mounted) setState(() => _lifecycleUpdating = false);
    }
  }

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
        '이미 IMS 예약이 등록되어 있습니다.',
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
      final result = await _runWithImsProgress(() async {
        final client = ImsReservationClient(baseUrl: appEnv.aiParserBaseUrl);
        return client.createReservation(buildResult.payload);
      });
      await _saveImsRegistrationResult(
        payload: buildResult.payload,
        result: result,
      );
      ref.invalidate(externalReservationLinkProvider(widget.reservationId));
      if (!mounted) return;

      if (result.hasLinkedExternalId) {
        _showSnack(
          'IMS 등록완료(${reservation.carNumber}, ${_formatDateTime(reservation.startAt)})',
          backgroundColor: Colors.green.shade700,
        );
        return;
      }

      _showSnack(
        'IMS 예약실패(${result.message.isEmpty ? result.code : result.message})',
        backgroundColor: Colors.red.shade700,
      );
    } on ImsReservationClientException catch (error) {
      await _saveImsRegistrationFailure(
        payload: buildResult.payload,
        errorText: error.message,
      );
      ref.invalidate(externalReservationLinkProvider(widget.reservationId));
      if (!mounted) return;
      _showSnack(
        'IMS 예약실패(${error.message})',
        backgroundColor: Colors.red.shade700,
      );
    } catch (error) {
      await _saveImsRegistrationFailure(
        payload: buildResult.payload,
        errorText: '$error',
      );
      ref.invalidate(externalReservationLinkProvider(widget.reservationId));
      if (!mounted) return;
      _showSnack('IMS 예약실패($error)', backgroundColor: Colors.red.shade700);
    } finally {
      if (mounted) setState(() => _imsSubmitting = false);
    }
  }

  Future<T> _runWithImsProgress<T>(Future<T> Function() task) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('IMS 등록 진행중'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              LinearProgressIndicator(),
              SizedBox(height: 16),
              Text('IMS에 예약을 생성하고 등록 정보를 확인하는 중입니다.'),
              SizedBox(height: 6),
              Text('완료 전까지 다른 동작을 하지 마세요.'),
            ],
          ),
        ),
      ),
    );

    try {
      return await task();
    } finally {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    }
  }

  Future<void> _saveImsRegistrationResult({
    required ImsReservationPayload payload,
    required ImsReservationExecutionResult result,
  }) async {
    final linked = result.hasLinkedExternalId;
    final errorText = linked
        ? null
        : (result.errorText.trim().isNotEmpty
              ? result.errorText.trim()
              : (result.message.trim().isNotEmpty
                    ? result.message.trim()
                    : result.code));
    await ref
        .read(supabaseOpsRepositoryProvider)
        .upsertExternalReservationLink(
          reservationId: widget.reservationId,
          externalReservationId: result.externalReservationId,
          externalDetailId: result.externalDetailId,
          externalStatus: linked ? 'linked' : 'failed',
          linkKey: result.linkKey.trim().isEmpty
              ? 'OPS:${widget.reservationId.trim()}'
              : result.linkKey.trim(),
          lastPayloadJson: payload.toJson(),
          lastResultJson: result.resultJson,
          errorText: errorText,
        );
  }

  Future<void> _saveImsRegistrationFailure({
    required ImsReservationPayload payload,
    required String errorText,
  }) async {
    await ref
        .read(supabaseOpsRepositoryProvider)
        .upsertExternalReservationLink(
          reservationId: widget.reservationId,
          externalStatus: 'failed',
          linkKey: 'OPS:${widget.reservationId.trim()}',
          lastPayloadJson: payload.toJson(),
          lastResultJson: {'error': errorText},
          errorText: errorText,
        );
  }

  Future<void> _clearImsReservationRegistration() async {
    if (_registrationUpdating) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('IMS 등록해제'),
          content: const Text('IMS 예약은 삭제되지 않습니다.\nOPS에 저장된 IMS 등록 정보만 해제할까요?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('등록해제'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() => _registrationUpdating = true);
    try {
      await ref
          .read(supabaseOpsRepositoryProvider)
          .markExternalReservationLinkUnlinked(
            reservationId: widget.reservationId,
          );
      ref.invalidate(externalReservationLinkProvider(widget.reservationId));
      if (!mounted) return;
      _showSnack('IMS 등록 정보를 해제했습니다.', backgroundColor: Colors.green.shade700);
    } catch (error) {
      if (!mounted) return;
      _showSnack('IMS 등록해제 실패($error)', backgroundColor: Colors.red.shade700);
    } finally {
      if (mounted) setState(() => _registrationUpdating = false);
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
    final linkedSchedulesAsync = ref
        .watch(allStatusBoardRecordsProvider)
        .whenData((items) {
          final schedules = items
              .where(
                (item) =>
                    item.isScheduleEntry &&
                    item.reservationId.trim() == widget.reservationId.trim(),
              )
              .toList();
          schedules.sort((a, b) {
            final aTime = a.sortAt ?? DateTime(2999);
            final bTime = b.sortAt ?? DateTime(2999);
            return aTime.compareTo(bTime);
          });
          return schedules;
        });

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
        final hasActiveImsRegistration = externalLink?.isActiveBinding == true;
        final linkedSchedules =
            linkedSchedulesAsync.valueOrNull ?? const <StatusBoardRecord>[];
        final pickupPending = linkedSchedules.any(
          (item) =>
              item.scheduleType.trim() == '배차' && !_isTruthy(item.scheduleDone),
        );
        final returnPending = linkedSchedules.any(
          (item) =>
              item.scheduleType.trim() == '반납' && !_isTruthy(item.scheduleDone),
        );
        final isCompleted =
            reservation.statusKey.trim() == '완료' ||
            reservation.tab == ReservationTab.completed;
        final isDispatched =
            reservation.statusKey.trim() == '배차중' ||
            reservation.tab == ReservationTab.inUse;
        final showPickupComplete =
            !isCompleted && !isDispatched && pickupPending;
        final showReturnComplete =
            !isCompleted && isDispatched && returnPending;

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
                      _DetailActionButton(
                        label: '수정',
                        icon: Icons.edit_outlined,
                        loading: _reservationUpdating,
                        emphasis: true,
                        onPressed: _reservationUpdating
                            ? null
                            : () => _editReservation(reservation),
                      ),
                      _DetailActionButton(
                        label: '차량변경',
                        icon: Icons.directions_car_filled_outlined,
                        loading: _reservationUpdating,
                        onPressed: _reservationUpdating
                            ? null
                            : () => _changeVehicle(reservation, externalLink),
                      ),
                      if (showPickupComplete)
                        _DetailActionButton(
                          label: '배차완료',
                          icon: Icons.upload_rounded,
                          loading: _lifecycleUpdating,
                          emphasis: true,
                          onPressed: _lifecycleUpdating
                              ? null
                              : () => _completeReservationLifecycle(
                                  reservation: reservation,
                                  linkedSchedules: linkedSchedules,
                                  scheduleType: '배차',
                                  externalLink: externalLink,
                                ),
                        ),
                      if (showReturnComplete)
                        _DetailActionButton(
                          label: '반납완료',
                          icon: Icons.assignment_turned_in_outlined,
                          loading: _lifecycleUpdating,
                          emphasis: true,
                          onPressed: _lifecycleUpdating
                              ? null
                              : () => _completeReservationLifecycle(
                                  reservation: reservation,
                                  linkedSchedules: linkedSchedules,
                                  scheduleType: '반납',
                                  externalLink: externalLink,
                                ),
                        ),
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
                      if (hasActiveImsRegistration)
                        const _DetailActionButton(
                          label: 'IMS등록됨',
                          icon: Icons.link_outlined,
                          onPressed: null,
                        )
                      else
                        _DetailActionButton(
                          label: 'IMS추가',
                          icon: Icons.cloud_upload_outlined,
                          emphasis: true,
                          loading: _imsSubmitting,
                          onPressed: _imsSubmitting
                              ? null
                              : _submitImsReservation,
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
              title: '연결된 일정',
              child: _LinkedSchedulesList(schedulesAsync: linkedSchedulesAsync),
            ),
            const SizedBox(height: 14),
            _SectionCard(
              title: 'IMS 등록 정보',
              child: _ImsRegistrationInfo(
                link: externalLink,
                isLoading: externalLinkAsync.isLoading,
                isUpdating: _registrationUpdating,
                onCreate: hasActiveImsRegistration || _imsSubmitting
                    ? null
                    : _submitImsReservation,
                onUnlink: hasActiveImsRegistration && !_registrationUpdating
                    ? _clearImsReservationRegistration
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
                  _DetailField(
                    label: '가격',
                    value: _formatWon(reservation.paymentAmount),
                  ),
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
                  _DetailField(
                    label: '배차지',
                    value: reservation.locationSummary,
                  ),
                  _DetailField(
                    label: '반납지',
                    value: reservation.dropoffLocation,
                  ),
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
              child: Text(_displayValue(reservation.rawNoteText)),
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

enum _ImsChangeFailureDecision { unlinkAndChange, cancel }

class _ImsChangeFailureDialog extends StatelessWidget {
  const _ImsChangeFailureDialog({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('IMS 차량변경 실패'),
      content: Text('IMS 변경에 실패했습니다.\n\n$message\n\n연동을 끊고 원장만 변경할까요?'),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(_ImsChangeFailureDecision.cancel),
          child: const Text('변경취소'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(
            context,
          ).pop(_ImsChangeFailureDecision.unlinkAndChange),
          child: const Text('연동 끊고 원장만 변경'),
        ),
      ],
    );
  }
}

class _VehicleChangeDialog extends StatefulWidget {
  const _VehicleChangeDialog({
    required this.cars,
    required this.currentCarNumber,
  });

  final List<StatusBoardRecord> cars;
  final String currentCarNumber;

  @override
  State<_VehicleChangeDialog> createState() => _VehicleChangeDialogState();
}

class _VehicleChangeDialogState extends State<_VehicleChangeDialog> {
  late final TextEditingController _searchController;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final normalizedCurrent = widget.currentCarNumber.trim();
    final query = _query.trim().toLowerCase();
    final cars = widget.cars.where((car) {
      if (car.carNumber.trim() == normalizedCurrent) return false;
      if (query.isEmpty) return true;
      return car.carNumber.toLowerCase().contains(query) ||
          car.carName.toLowerCase().contains(query) ||
          car.parkingLocation.toLowerCase().contains(query);
    }).toList();

    return AlertDialog(
      title: const Text('차량변경'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '차량검색',
                hintText: '차량번호/차종/주차지',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: cars.isEmpty
                  ? const Center(child: Text('선택 가능한 차량이 없습니다.'))
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: cars.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final car = cars[index];
                        return ListTile(
                          leading: const Icon(Icons.directions_car_outlined),
                          title: Text(
                            car.carNumber,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            [car.carName, car.parkingLocation]
                                .where((value) => value.trim().isNotEmpty)
                                .join(' · '),
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => Navigator.of(context).pop(car),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
      ],
    );
  }
}

class _ImsRegistrationInfo extends StatelessWidget {
  const _ImsRegistrationInfo({
    required this.link,
    required this.isLoading,
    required this.isUpdating,
    required this.onCreate,
    required this.onUnlink,
  });

  final ExternalReservationLink? link;
  final bool isLoading;
  final bool isUpdating;
  final VoidCallback? onCreate;
  final VoidCallback? onUnlink;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final active = link?.isActiveBinding == true;
    final failed = link?.isFailed == true;
    final unlinked = link?.isUnlinked == true;
    final deleted = link?.isDeleted == true;
    final statusLabel = active
        ? 'IMS등록됨'
        : failed
        ? '등록실패'
        : unlinked
        ? '등록해제'
        : deleted
        ? '삭제됨'
        : '미등록';
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
          Text('IMS 등록 상태 확인 중'),
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
          _DetailField(label: '등록키', value: link?.linkKey ?? ''),
          _DetailField(
            label: '마지막 등록/확인시각',
            value: _formatOptionalDateTime(link?.lastCheckedAt),
          ),
          if ((link?.errorText ?? '').trim().isNotEmpty)
            _DetailField(label: '오류', value: link?.errorText ?? ''),
          const Text('IMS 예약은 삭제되지 않고, OPS에 저장된 등록 정보만 해제됩니다.'),
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
            label: const Text('등록해제'),
          ),
        ] else ...[
          Text(
            failed
                ? 'IMS 예약 등록에 실패했습니다. IMS 예약을 새로 추가할 수 있습니다.'
                : 'IMS 예약을 새로 추가할 수 있습니다.',
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
            ],
          ),
        ],
      ],
    );
  }
}

class _LinkedSchedulesList extends StatelessWidget {
  const _LinkedSchedulesList({required this.schedulesAsync});

  final AsyncValue<List<StatusBoardRecord>> schedulesAsync;

  @override
  Widget build(BuildContext context) {
    return schedulesAsync.when(
      data: (items) {
        if (items.isEmpty) {
          return const Text('연결된 일정이 없습니다.');
        }
        return Column(
          children: [
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _LinkedScheduleCard(item: item),
              ),
          ],
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (error, stack) => Text('연결 일정을 불러오지 못했습니다.\n$error'),
    );
  }
}

class _LinkedScheduleCard extends StatelessWidget {
  const _LinkedScheduleCard({required this.item});

  final StatusBoardRecord item;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDone = _isTruthy(item.scheduleDone);
    final type = item.scheduleType.trim().isEmpty ? '일정' : item.scheduleType;
    final when = item.sortAt == null
        ? item.timeLabel
        : _formatLinkedScheduleDateTime(item.sortAt!);
    final location = item.locationSummary.trim().isNotEmpty
        ? item.locationSummary
        : item.pickupLocation;

    return Material(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push('/schedule/${item.recordId}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _scheduleTypeColor(type).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  type == '반납'
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded,
                  color: _scheduleTypeColor(type),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          type,
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (isDone)
                          Text(
                            '완료',
                            style: textTheme.labelSmall?.copyWith(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      when,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      _displayValue(location),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

Color _scheduleTypeColor(String type) {
  return type.trim() == '반납'
      ? const Color(0xFFD32F2F)
      : const Color(0xFF1976D2);
}

class _ReservationEditResult {
  const _ReservationEditResult({
    required this.reservationNumber,
    required this.customerName,
    required this.customerPhone,
    required this.customerBirthDate,
    required this.referralSource,
    required this.paymentAmount,
    required this.startAt,
    required this.endAt,
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.noteText,
  });

  final String reservationNumber;
  final String customerName;
  final String customerPhone;
  final String customerBirthDate;
  final String referralSource;
  final String paymentAmount;
  final DateTime startAt;
  final DateTime endAt;
  final String pickupLocation;
  final String dropoffLocation;
  final String noteText;
}

class _ReservationEditDialog extends StatefulWidget {
  const _ReservationEditDialog({required this.reservation});

  final ReservationRecord reservation;

  @override
  State<_ReservationEditDialog> createState() => _ReservationEditDialogState();
}

class _ReservationEditDialogState extends State<_ReservationEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _reservationNumberController;
  late final TextEditingController _customerNameController;
  late final TextEditingController _customerPhoneController;
  late final TextEditingController _customerBirthDateController;
  late final TextEditingController _referralSourceController;
  late final TextEditingController _paymentAmountController;
  late final TextEditingController _startAtController;
  late final TextEditingController _endAtController;
  late final TextEditingController _pickupLocationController;
  late final TextEditingController _dropoffLocationController;
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    final reservation = widget.reservation;
    _reservationNumberController = TextEditingController(
      text: reservation.reservationNumber,
    );
    _customerNameController = TextEditingController(
      text: reservation.customerName,
    );
    _customerPhoneController = TextEditingController(
      text: opsFormatPhoneInput(reservation.customerPhone),
    );
    _customerBirthDateController = TextEditingController(
      text: opsFormatBirthDateInput(reservation.customerBirthDate),
    );
    _referralSourceController = TextEditingController(
      text: reservation.referralSource,
    );
    _paymentAmountController = TextEditingController(
      text: reservation.paymentAmount,
    );
    _startAtController = TextEditingController(
      text: _formatEditorDateTime(reservation.startAt),
    );
    _endAtController = TextEditingController(
      text: _formatEditorDateTime(reservation.endAt),
    );
    _pickupLocationController = TextEditingController(
      text: reservation.locationSummary,
    );
    _dropoffLocationController = TextEditingController(
      text: reservation.dropoffLocation,
    );
    _noteController = TextEditingController(text: reservation.rawNoteText);
  }

  @override
  void dispose() {
    _reservationNumberController.dispose();
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _customerBirthDateController.dispose();
    _referralSourceController.dispose();
    _paymentAmountController.dispose();
    _startAtController.dispose();
    _endAtController.dispose();
    _pickupLocationController.dispose();
    _dropoffLocationController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime(TextEditingController controller) async {
    final now = DateTime.now();
    final initial = _tryParseEditorDateTime(controller.text.trim()) ?? now;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 5),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (pickedTime == null || !mounted) return;

    controller.text = _formatEditorDateTime(
      DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reservation = widget.reservation;
    return AlertDialog(
      title: const Text('예약 수정'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ReservationEditTextField(
                    controller: _reservationNumberController,
                    label: '외부예약번호',
                  ),
                  _ReservationEditTextField(
                    controller: _customerNameController,
                    label: '고객명',
                    validator: _requiredValidator,
                  ),
                  _ReservationEditTextField(
                    controller: _customerPhoneController,
                    label: '고객번호',
                    keyboardType: TextInputType.phone,
                    inputFormatters: [OpsPhoneInputFormatter()],
                    validator: _phoneValidator,
                  ),
                  _ReservationEditTextField(
                    controller: _customerBirthDateController,
                    label: '생년월일',
                    hintText: '1984-11-15',
                    keyboardType: TextInputType.number,
                    inputFormatters: [OpsBirthDateInputFormatter()],
                    validator: _birthDateValidator,
                  ),
                  _ReservationEditTextField(
                    controller: _referralSourceController,
                    label: '소개처',
                  ),
                  _ReservationEditTextField(
                    controller: _paymentAmountController,
                    label: '가격',
                    hintText: '100000',
                    validator: _positiveMoneyValidator,
                  ),
                  _ReservationEditTextField(
                    controller: _startAtController,
                    label: '배차일시',
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      OpsDateTimeInputFormatter(
                        defaultYear: reservation.startAt.year,
                      ),
                    ],
                    validator: _dateTimeValidator,
                    suffixIcon: IconButton(
                      onPressed: () => _pickDateTime(_startAtController),
                      icon: const Icon(Icons.calendar_today_outlined),
                    ),
                  ),
                  _ReservationEditTextField(
                    controller: _endAtController,
                    label: '반납일시',
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      OpsDateTimeInputFormatter(
                        defaultYear: reservation.endAt.year,
                      ),
                    ],
                    validator: _dateTimeValidator,
                    suffixIcon: IconButton(
                      onPressed: () => _pickDateTime(_endAtController),
                      icon: const Icon(Icons.calendar_today_outlined),
                    ),
                  ),
                  _ReservationEditTextField(
                    controller: _pickupLocationController,
                    label: '배차지',
                  ),
                  _ReservationEditTextField(
                    controller: _dropoffLocationController,
                    label: '반납지',
                    validator: _requiredValidator,
                  ),
                  _ReservationEditTextField(
                    controller: _noteController,
                    label: '메모',
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            final startAt = _tryParseEditorDateTime(
              _startAtController.text.trim(),
              fallback: widget.reservation.startAt,
            );
            final endAt = _tryParseEditorDateTime(
              _endAtController.text.trim(),
              fallback: widget.reservation.endAt,
            );
            if (startAt == null || endAt == null) return;
            if (!endAt.isAfter(startAt)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('반납일시는 배차일시 이후여야 합니다.')),
              );
              return;
            }
            _startAtController.text = _formatEditorDateTime(startAt);
            _endAtController.text = _formatEditorDateTime(endAt);
            Navigator.of(context).pop(
              _ReservationEditResult(
                reservationNumber: _reservationNumberController.text.trim(),
                customerName: _customerNameController.text.trim(),
                customerPhone: opsNormalizePhoneForStorage(
                  _customerPhoneController.text,
                ),
                customerBirthDate: opsNormalizeBirthDateForStorage(
                  _customerBirthDateController.text,
                ),
                referralSource: _referralSourceController.text.trim(),
                paymentAmount: _normalizeMoneyForStorage(
                  _paymentAmountController.text,
                ),
                startAt: startAt,
                endAt: endAt,
                pickupLocation: _pickupLocationController.text.trim(),
                dropoffLocation: _dropoffLocationController.text.trim(),
                noteText: _noteController.text.trim(),
              ),
            );
          },
          child: const Text('저장'),
        ),
      ],
    );
  }
}

class _ReservationEditTextField extends StatelessWidget {
  const _ReservationEditTextField({
    required this.controller,
    required this.label,
    this.hintText,
    this.validator,
    this.maxLines = 1,
    this.suffixIcon,
    this.keyboardType,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final String label;
  final String? hintText;
  final String? Function(String?)? validator;
  final int maxLines;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        validator: validator,
        maxLines: maxLines,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          suffixIcon: suffixIcon,
        ),
      ),
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

String _formatLinkedScheduleDateTime(DateTime value) {
  final local = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
  return '${two(local.month)}/${two(local.day)}(${weekdays[local.weekday - 1]}) ${two(local.hour)}:${two(local.minute)}';
}

String _formatEditorDateTime(DateTime value) {
  return opsFormatEditorDateTime(value);
}

DateTime? _tryParseEditorDateTime(String value, {DateTime? fallback}) {
  return opsTryParseEditorDateTime(value, fallback: fallback);
}

String _formatWon(String value) {
  final digits = value.replaceAll(RegExp(r'\D+'), '');
  if (digits.isEmpty) return '';
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return '$buffer원';
}

String _normalizeMoneyForStorage(String value) {
  return value.replaceAll(RegExp(r'\D+'), '');
}

String? _requiredValidator(String? value) {
  if (value == null || value.trim().isEmpty) return '필수 입력입니다';
  return null;
}

String? _phoneValidator(String? value) {
  if (!opsIsValidPhoneForStorage(value ?? '')) {
    return '전화번호 형식을 확인해 주세요';
  }
  return null;
}

String? _positiveMoneyValidator(String? value) {
  final amount = int.tryParse(_normalizeMoneyForStorage(value ?? ''));
  if (amount == null || amount <= 0) return '0보다 큰 금액을 입력해 주세요';
  return null;
}

String? _dateTimeValidator(String? value) {
  if (_tryParseEditorDateTime(value ?? '') == null) {
    return '예: 2026-05-17 10:00';
  }
  return null;
}

String? _birthDateValidator(String? value) {
  final text = (value ?? '').trim();
  if (text.isEmpty) return null;
  if (!opsIsCompleteBirthDate(text)) {
    return '실제 날짜를 입력해 주세요';
  }
  return null;
}

String _formatOptionalDateTime(DateTime? value) {
  if (value == null) return '';
  return _formatDateTime(value);
}

String _displayValue(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? '-' : trimmed;
}

String _resolveImsReturnContractId(ExternalReservationLink? link) {
  if (link == null) return '';
  final detailId = link.externalDetailId.trim();
  if (detailId.isNotEmpty) return detailId;
  return link.externalReservationId.trim();
}

String? _extractRawRowId(String recordId, String prefix) {
  final expected = '$prefix:';
  if (!recordId.startsWith(expected)) return null;
  return recordId.substring(expected.length);
}

bool _isTruthy(String value) {
  final normalized = value.trim().toLowerCase();
  return normalized == 'true' || normalized == '1' || normalized == 'yes';
}
