import 'package:flutter/material.dart';
import 'package:rentcar00_ops/shared/utils/ops_kst_datetime.dart';

const Set<String> koreanPublicHolidayDates2026 = {
  '2026-01-01', // 신정
  '2026-02-16', // 설날 연휴
  '2026-02-17', // 설날
  '2026-02-18', // 설날 연휴
  '2026-03-01', // 삼일절
  '2026-03-02', // 삼일절 대체공휴일
  '2026-05-01', // 근로자의 날
  '2026-05-05', // 어린이날
  '2026-05-24', // 부처님오신날
  '2026-05-25', // 부처님오신날 대체공휴일
  '2026-06-03', // 제9회 전국동시지방선거
  '2026-06-06', // 현충일
  '2026-08-15', // 광복절
  '2026-08-17', // 광복절 대체공휴일
  '2026-09-24', // 추석 연휴
  '2026-09-25', // 추석
  '2026-09-26', // 추석 연휴
  '2026-10-03', // 개천절
  '2026-10-05', // 개천절 대체공휴일
  '2026-10-09', // 한글날
  '2026-12-25', // 성탄절
};

bool isKoreanPublicHoliday(DateTime value) {
  return koreanPublicHolidayDates2026.contains(opsLocalDateKey(value));
}

String opsLocalDateKey(DateTime value) {
  return opsKstDateKey(value);
}

Color opsDateColor(DateTime value) {
  final kst = opsAsKstWallTime(value);
  if (isKoreanPublicHoliday(kst) || kst.weekday == DateTime.sunday) {
    return const Color(0xFFD32F2F);
  }
  if (kst.weekday == DateTime.saturday) {
    return const Color(0xFF1565C0);
  }
  return const Color(0xFF111827);
}
