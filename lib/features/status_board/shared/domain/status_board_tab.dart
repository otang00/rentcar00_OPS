import 'package:flutter/material.dart';

enum StatusBoardTab {
  idle(
    label: '대기',
    icon: Icons.directions_car_outlined,
    emptyMessage: '대기 차량이 여기에 표시됩니다.',
  ),
  insurance(
    label: '보험',
    icon: Icons.health_and_safety_outlined,
    emptyMessage: '보험 차량이 여기에 표시됩니다.',
  ),
  general(
    label: '일반',
    icon: Icons.assignment_outlined,
    emptyMessage: '일반 배차 차량이 여기에 표시됩니다.',
  ),
  longTerm(
    label: '장기',
    icon: Icons.event_repeat_outlined,
    emptyMessage: '장기 차량이 여기에 표시됩니다.',
  ),
  schedule(
    label: '일정',
    icon: Icons.calendar_month_outlined,
    emptyMessage: '진행 중 일정이 여기에 표시됩니다.',
  );

  const StatusBoardTab({
    required this.label,
    required this.icon,
    required this.emptyMessage,
  });

  final String label;
  final IconData icon;
  final String emptyMessage;
}
