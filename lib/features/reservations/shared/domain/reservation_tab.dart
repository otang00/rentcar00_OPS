import 'package:flutter/material.dart';
import 'package:rentcar00_ops/shared/constants/tab_keys.dart';

enum ReservationTab {
  pending(
    key: TabKeys.pending,
    label: '예약중',
    icon: Icons.event_note_outlined,
    emptyMessage: '예약 원장 기반 카드가 여기에 표시됩니다.',
  ),
  pickupToday(
    key: TabKeys.pickupToday,
    label: '배차대기',
    icon: Icons.local_shipping_outlined,
    emptyMessage: '배차 완료 전 예약과 지연/예정 경고가 여기에 표시됩니다.',
  ),
  inUse(
    key: TabKeys.inUse,
    label: '배차중',
    icon: Icons.drive_eta_outlined,
    emptyMessage: '이용 중 차량과 반납 임박 경고가 여기에 표시됩니다.',
  ),
  returnDue(
    key: TabKeys.returnDue,
    label: '반납일',
    icon: Icons.assignment_return_outlined,
    emptyMessage: '당일 반납 처리 대상이 여기에 표시됩니다.',
  ),
  completed(
    key: TabKeys.completed,
    label: '완료',
    icon: Icons.task_alt_outlined,
    emptyMessage: '반납 완료 후 7일 이내 기록이 여기에 표시됩니다.',
  );

  const ReservationTab({
    required this.key,
    required this.label,
    required this.icon,
    required this.emptyMessage,
  });

  final String key;
  final String label;
  final IconData icon;
  final String emptyMessage;
}
