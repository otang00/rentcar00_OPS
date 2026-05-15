import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rentcar00_ops/app/router/app_routes.dart';
import 'package:rentcar00_ops/data/models/reservation_record.dart';
import 'package:rentcar00_ops/data/models/status_board_record.dart';
import 'package:rentcar00_ops/features/reservations/detail/data/ims_reservation_client.dart';
import 'package:rentcar00_ops/features/reservations/detail/data/ims_reservation_payload.dart';
import 'package:rentcar00_ops/features/reservations/shared/domain/reservation_tab.dart';
import 'package:rentcar00_ops/features/status_board/detail/data/reservation_ai_parser_client.dart';
import 'package:rentcar00_ops/features/reservations/shared/providers/reservation_providers.dart';
import 'package:rentcar00_ops/features/status_board/shared/presentation/schedule_editor_dialog.dart';
import 'package:rentcar00_ops/shared/config/supabase_providers.dart';
import 'package:rentcar00_ops/shared/utils/contact_launcher.dart';

const _parkingLocationOptions = [
  '수푸레B1',
  '수푸레B2',
  '주차타워(반포)',
  '반포3주민센터',
  '수푸레1층',
];

ReservationRecord _buildReservationRecordForIms({
  required String reservationId,
  required _ReservationCreateFormResult form,
  required StatusBoardRecord car,
}) {
  return ReservationRecord(
    reservationId: reservationId,
    reservationNumber: form.reservationNumber,
    customerName: form.customerName,
    customerPhone: form.customerPhone,
    customerBirthDate: form.customerBirthDate,
    referralSource: form.referralSource,
    paymentAmount: form.paymentAmount,
    carNumber: car.carNumber,
    carName: car.carName,
    tab: ReservationTab.pending,
    statusKey: '예약중',
    startAt: form.startAt,
    endAt: form.endAt,
    locationSummary: form.pickupLocation,
    noteText: form.noteText,
    primaryBadges: const [],
    checkPayload: const {},
    actionLogs: const [],
  );
}

void _showReservationCreateSnackBar(
  BuildContext context, {
  required String label,
  required StatusBoardRecord car,
  required DateTime startAt,
  required Color color,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: color,
      content: Text(
        '$label(${car.carNumber.trim()}, ${_formatEditorDateTime(startAt)})',
      ),
    ),
  );
}

Future<T> _runWithImsProgress<T>(
  BuildContext context,
  Future<T> Function() task,
) async {
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
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }
}

Future<void> _saveImsRegistrationResult({
  required WidgetRef ref,
  required String reservationId,
  required ImsReservationPayload payload,
  required ImsReservationExecutionResult result,
  String? fallbackErrorText,
}) async {
  final linked = result.hasLinkedExternalId;
  final status = linked ? 'linked' : 'failed';
  final linkKey = result.linkKey.trim().isEmpty
      ? 'OPS:${reservationId.trim()}'
      : result.linkKey.trim();
  final errorText = linked
      ? null
      : (result.errorText.trim().isNotEmpty
            ? result.errorText.trim()
            : (fallbackErrorText?.trim().isNotEmpty == true
                  ? fallbackErrorText!.trim()
                  : (result.message.trim().isNotEmpty
                        ? result.message.trim()
                        : result.code)));

  await ref
      .read(supabaseOpsRepositoryProvider)
      .upsertExternalReservationLink(
        reservationId: reservationId,
        externalReservationId: result.externalReservationId,
        externalDetailId: result.externalDetailId,
        externalStatus: status,
        linkKey: linkKey,
        lastPayloadJson: payload.toJson(),
        lastResultJson: result.resultJson,
        errorText: errorText,
      );
}

Future<void> _saveImsRegistrationFailure({
  required WidgetRef ref,
  required String reservationId,
  required ImsReservationPayload payload,
  required String errorText,
}) async {
  await ref
      .read(supabaseOpsRepositoryProvider)
      .upsertExternalReservationLink(
        reservationId: reservationId,
        externalStatus: 'failed',
        linkKey: 'OPS:${reservationId.trim()}',
        lastPayloadJson: payload.toJson(),
        lastResultJson: {'error': errorText},
        errorText: errorText,
      );
}

Future<void> showReservationCreateFlow({
  required BuildContext context,
  required WidgetRef ref,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  List<StatusBoardRecord> cars;
  try {
    final records = await ref.read(allStatusBoardRecordsProvider.future);
    cars = records.where((item) => !item.isScheduleEntry).toList()
      ..sort((a, b) => a.carNumber.compareTo(b.carNumber));
  } catch (error) {
    messenger.showSnackBar(
      SnackBar(content: Text('차량 목록을 불러오지 못했습니다.\n$error')),
    );
    return;
  }

  if (!context.mounted) return;
  final appEnv = ref.read(appEnvProvider);
  final form = await showDialog<_ReservationCreateFormResult>(
    context: context,
    builder: (context) => _ReservationCreateDialog(
      aiParserBaseUrl: appEnv.aiParserBaseUrl,
      availableCars: cars,
    ),
  );
  if (form == null || !context.mounted) return;

  final reservation = _buildReservationRecordForIms(
    reservationId: 'draft',
    form: form,
    car: form.car,
  );
  final preflightPayload = buildImsReservationPayload(reservation);
  if (form.imsChecked && !preflightPayload.isValid) {
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: Colors.redAccent,
        content: Text(
          'IMS 확인 필요: ${preflightPayload.errors.map(imsPayloadErrorLabel).join(', ')}',
        ),
      ),
    );
    return;
  }

  try {
    final reservationId = await ref
        .read(supabaseOpsRepositoryProvider)
        .createReservationFromVehicle(
          car: form.car,
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
          createdVia: 'global_reservation_add',
        );

    if (!context.mounted) return;

    if (form.imsChecked) {
      final confirmedReservation = _buildReservationRecordForIms(
        reservationId: reservationId,
        form: form,
        car: form.car,
      );
      try {
        final confirmedPayload = buildImsReservationPayload(
          confirmedReservation,
        ).payload;
        final result = await _runWithImsProgress(context, () async {
          final client = ImsReservationClient(baseUrl: appEnv.aiParserBaseUrl);
          return client.createReservation(confirmedPayload);
        });
        await _saveImsRegistrationResult(
          ref: ref,
          reservationId: reservationId,
          payload: confirmedPayload,
          result: result,
        );
        if (!context.mounted) return;
        if (result.hasLinkedExternalId) {
          _showReservationCreateSnackBar(
            context,
            label: 'IMS 등록완료',
            car: form.car,
            startAt: form.startAt,
            color: Colors.green,
          );
        } else {
          _showReservationCreateSnackBar(
            context,
            label:
                'IMS예약실패(${result.message.isEmpty ? result.code : result.message})',
            car: form.car,
            startAt: form.startAt,
            color: Colors.redAccent,
          );
        }
      } on ImsReservationClientException catch (error) {
        final failedPayload = buildImsReservationPayload(
          confirmedReservation,
        ).payload;
        await _saveImsRegistrationFailure(
          ref: ref,
          reservationId: reservationId,
          payload: failedPayload,
          errorText: error.message,
        );
        if (!context.mounted) return;
        _showReservationCreateSnackBar(
          context,
          label: 'IMS예약실패(${error.message})',
          car: form.car,
          startAt: form.startAt,
          color: Colors.redAccent,
        );
      } catch (error) {
        final failedPayload = buildImsReservationPayload(
          confirmedReservation,
        ).payload;
        await _saveImsRegistrationFailure(
          ref: ref,
          reservationId: reservationId,
          payload: failedPayload,
          errorText: '$error',
        );
        if (!context.mounted) return;
        _showReservationCreateSnackBar(
          context,
          label: 'IMS예약실패($error)',
          car: form.car,
          startAt: form.startAt,
          color: Colors.redAccent,
        );
      }
    } else {
      messenger.showSnackBar(
        const SnackBar(content: Text('예약원장과 일정 2건을 생성했습니다.')),
      );
    }

    ref.invalidate(allStatusBoardRecordsProvider);
    ref.invalidate(allReservationsProvider);
    if (!context.mounted) return;
    context.push(
      AppRoutes.reservationDetail.replaceFirst(
        ':reservationId',
        Uri.encodeComponent(reservationId),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    messenger.showSnackBar(SnackBar(content: Text('예약 생성에 실패했습니다.\n$error')));
  }
}

class StatusBoardDetailPage extends ConsumerWidget {
  const StatusBoardDetailPage({super.key, required this.recordId});

  final String recordId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordAsync = ref.watch(statusBoardDetailProvider(recordId));

    return Scaffold(
      appBar: AppBar(title: const Text('상세')),
      body: recordAsync.when(
        data: (record) {
          if (record == null) {
            return const Center(child: Text('정보를 찾을 수 없습니다.'));
          }
          if (record.isScheduleEntry) {
            return _ScheduleDetailBody(record: record);
          }
          return _VehicleDetailBody(recordId: recordId, record: record);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('상세를 불러오지 못했습니다.\n$error')),
      ),
    );
  }
}

class _VehicleDetailBody extends ConsumerStatefulWidget {
  const _VehicleDetailBody({required this.recordId, required this.record});

  final String recordId;
  final StatusBoardRecord record;

  @override
  ConsumerState<_VehicleDetailBody> createState() => _VehicleDetailBodyState();
}

class _VehicleDetailBodyState extends ConsumerState<_VehicleDetailBody> {
  bool _submitting = false;

  StatusBoardRecord get record => widget.record;

  Future<void> _runAction(Future<void> Function() action) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await action();
      if (!mounted) return;
      ref.invalidate(allStatusBoardRecordsProvider);
      ref.invalidate(allReservationsProvider);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _createReservation() async {
    final appEnv = ref.read(appEnvProvider);
    final form = await showDialog<_ReservationCreateFormResult>(
      context: context,
      builder: (context) => _ReservationCreateDialog(
        record: record,
        aiParserBaseUrl: appEnv.aiParserBaseUrl,
      ),
    );
    if (form == null) return;

    final preflightReservation = _buildReservationRecordForIms(
      reservationId: 'draft',
      form: form,
    );
    final preflightPayload = buildImsReservationPayload(preflightReservation);
    if (form.imsChecked && !preflightPayload.isValid) {
      _showImsFailure(
        preflightPayload.errors.map(imsPayloadErrorLabel).join(', '),
      );
      return;
    }

    await _runAction(() async {
      final reservationId = await ref
          .read(supabaseOpsRepositoryProvider)
          .createReservationFromVehicle(
            car: form.car,
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
      if (!mounted) return;

      if (form.imsChecked) {
        final reservation = _buildReservationRecordForIms(
          reservationId: reservationId,
          form: form,
        );
        final confirmedPayload = buildImsReservationPayload(
          reservation,
        ).payload;
        try {
          final result = await _runWithImsProgress(context, () async {
            final client = ImsReservationClient(
              baseUrl: appEnv.aiParserBaseUrl,
            );
            return client.createReservation(confirmedPayload);
          });
          await _saveImsRegistrationResult(
            ref: ref,
            reservationId: reservationId,
            payload: confirmedPayload,
            result: result,
          );
          if (!mounted) return;

          if (result.hasLinkedExternalId) {
            _showImsSuccess(
              carNumber: reservation.carNumber,
              startAt: reservation.startAt,
            );
          } else {
            _showImsFailure(
              result.message.isEmpty ? result.code : result.message,
            );
          }
        } on ImsReservationClientException catch (error) {
          await _saveImsRegistrationFailure(
            ref: ref,
            reservationId: reservationId,
            payload: confirmedPayload,
            errorText: error.message,
          );
          if (!mounted) return;
          _showImsFailure(error.message);
        } catch (error) {
          await _saveImsRegistrationFailure(
            ref: ref,
            reservationId: reservationId,
            payload: confirmedPayload,
            errorText: '$error',
          );
          if (!mounted) return;
          _showImsFailure('$error');
        }
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('예약원장과 일정 2건을 생성했습니다.')));
      }

      context.push(
        AppRoutes.reservationDetail.replaceFirst(
          ':reservationId',
          Uri.encodeComponent(reservationId),
        ),
      );
    });
  }

  Future<void> _openInstantStatus(String status, String statusAction) async {
    final form = await showDialog<_InstantStatusFormResult>(
      context: context,
      builder: (context) => _InstantStatusDialog(
        record: record,
        title: statusAction,
        initialStatus: status,
        statusAction: statusAction,
      ),
    );
    if (form == null) return;

    final carRowId = _extractRawRowId(record.recordId, 'car');
    if (carRowId == null) {
      _showError('차량 row id 를 찾지 못했습니다.');
      return;
    }

    await _runAction(() async {
      await ref
          .read(supabaseOpsRepositoryProvider)
          .updateCarInstantStatus(
            carRowId: carRowId,
            status: form.status,
            statusAction: form.statusAction,
            customerName: form.customerName,
            customerPhone: form.customerPhone,
            startAt: form.startAt,
            endAt: form.endAt,
            pickupLocation: form.pickupLocation,
            parkingLocation: form.parkingLocation,
            noteText: form.noteText,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${form.statusAction} 상태로 저장했습니다.')),
      );
    });
  }

  Future<void> _editVehicleStatus() async {
    final form = await showDialog<_InstantStatusFormResult>(
      context: context,
      builder: (context) => _InstantStatusDialog(
        record: record,
        title: '차량 상태 수정',
        initialStatus: _normalizeEditableStatus(record.status),
        statusAction: '상태 수정',
        allowStatusSelection: true,
      ),
    );
    if (form == null) return;

    final carRowId = _extractRawRowId(record.recordId, 'car');
    if (carRowId == null) {
      _showError('차량 row id 를 찾지 못했습니다.');
      return;
    }

    await _runAction(() async {
      await ref
          .read(supabaseOpsRepositoryProvider)
          .updateCarInstantStatus(
            carRowId: carRowId,
            status: form.status,
            statusAction: form.statusAction,
            customerName: form.customerName,
            customerPhone: form.customerPhone,
            startAt: form.startAt,
            endAt: form.endAt,
            pickupLocation: form.pickupLocation,
            parkingLocation: form.parkingLocation,
            noteText: form.noteText,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('차량 상태를 수정했습니다.')));
    });
  }

  Future<void> _toggleWash({required bool interior}) async {
    final carRowId = _extractRawRowId(record.recordId, 'car');
    if (carRowId == null) {
      _showError('차량 row id 를 찾지 못했습니다.');
      return;
    }

    final current = interior ? record.interiorWash : record.carWash;
    final next = !_isTruthy(current);
    await _runAction(() async {
      await ref
          .read(supabaseOpsRepositoryProvider)
          .setCarWashFlag(carRowId: carRowId, interior: interior, active: next);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${interior ? '실내세차' : '외부세차'}를 ${next ? '완료' : '해제'}했습니다.',
          ),
        ),
      );
    });
  }

  Future<void> _editParking() async {
    final parkingLocation = await showDialog<String>(
      context: context,
      builder: (context) =>
          _ParkingLocationDialog(initialValue: record.parkingLocation),
    );
    if (parkingLocation == null) return;

    final carRowId = _extractRawRowId(record.recordId, 'car');
    if (carRowId == null) {
      _showError('차량 row id 를 찾지 못했습니다.');
      return;
    }

    await _runAction(() async {
      await ref
          .read(supabaseOpsRepositoryProvider)
          .updateParkingLocation(
            carRowId: carRowId,
            parkingLocation: parkingLocation,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('주차지를 저장했습니다.')));
    });
  }

  Future<void> _editCarManagementInfo() async {
    final form = await showDialog<_CarManagementInfoFormResult>(
      context: context,
      builder: (context) => _CarManagementInfoDialog(record: record),
    );
    if (form == null) return;

    final carRowId = _extractRawRowId(record.recordId, 'car');
    if (carRowId == null) {
      _showError('차량 row id 를 찾지 못했습니다.');
      return;
    }

    await _runAction(() async {
      await ref
          .read(supabaseOpsRepositoryProvider)
          .updateCarManagementInfo(
            carRowId: carRowId,
            carInspectionAt: form.carInspectionAt,
            carAgeExpiryAt: form.carAgeExpiryAt,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('차량 관리 정보를 저장했습니다.')));
    });
  }

  Future<void> _completeReturn() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _ConfirmActionDialog(
        icon: Icons.assignment_turned_in_outlined,
        title: '반납 완료',
        message: '차량을 대기중으로 전환하고 세차 상태와 주차지를 초기화합니다.',
        confirmLabel: '완료',
      ),
    );
    if (confirmed != true) return;

    final carRowId = _extractRawRowId(record.recordId, 'car');
    if (carRowId == null) {
      _showError('차량 row id 를 찾지 못했습니다.');
      return;
    }

    await _runAction(() async {
      await ref
          .read(supabaseOpsRepositoryProvider)
          .completeCarReturn(carRowId: carRowId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('반납 완료 처리했습니다.')));
    });
  }

  ReservationRecord _buildReservationRecordForIms({
    required String reservationId,
    required _ReservationCreateFormResult form,
  }) {
    return ReservationRecord(
      reservationId: reservationId,
      reservationNumber: form.reservationNumber,
      customerName: form.customerName,
      customerPhone: form.customerPhone,
      customerBirthDate: form.customerBirthDate,
      referralSource: form.referralSource,
      paymentAmount: form.paymentAmount,
      carNumber: form.car.carNumber,
      carName: form.car.carName,
      tab: ReservationTab.pending,
      statusKey: '예약중',
      startAt: form.startAt,
      endAt: form.endAt,
      locationSummary: form.pickupLocation,
      noteText: form.noteText,
      primaryBadges: const [],
      checkPayload: const {},
      actionLogs: const [],
    );
  }

  void _showImsSuccess({required String carNumber, required DateTime startAt}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.green,
        content: Text(
          'IMS 등록완료(${carNumber.trim()}, ${_formatEditorDateTime(startAt)})',
        ),
      ),
    );
  }

  void _showImsFailure(String reason) {
    final trimmed = reason.trim();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.redAccent,
        content: Text(
          'IMS예약실패(${trimmed.isEmpty ? 'unknown error' : trimmed})',
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final relatedSchedulesAsync = ref.watch(
      relatedSchedulesProvider(widget.recordId),
    );
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final idleActions = _isIdleStatus(record.status);
    final inServiceActions = _isInServiceStatus(record.status);
    final hasPhone = hasCallablePhone(record.customerPhone);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
      children: [
        Text(
          record.carNumber.isEmpty ? '(차량번호없음)' : record.carNumber,
          style: textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          record.carName.isEmpty ? '차종 미확인' : record.carName,
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            record.status.isEmpty
                ? record.tab.label
                : '${record.tab.label} · ${record.status}',
            style: textTheme.titleSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (_submitting) ...[
          const LinearProgressIndicator(),
          const SizedBox(height: 10),
        ],
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 4,
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
          childAspectRatio: 1.05,
          children: [
            _ActionChipButton(
              label: '예약',
              icon: Icons.add_card_rounded,
              emphasis: _ActionChipEmphasis.primary,
              expand: true,
              onPressed: _submitting ? null : _createReservation,
            ),
            _ActionChipButton(
              label: '수정',
              icon: Icons.edit_outlined,
              expand: true,
              onPressed: _submitting ? null : _editVehicleStatus,
            ),
            if (idleActions) ...[
              _ActionChipButton(
                label: '보험',
                icon: Icons.shield_outlined,
                expand: true,
                onPressed: _submitting
                    ? null
                    : () => _openInstantStatus('보험', '배차 보험'),
              ),
              _ActionChipButton(
                label: '일반',
                icon: Icons.directions_car_filled_outlined,
                expand: true,
                onPressed: _submitting
                    ? null
                    : () => _openInstantStatus('일반', '배차 일반'),
              ),
              _ActionChipButton(
                label: '장기',
                icon: Icons.event_repeat_outlined,
                expand: true,
                onPressed: _submitting
                    ? null
                    : () => _openInstantStatus('장기', '배차 장기'),
              ),
            ],
            if (inServiceActions)
              _ActionChipButton(
                label: '반납',
                icon: Icons.assignment_return_outlined,
                emphasis: _ActionChipEmphasis.primary,
                expand: true,
                onPressed: _submitting ? null : _completeReturn,
              ),
            if (inServiceActions && hasPhone)
              _ActionChipButton(
                label: '전화',
                icon: Icons.call_outlined,
                expand: true,
                onPressed: _submitting
                    ? null
                    : () => tryLaunchPhoneCall(context, record.customerPhone),
              ),
            if (inServiceActions && hasPhone)
              _ActionChipButton(
                label: '문자',
                icon: Icons.sms_outlined,
                expand: true,
                onPressed: _submitting
                    ? null
                    : () => tryLaunchSms(context, record.customerPhone),
              ),
            if (idleActions)
              _ActionChipButton(
                label: '외부',
                icon: _isTruthy(record.carWash)
                    ? Icons.local_car_wash_rounded
                    : Icons.local_car_wash_outlined,
                active: _isTruthy(record.carWash),
                expand: true,
                onPressed: _submitting
                    ? null
                    : () => _toggleWash(interior: false),
              ),
            if (idleActions)
              _ActionChipButton(
                label: '실내',
                icon: _isTruthy(record.interiorWash)
                    ? Icons.airline_seat_recline_normal_rounded
                    : Icons.airline_seat_recline_normal_outlined,
                active: _isTruthy(record.interiorWash),
                expand: true,
                onPressed: _submitting
                    ? null
                    : () => _toggleWash(interior: true),
              ),
            if (idleActions)
              _ActionChipButton(
                label: '주차',
                icon: Icons.local_parking_outlined,
                expand: true,
                onPressed: _submitting ? null : _editParking,
              ),
          ],
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: 'Related 일정',
          child: relatedSchedulesAsync.when(
            data: (items) {
              if (items.isEmpty) {
                return const Text('연결된 일정이 없습니다.');
              }
              return Column(
                children: [
                  for (final item in items)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(
                        item.scheduleType.isEmpty
                            ? item.timeLabel
                            : '${item.scheduleType} · ${item.timeLabel}',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        item.locationSummary.isEmpty
                            ? (item.detailText.isEmpty ? '-' : item.detailText)
                            : item.locationSummary,
                        style: textTheme.bodyMedium?.copyWith(height: 1.3),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push(
                        '/schedule/${Uri.encodeComponent(item.recordId)}',
                      ),
                    ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Text('일정 정보를 불러오지 못했습니다.\n$error'),
          ),
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: '운행 정보',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FieldBlock(
                label: '임차인',
                value: record.customerName,
                emphasize: true,
              ),
              _FieldBlock(label: '고객번호', value: record.customerPhone),
              _FieldBlock(label: '대여일', value: record.startAt),
              _FieldBlock(label: '반납일', value: record.endAt),
              _FieldBlock(label: '배차지', value: record.pickupLocation),
              _FieldBlock(label: '주차지', value: record.parkingLocation),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: '차량 관리 정보',
          trailing: TextButton.icon(
            onPressed: _submitting ? null : _editCarManagementInfo,
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('수정'),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FieldBlock(label: '세차', value: record.carWash),
              _FieldBlock(label: '실내세차', value: record.interiorWash),
              _FieldBlock(label: '차량등록일', value: record.carRegisteredAt),
              _FieldBlock(label: '차량검사일', value: record.carInspectionAt),
              _FieldBlock(label: '차령만료일', value: record.carAgeExpiryAt),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: '차량 번호 세부',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FieldBlock(
                label: '차량번호(앞)',
                value: record.carNumberFront,
                emphasize: true,
              ),
              _FieldBlock(
                label: '차량번호(중)',
                value: record.carNumberMiddle,
                emphasize: true,
              ),
              _FieldBlock(
                label: '차량번호(네자리)',
                value: record.carNumberRear,
                emphasize: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: '메모 / 상태',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FieldBlock(label: '상태액션', value: record.statusAction),
              _FieldBlock(label: '비고', value: record.noteText, multiline: true),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionChipButton extends StatelessWidget {
  const _ActionChipButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.emphasis = _ActionChipEmphasis.standard,
    this.active = false,
    this.expand = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final _ActionChipEmphasis emphasis;
  final bool active;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isPrimary = emphasis == _ActionChipEmphasis.primary;
    final isDanger = emphasis == _ActionChipEmphasis.danger;
    final isActive = active && !isDanger;
    final foreground = isDanger
        ? const Color(0xFFB42318)
        : (isPrimary || isActive)
        ? colorScheme.onPrimary
        : colorScheme.primary;
    final background = isDanger
        ? const Color(0xFFFFF1F0)
        : (isPrimary || isActive)
        ? colorScheme.primary
        : const Color(0xFFEAF5FF);
    final borderColor = isDanger
        ? const Color(0xFFFFC9C5)
        : (isPrimary || isActive)
        ? colorScheme.primary
        : const Color(0xFFBBDEFB);

    final button = FilledButton.tonal(
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
    );

    if (expand) {
      return SizedBox.expand(child: button);
    }

    return SizedBox(width: 64, height: 58, child: button);
  }
}

enum _ActionChipEmphasis { standard, primary, danger }

String _carDisplayLabel(StatusBoardRecord car) {
  final name = car.carName.trim();
  return name.isEmpty ? car.carNumber : '${car.carNumber} · $name';
}

class _CarSelectDialog extends StatefulWidget {
  const _CarSelectDialog({required this.cars, this.initialCar});

  final List<StatusBoardRecord> cars;
  final StatusBoardRecord? initialCar;

  @override
  State<_CarSelectDialog> createState() => _CarSelectDialogState();
}

class _CarSelectDialogState extends State<_CarSelectDialog> {
  late final TextEditingController _queryController;

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController();
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  List<StatusBoardRecord> _filteredCars(String query) {
    final raw = query.trim().toLowerCase();
    final digits = raw.replaceAll(RegExp(r'\D+'), '');
    if (raw.isEmpty) return widget.cars;
    return widget.cars.where((car) {
      final number = car.carNumber.toLowerCase();
      final name = car.carName.toLowerCase();
      final numberDigits = car.carNumber.replaceAll(RegExp(r'\D+'), '');
      return number.contains(raw) ||
          name.contains(raw) ||
          (digits.isNotEmpty && numberDigits.endsWith(digits));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final filtered = _filteredCars(_queryController.text);

    return AlertDialog(
      title: const Text('차량 선택'),
      content: SizedBox(
        width: 420,
        height: 520,
        child: Column(
          children: [
            TextField(
              controller: _queryController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '차량번호 / 뒤4자리 / 차종 검색',
                prefixIcon: Icon(Icons.search_outlined),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('검색 결과가 없습니다.'))
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final car = filtered[index];
                        final selected =
                            widget.initialCar?.recordId == car.recordId;
                        return ListTile(
                          dense: true,
                          selected: selected,
                          title: Text(
                            car.carNumber,
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          subtitle: Text(
                            [
                              if (car.carName.trim().isNotEmpty) car.carName,
                              if (car.status.trim().isNotEmpty) car.status,
                            ].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: selected
                              ? const Icon(Icons.check_circle)
                              : null,
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

class _ReservationCreateDialog extends StatefulWidget {
  const _ReservationCreateDialog({
    this.record,
    required this.aiParserBaseUrl,
    this.availableCars = const [],
  });

  final StatusBoardRecord? record;
  final String aiParserBaseUrl;
  final List<StatusBoardRecord> availableCars;

  @override
  State<_ReservationCreateDialog> createState() =>
      _ReservationCreateDialogState();
}

class _ReservationCreateDialogState extends State<_ReservationCreateDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _reservationNumberController;
  late final TextEditingController _customerNameController;
  late final TextEditingController _customerPhoneController;
  late final TextEditingController _customerBirthDateController;
  late final TextEditingController _referralSourceController;
  late final TextEditingController _paymentAmountController;
  late final TextEditingController _pickupLocationController;
  late final TextEditingController _dropoffLocationController;
  late final TextEditingController _noteController;
  late final TextEditingController _startAtController;
  late final TextEditingController _endAtController;
  late final TextEditingController _carController;
  StatusBoardRecord? _selectedCar;
  bool _aiParsing = false;
  bool _imsChecked = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day, now.hour, now.minute);
    final end = start.add(const Duration(days: 1));
    _selectedCar = widget.record;
    _carController = TextEditingController(
      text: _selectedCar == null ? '' : _carDisplayLabel(_selectedCar!),
    );
    _reservationNumberController = TextEditingController();
    _customerNameController = TextEditingController();
    _customerPhoneController = TextEditingController();
    _customerBirthDateController = TextEditingController();
    _referralSourceController = TextEditingController();
    _paymentAmountController = TextEditingController();
    _pickupLocationController = TextEditingController();
    _dropoffLocationController = TextEditingController();
    _noteController = TextEditingController();
    _startAtController = TextEditingController(
      text: _formatEditorDateTime(start),
    );
    _endAtController = TextEditingController(text: _formatEditorDateTime(end));
  }

  Future<void> _openAiParserInput() async {
    if (_aiParsing) return;

    final text = await showDialog<String>(
      context: context,
      builder: (context) =>
          _AiParserTextInputDialog(aiParserBaseUrl: widget.aiParserBaseUrl),
    );
    if (text == null || text.trim().isEmpty || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _aiParsing = true);

    try {
      final client = ReservationAiParserClient(baseUrl: widget.aiParserBaseUrl);
      final result = await client.parseText(text);
      if (!mounted) return;
      _applyAiParserResult(result, sourceText: text);

      final message = [
        if (result.missing.isNotEmpty) '누락: ${result.missing.join(', ')}',
        if (result.warnings.isNotEmpty) '경고: ${result.warnings.join(', ')}',
        if (result.missing.isEmpty && result.warnings.isEmpty)
          'AI파서 결과를 입력했습니다.',
      ].join('\n');

      messenger.showSnackBar(SnackBar(content: Text(message)));
    } on ReservationAiParserException catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('AI파서 호출 실패\n$error')));
    } finally {
      if (mounted) setState(() => _aiParsing = false);
    }
  }

  void _applyAiParserResult(
    ReservationAiParseResult result, {
    required String sourceText,
  }) {
    final fields = result.fields;

    void fillIfNotEmpty(TextEditingController controller, String? value) {
      if (value == null || value.trim().isEmpty) return;
      controller.text = value.trim();
    }

    fillIfNotEmpty(_reservationNumberController, fields.reservationNumber);
    fillIfNotEmpty(_customerNameController, fields.customerName);
    fillIfNotEmpty(_customerPhoneController, fields.customerPhone);
    fillIfNotEmpty(_customerBirthDateController, fields.birthDate);
    fillIfNotEmpty(_referralSourceController, fields.referrer);
    fillIfNotEmpty(_paymentAmountController, fields.price);
    fillIfNotEmpty(_pickupLocationController, fields.pickupLocation);
    fillIfNotEmpty(_dropoffLocationController, fields.returnLocation);
    fillIfNotEmpty(_noteController, sourceText);

    final parsedStartAt = _normalizeAiDateTime(fields.pickupAt);
    final parsedEndAt = _normalizeAiDateTime(fields.returnAt);
    fillIfNotEmpty(_startAtController, parsedStartAt);
    fillIfNotEmpty(_endAtController, parsedEndAt);
  }

  String? _normalizeAiDateTime(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) return null;
    final parsed = DateTime.tryParse(text.replaceFirst(' ', 'T'));
    if (parsed == null) return text;
    return _formatEditorDateTime(parsed);
  }

  Future<void> _pickDateTime(TextEditingController controller) async {
    final now = DateTime.now();
    final initial = _tryParseDateTime(controller.text.trim()) ?? now;
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

    final combined = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    setState(() {
      controller.text = _formatEditorDateTime(combined);
    });
  }

  @override
  void dispose() {
    _reservationNumberController.dispose();
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _customerBirthDateController.dispose();
    _referralSourceController.dispose();
    _paymentAmountController.dispose();
    _pickupLocationController.dispose();
    _dropoffLocationController.dispose();
    _noteController.dispose();
    _startAtController.dispose();
    _endAtController.dispose();
    _carController.dispose();
    super.dispose();
  }

  Future<void> _selectCar() async {
    final selected = await showDialog<StatusBoardRecord>(
      context: context,
      builder: (context) => _CarSelectDialog(
        cars: widget.availableCars,
        initialCar: _selectedCar,
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _selectedCar = selected;
      _carController.text = _carDisplayLabel(selected);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Expanded(child: Text('예약생성')),
          TextButton.icon(
            onPressed: _aiParsing ? null : _openAiParserInput,
            icon: _aiParsing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome_outlined),
            label: const Text('AI파서'),
          ),
        ],
      ),
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
                  if (widget.record == null)
                    _DialogTextField(
                      controller: _carController,
                      label: '차량번호',
                      hintText: '차량 선택',
                      readOnly: true,
                      onTap: _selectCar,
                      suffixIcon: const Icon(Icons.search_outlined),
                      validator: _requiredValidator,
                    ),
                  _DialogTextField(
                    controller: _reservationNumberController,
                    label: '외부예약번호',
                    validator: _requiredValidator,
                  ),
                  _DialogTextField(
                    controller: _customerNameController,
                    label: '이용자/고객명',
                    validator: _requiredValidator,
                  ),
                  _DialogTextField(
                    controller: _customerPhoneController,
                    label: '고객번호',
                    validator: _phoneValidator,
                  ),
                  _DialogTextField(
                    controller: _customerBirthDateController,
                    label: '생년월일',
                    hintText: '1990-01-31',
                    validator: _birthDateValidator,
                  ),
                  _DialogTextField(
                    controller: _referralSourceController,
                    label: '소개처',
                  ),
                  _DialogTextField(
                    controller: _paymentAmountController,
                    label: '가격',
                    hintText: '100000',
                    validator: _positiveMoneyValidator,
                  ),
                  _DialogTextField(
                    controller: _startAtController,
                    label: '배차일시',
                    hintText: '2026-05-11 10:00',
                    validator: _dateTimeValidator,
                    readOnly: true,
                    onTap: () => _pickDateTime(_startAtController),
                    suffixIcon: const Icon(Icons.calendar_today_outlined),
                  ),
                  _DialogTextField(
                    controller: _endAtController,
                    label: '반납일시',
                    hintText: '2026-05-12 10:00',
                    validator: _dateTimeValidator,
                    readOnly: true,
                    onTap: () => _pickDateTime(_endAtController),
                    suffixIcon: const Icon(Icons.calendar_today_outlined),
                  ),
                  _DialogTextField(
                    controller: _pickupLocationController,
                    label: '배차지',
                    validator: _requiredValidator,
                  ),
                  _DialogTextField(
                    controller: _dropoffLocationController,
                    label: '반납지',
                    validator: _requiredValidator,
                  ),
                  _DialogTextField(
                    controller: _noteController,
                    label: '비고',
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(
              value: _imsChecked,
              onChanged: (value) {
                setState(() => _imsChecked = value ?? false);
              },
            ),
            const Text('IMS'),
          ],
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            final selectedCar = _selectedCar;
            if (selectedCar == null) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('차량을 선택해주세요.')));
              return;
            }
            final startAt = _tryParseDateTime(_startAtController.text.trim());
            final endAt = _tryParseDateTime(_endAtController.text.trim());
            if (startAt == null || endAt == null) return;
            if (!endAt.isAfter(startAt)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('반납일시는 배차일시 이후여야 합니다.')),
              );
              return;
            }
            final result = _ReservationCreateFormResult(
              car: selectedCar,
              reservationNumber: _reservationNumberController.text.trim(),
              customerName: _customerNameController.text.trim(),
              customerPhone: _normalizePhoneForStorage(
                _customerPhoneController.text,
              ),
              customerBirthDate: _normalizeBirthDateForStorage(
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
              imsChecked: _imsChecked,
            );

            if (_imsChecked) {
              final reservation = ReservationRecord(
                reservationId: 'draft',
                reservationNumber: result.reservationNumber,
                customerName: result.customerName,
                customerPhone: result.customerPhone,
                customerBirthDate: result.customerBirthDate,
                referralSource: result.referralSource,
                paymentAmount: result.paymentAmount,
                carNumber: selectedCar.carNumber,
                carName: selectedCar.carName,
                tab: ReservationTab.pending,
                statusKey: '예약중',
                startAt: result.startAt,
                endAt: result.endAt,
                locationSummary: result.pickupLocation,
                noteText: result.noteText,
                primaryBadges: const [],
                checkPayload: const {},
                actionLogs: const [],
              );
              final imsResult = buildImsReservationPayload(reservation);
              if (!imsResult.isValid) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: Colors.redAccent,
                    content: Text(
                      'IMS 확인 필요: ${imsResult.errors.map(imsPayloadErrorLabel).join(', ')}',
                    ),
                  ),
                );
                return;
              }
            }

            Navigator.of(context).pop(result);
          },
          child: const Text('생성'),
        ),
      ],
    );
  }
}

class _InstantStatusDialog extends StatefulWidget {
  const _InstantStatusDialog({
    required this.record,
    required this.title,
    required this.initialStatus,
    required this.statusAction,
    this.allowStatusSelection = false,
  });

  final StatusBoardRecord record;
  final String title;
  final String initialStatus;
  final String statusAction;
  final bool allowStatusSelection;

  @override
  State<_InstantStatusDialog> createState() => _InstantStatusDialogState();
}

class _InstantStatusDialogState extends State<_InstantStatusDialog> {
  final _formKey = GlobalKey<FormState>();
  static const _statusOptions = ['대기중', '보험', '일반', '장기'];
  late String _selectedStatus;
  late final TextEditingController _customerNameController;
  late final TextEditingController _customerPhoneController;
  late final TextEditingController _pickupLocationController;
  late final TextEditingController _parkingLocationController;
  late final TextEditingController _noteController;
  late final TextEditingController _startAtController;
  late final TextEditingController _endAtController;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.initialStatus;
    _customerNameController = TextEditingController(
      text: widget.record.customerName,
    );
    _customerPhoneController = TextEditingController(
      text: widget.record.customerPhone,
    );
    _pickupLocationController = TextEditingController(
      text: widget.record.pickupLocation,
    );
    _parkingLocationController = TextEditingController(
      text: widget.record.parkingLocation,
    );
    _noteController = TextEditingController(text: widget.record.noteText);
    _startAtController = TextEditingController(text: widget.record.startAt);
    _endAtController = TextEditingController(text: widget.record.endAt);
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _pickupLocationController.dispose();
    _parkingLocationController.dispose();
    _noteController.dispose();
    _startAtController.dispose();
    _endAtController.dispose();
    super.dispose();
  }

  bool get _requiresTripFields => !_isIdleStatus(_selectedStatus);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.allowStatusSelection)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 6),
                          child: Text(
                            '차량상태',
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedStatus,
                          decoration: const InputDecoration(
                            isDense: false,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                          items: [
                            for (final status in _statusOptions)
                              DropdownMenuItem(
                                value: status,
                                child: Text(status),
                              ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _selectedStatus = value);
                          },
                        ),
                      ],
                    ),
                  ),
                _DialogTextField(
                  controller: _customerNameController,
                  label: '이용자/고객명',
                  validator: _requiresTripFields ? _requiredValidator : null,
                ),
                _DialogTextField(
                  controller: _customerPhoneController,
                  label: '고객번호',
                ),
                _DialogTextField(
                  controller: _startAtController,
                  label: '대여일시',
                  hintText: '2026-05-11 10:00',
                  validator: _requiresTripFields ? _requiredValidator : null,
                ),
                _DialogTextField(
                  controller: _endAtController,
                  label: '반납일시',
                  hintText: '2026-05-12 10:00',
                  validator: _requiresTripFields ? _requiredValidator : null,
                ),
                _DialogTextField(
                  controller: _pickupLocationController,
                  label: '배차지',
                ),
                _DialogTextField(
                  controller: _parkingLocationController,
                  label: '주차지',
                ),
                _DialogTextField(
                  controller: _noteController,
                  label: '비고',
                  maxLines: 3,
                ),
              ],
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
            final startAtRaw = _startAtController.text.trim();
            final endAtRaw = _endAtController.text.trim();
            final startAt = startAtRaw.isEmpty
                ? null
                : _tryParseDateTime(startAtRaw);
            final endAt = endAtRaw.isEmpty ? null : _tryParseDateTime(endAtRaw);
            if (_requiresTripFields && (startAt == null || endAt == null)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('대여/반납 일시 형식을 확인해 주세요.')),
              );
              return;
            }
            Navigator.of(context).pop(
              _InstantStatusFormResult(
                status: _selectedStatus,
                statusAction: widget.statusAction,
                customerName: _customerNameController.text.trim(),
                customerPhone: _customerPhoneController.text.trim(),
                startAt: startAt,
                endAt: endAt,
                pickupLocation: _pickupLocationController.text.trim(),
                parkingLocation: _pickupLocationController.text.trim().isEmpty
                    ? _parkingLocationController.text.trim()
                    : _parkingLocationController.text.trim(),
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

class _ParkingLocationDialog extends StatefulWidget {
  const _ParkingLocationDialog({required this.initialValue});

  final String initialValue;

  @override
  State<_ParkingLocationDialog> createState() => _ParkingLocationDialogState();
}

class _ParkingLocationDialogState extends State<_ParkingLocationDialog> {
  late final TextEditingController _customController;
  late final List<String> _options;
  late String _selectedValue;
  bool _showCustomInput = false;

  @override
  void initState() {
    super.initState();
    _options = [..._parkingLocationOptions];
    final initial = widget.initialValue.trim();
    final hasInitial = initial.isNotEmpty;
    final inOptions = _options.contains(initial);
    if (hasInitial && !inOptions) {
      _options.add(initial);
    }
    _selectedValue = hasInitial ? initial : _options.first;
    _showCustomInput = hasInitial && !inOptions;
    _customController = TextEditingController(
      text: _showCustomInput ? initial : '',
    );
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  void _addCustomOption() {
    final value = _customController.text.trim();
    if (value.isEmpty) return;
    setState(() {
      if (!_options.contains(value)) {
        _options.add(value);
      }
      _selectedValue = value;
      _showCustomInput = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('주차지 수정'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _selectedValue,
              decoration: const InputDecoration(labelText: '주차지'),
              items: [
                for (final option in _options)
                  DropdownMenuItem(value: option, child: Text(option)),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _selectedValue = value);
              },
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _showCustomInput = !_showCustomInput;
                      });
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('직접추가'),
                  ),
                ),
              ],
            ),
            if (_showCustomInput) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _DialogTextField(
                      controller: _customController,
                      label: '새 주차지',
                      autofocus: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: FilledButton(
                      onPressed: _addCustomOption,
                      child: const Text('추가'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_selectedValue.trim()),
          child: const Text('저장'),
        ),
      ],
    );
  }
}

class _CarManagementInfoFormResult {
  const _CarManagementInfoFormResult({
    required this.carInspectionAt,
    required this.carAgeExpiryAt,
  });

  final String carInspectionAt;
  final String carAgeExpiryAt;
}

class _CarManagementInfoDialog extends StatefulWidget {
  const _CarManagementInfoDialog({required this.record});

  final StatusBoardRecord record;

  @override
  State<_CarManagementInfoDialog> createState() =>
      _CarManagementInfoDialogState();
}

class _CarManagementInfoDialogState extends State<_CarManagementInfoDialog> {
  late final TextEditingController _registeredController;
  late final TextEditingController _inspectionController;
  late final TextEditingController _ageExpiryController;

  @override
  void initState() {
    super.initState();
    _registeredController = TextEditingController(
      text: widget.record.carRegisteredAt.isEmpty
          ? '-'
          : widget.record.carRegisteredAt,
    );
    _inspectionController = TextEditingController(
      text: widget.record.carInspectionAt,
    );
    _ageExpiryController = TextEditingController(
      text: widget.record.carAgeExpiryAt,
    );
  }

  @override
  void dispose() {
    _registeredController.dispose();
    _inspectionController.dispose();
    _ageExpiryController.dispose();
    super.dispose();
  }

  String? _validateDate(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '날짜를 입력해주세요.';
    final pattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    if (!pattern.hasMatch(trimmed)) return 'YYYY-MM-DD 형식으로 입력해주세요.';
    final parsed = DateTime.tryParse(trimmed);
    if (parsed == null) return '올바른 날짜가 아닙니다.';
    final normalized =
        '${parsed.year.toString().padLeft(4, '0')}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
    if (normalized != trimmed) return '올바른 날짜가 아닙니다.';
    return null;
  }

  void _save() {
    final inspection = _inspectionController.text.trim();
    final ageExpiry = _ageExpiryController.text.trim();
    final inspectionError = _validateDate(inspection);
    final ageExpiryError = _validateDate(ageExpiry);

    if (inspectionError != null || ageExpiryError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(inspectionError ?? ageExpiryError!)),
      );
      return;
    }

    Navigator.of(context).pop(
      _CarManagementInfoFormResult(
        carInspectionAt: inspection,
        carAgeExpiryAt: ageExpiry,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('차량 관리 정보 수정'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DialogTextField(
              controller: _registeredController,
              label: '차량등록일',
              readOnly: true,
            ),
            const SizedBox(height: 12),
            _DialogTextField(
              controller: _inspectionController,
              label: '차량검사일',
              hintText: 'YYYY-MM-DD',
              keyboardType: TextInputType.datetime,
            ),
            const SizedBox(height: 12),
            _DialogTextField(
              controller: _ageExpiryController,
              label: '차령만료일',
              hintText: 'YYYY-MM-DD',
              keyboardType: TextInputType.datetime,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(onPressed: _save, child: const Text('저장')),
      ],
    );
  }
}

class _ScheduleDetailBody extends ConsumerStatefulWidget {
  const _ScheduleDetailBody({required this.record});

  final StatusBoardRecord record;

  @override
  ConsumerState<_ScheduleDetailBody> createState() =>
      _ScheduleDetailBodyState();
}

class _ScheduleDetailBodyState extends ConsumerState<_ScheduleDetailBody> {
  bool _submitting = false;

  StatusBoardRecord get record => widget.record;

  Future<void> _runScheduleAction(Future<void> Function() action) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await action();
      if (!mounted) return;
      ref.invalidate(allStatusBoardRecordsProvider);
      ref.invalidate(allReservationsProvider);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _completeSchedule() async {
    final scheduleRowId = _extractRawRowId(record.recordId, 'schedule');
    if (scheduleRowId == null) {
      _showError('일정 row id 를 찾지 못했습니다.');
      return;
    }

    await _runScheduleAction(() async {
      await ref
          .read(supabaseOpsRepositoryProvider)
          .completeSchedule(
            scheduleRowId: scheduleRowId,
            scheduleType: record.scheduleType,
            reservationId: record.reservationId,
            carNumber: record.carNumber,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('일정완료 처리했습니다.')));
      context.pop();
    });
  }

  Future<void> _editSchedule() async {
    final scheduleRowId = _extractRawRowId(record.recordId, 'schedule');
    if (scheduleRowId == null) {
      _showError('일정 row id 를 찾지 못했습니다.');
      return;
    }

    final form = await showDialog<ScheduleEditorResult>(
      context: context,
      builder: (context) => ScheduleEditorDialog(
        title: '일정 수정',
        confirmLabel: '저장',
        initialType: record.scheduleType,
        initialScheduleAt: record.sortAt,
        initialCarNumber: record.carNumber,
        initialCarName: record.carName,
        initialLocationText: record.locationSummary,
        initialDetailText: record.detailText,
      ),
    );
    if (form == null) return;

    await _runScheduleAction(() async {
      await ref
          .read(supabaseOpsRepositoryProvider)
          .updateSchedule(
            scheduleRowId: scheduleRowId,
            scheduleType: form.scheduleType,
            scheduleAt: form.scheduleAt,
            carNumber: form.carNumber,
            carName: form.carName,
            locationText: form.locationText,
            detailText: form.detailText,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('일정을 수정했습니다.')));
    });
  }

  Future<void> _deleteSchedule() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => const _ConfirmActionDialog(
        icon: Icons.delete_outline,
        title: '일정삭제',
        message: '이 일정을 삭제합니다.',
        confirmLabel: '삭제',
        danger: true,
      ),
    );
    if (confirmed != true) return;

    final scheduleRowId = _extractRawRowId(record.recordId, 'schedule');
    if (scheduleRowId == null) {
      _showError('일정 row id 를 찾지 못했습니다.');
      return;
    }

    await _runScheduleAction(() async {
      await ref
          .read(supabaseOpsRepositoryProvider)
          .deleteSchedule(scheduleRowId: scheduleRowId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('일정을 삭제했습니다.')));
      context.pop();
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final hasPhone = hasCallablePhone(record.customerPhone);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        Text(
          record.scheduleType.isEmpty ? '일정 디테일' : record.scheduleType,
          style: textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          record.timeLabel.isEmpty ? '-' : record.timeLabel,
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            record.carNumber.isEmpty ? '차량번호 미확인' : record.carNumber,
            style: textTheme.titleSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
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
              if (_submitting) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 12),
              ],
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 4,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
                childAspectRatio: 1.05,
                children: [
                  _ActionChipButton(
                    label: '완료',
                    icon: Icons.task_alt_outlined,
                    emphasis: _ActionChipEmphasis.primary,
                    expand: true,
                    onPressed: _submitting ? null : _completeSchedule,
                  ),
                  _ActionChipButton(
                    label: '수정',
                    icon: Icons.edit_outlined,
                    expand: true,
                    onPressed: _submitting ? null : _editSchedule,
                  ),
                  if (hasPhone)
                    _ActionChipButton(
                      label: '전화',
                      icon: Icons.call_outlined,
                      expand: true,
                      onPressed: _submitting
                          ? null
                          : () => tryLaunchPhoneCall(
                              context,
                              record.customerPhone,
                            ),
                    ),
                  if (hasPhone)
                    _ActionChipButton(
                      label: '문자',
                      icon: Icons.sms_outlined,
                      expand: true,
                      onPressed: _submitting
                          ? null
                          : () => tryLaunchSms(context, record.customerPhone),
                    ),
                  _ActionChipButton(
                    label: '삭제',
                    icon: Icons.delete_outline,
                    emphasis: _ActionChipEmphasis.danger,
                    expand: true,
                    onPressed: _submitting ? null : _deleteSchedule,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: '일정 정보',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FieldBlock(
                label: '일정번호',
                value: record.scheduleId,
                emphasize: true,
              ),
              _FieldBlock(label: '일정유형', value: record.scheduleType),
              _FieldBlock(label: '일정시각', value: record.startAt),
              _FieldBlock(
                label: '차량번호',
                value: record.carNumber,
                emphasize: true,
              ),
              _FieldBlock(label: '차종', value: record.carName),
              _FieldBlock(label: '위치', value: record.locationSummary),
              _FieldBlock(
                label: '상세정보',
                value: record.detailText,
                multiline: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: '예약 연결',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (record.reservationId.isNotEmpty)
                _LinkedFieldBlock(
                  label: '예약ID',
                  value: record.reservationId,
                  enabled: true,
                  onTap: () => context.push(
                    AppRoutes.reservationDetail.replaceFirst(
                      ':reservationId',
                      Uri.encodeComponent(record.reservationId),
                    ),
                  ),
                )
              else
                const _FieldBlock(label: '예약ID', value: '연결된 예약 없음'),
              _FieldBlock(label: '외부예약번호', value: record.reservationNumber),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

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
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _FieldBlock extends StatelessWidget {
  const _FieldBlock({
    required this.label,
    required this.value,
    this.emphasize = false,
    this.multiline = false,
  });

  final String label;
  final String value;
  final bool emphasize;
  final bool multiline;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final display = value.isEmpty ? '-' : value;

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
            display,
            maxLines: multiline ? null : 2,
            overflow: multiline ? null : TextOverflow.ellipsis,
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

class _LinkedFieldBlock extends StatelessWidget {
  const _LinkedFieldBlock({
    required this.label,
    required this.value,
    required this.enabled,
    this.onTap,
  });

  final String label;
  final String value;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final display = value.isEmpty ? '-' : value;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
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
              display,
              style: textTheme.titleMedium?.copyWith(
                color: enabled ? colorScheme.primary : null,
                decoration: enabled ? TextDecoration.underline : null,
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogTextField extends StatelessWidget {
  const _DialogTextField({
    required this.controller,
    required this.label,
    this.validator,
    this.maxLines = 1,
    this.hintText,
    this.autofocus = false,
    this.readOnly = false,
    this.keyboardType,
    this.onTap,
    this.suffixIcon,
  });

  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final int maxLines;
  final String? hintText;
  final bool autofocus;
  final bool readOnly;
  final TextInputType? keyboardType;
  final VoidCallback? onTap;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        autofocus: autofocus,
        validator: validator,
        maxLines: maxLines,
        readOnly: readOnly,
        keyboardType: keyboardType,
        onTap: onTap,
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }
}

class _ConfirmActionDialog extends StatelessWidget {
  const _ConfirmActionDialog({
    required this.icon,
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final String confirmLabel;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final actionColor = danger ? const Color(0xFFB42318) : colorScheme.primary;

    return AlertDialog(
      icon: Icon(icon, color: actionColor),
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('취소'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: actionColor,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}

class _AiParserTextInputDialog extends StatefulWidget {
  const _AiParserTextInputDialog({required this.aiParserBaseUrl});

  final String aiParserBaseUrl;

  @override
  State<_AiParserTextInputDialog> createState() =>
      _AiParserTextInputDialogState();
}

class _AiParserTextInputDialogState extends State<_AiParserTextInputDialog> {
  late final TextEditingController _controller;
  bool? _isConnected;
  bool _checkingConnection = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkConnection();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkConnection() async {
    if (_checkingConnection) return;
    setState(() => _checkingConnection = true);

    try {
      final client = ReservationAiParserClient(baseUrl: widget.aiParserBaseUrl);
      final ok = await client.checkHealth();
      if (!mounted) return;
      setState(() => _isConnected = ok);
    } on ReservationAiParserException {
      if (!mounted) return;
      setState(() => _isConnected = false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isConnected = false);
    } finally {
      if (mounted) setState(() => _checkingConnection = false);
    }
  }

  Widget _buildConnectionIcon() {
    if (_checkingConnection) {
      return const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (_isConnected == true) {
      return const Icon(Icons.check_circle, color: Colors.green);
    }
    if (_isConnected == false) {
      return const Icon(Icons.error, color: Colors.redAccent);
    }
    return const Icon(Icons.help_outline);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Expanded(child: Text('AI파서 원문 입력')),
          IconButton(
            onPressed: _checkingConnection ? null : _checkConnection,
            tooltip: _isConnected == true
                ? 'AI파서 연결됨'
                : _isConnected == false
                ? 'AI파서 연결 실패 - 다시 확인'
                : 'AI파서 연결 확인',
            icon: _buildConnectionIcon(),
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: _DialogTextField(
          controller: _controller,
          label: '예약 원문',
          autofocus: true,
          maxLines: 8,
          hintText: '예약 원문을 그대로 붙여넣어 주세요.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('해석'),
        ),
      ],
    );
  }
}

class _ReservationCreateFormResult {
  const _ReservationCreateFormResult({
    required this.car,
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
    required this.imsChecked,
  });

  final StatusBoardRecord car;
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
  final bool imsChecked;
}

class _InstantStatusFormResult {
  const _InstantStatusFormResult({
    required this.status,
    required this.statusAction,
    required this.customerName,
    required this.customerPhone,
    required this.startAt,
    required this.endAt,
    required this.pickupLocation,
    required this.parkingLocation,
    required this.noteText,
  });

  final String status;
  final String statusAction;
  final String customerName;
  final String customerPhone;
  final DateTime? startAt;
  final DateTime? endAt;
  final String pickupLocation;
  final String parkingLocation;
  final String noteText;
}

String _formatEditorDateTime(DateTime value) {
  final local = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
}

DateTime? _tryParseDateTime(String value) {
  final raw = value.trim();
  if (raw.isEmpty) return null;
  return DateTime.tryParse(raw.replaceFirst(' ', 'T')) ??
      DateTime.tryParse(raw);
}

String? _requiredValidator(String? value) {
  if (value == null || value.trim().isEmpty) {
    return '필수 입력입니다.';
  }
  return null;
}

String? _dateTimeValidator(String? value) {
  if (value == null || value.trim().isEmpty) {
    return '필수 입력입니다.';
  }
  if (_tryParseDateTime(value) == null) {
    return '예: 2026-05-11 10:00';
  }
  return null;
}

String? _phoneValidator(String? value) {
  final digits = _normalizePhoneForStorage(value ?? '');
  if (digits.isEmpty) return '필수 입력입니다.';
  if (!RegExp(r'^\d{10,11}$').hasMatch(digits)) {
    return '숫자 10~11자리로 입력하세요.';
  }
  return null;
}

String? _positiveMoneyValidator(String? value) {
  final digits = _normalizeMoneyForStorage(value ?? '');
  if (digits.isEmpty) return '필수 입력입니다.';
  final amount = int.tryParse(digits);
  if (amount == null || amount <= 0) {
    return '0보다 큰 숫자로 입력하세요.';
  }
  return null;
}

String? _birthDateValidator(String? value) {
  final normalized = _normalizeBirthDateForStorage(value ?? '');
  if (normalized.isEmpty) return '필수 입력입니다.';
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(normalized);
  if (match == null) return '예: 1990-01-31';
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final parsed = DateTime(year, month, day);
  if (parsed.year != year || parsed.month != month || parsed.day != day) {
    return '실제 날짜를 입력하세요.';
  }
  return null;
}

String? _extractRawRowId(String recordId, String prefix) {
  final expected = '$prefix:';
  if (!recordId.startsWith(expected)) return null;
  return recordId.substring(expected.length);
}

String _normalizePhoneForStorage(String value) {
  return value.replaceAll(RegExp(r'\D+'), '');
}

String _normalizeMoneyForStorage(String value) {
  return value.replaceAll(RegExp(r'\D+'), '');
}

String _normalizeBirthDateForStorage(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '';

  final digits = trimmed.replaceAll(RegExp(r'\D+'), '');
  if (digits.length == 8) {
    return '${digits.substring(0, 4)}-${digits.substring(4, 6)}-${digits.substring(6, 8)}';
  }
  if (digits.length == 6) {
    final currentYearTwoDigits = DateTime.now().year % 100;
    final yy = int.tryParse(digits.substring(0, 2));
    if (yy == null) return trimmed;
    final year = yy <= currentYearTwoDigits ? 2000 + yy : 1900 + yy;
    return '$year-${digits.substring(2, 4)}-${digits.substring(4, 6)}';
  }

  return trimmed.replaceAll(RegExp(r'[./]'), '-');
}

String _normalizeEditableStatus(String status) {
  final normalized = status.trim();
  if (normalized == '대기') return '대기중';
  if (normalized == '보험' || normalized == '일반' || normalized == '장기') {
    return normalized;
  }
  return '대기중';
}

bool _isIdleStatus(String status) {
  final normalized = status.trim();
  return normalized == '대기' || normalized == '대기중';
}

bool _isInServiceStatus(String status) {
  final normalized = status.trim();
  return normalized == '보험' || normalized == '일반' || normalized == '장기';
}

bool _isTruthy(String value) {
  final raw = value.trim().toLowerCase();
  return raw == 'true' || raw == 'y' || raw == 'yes' || raw == '1';
}
