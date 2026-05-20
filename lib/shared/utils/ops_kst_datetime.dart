const Duration opsKstOffset = Duration(hours: 9);

DateTime opsKstNow() {
  final kst = DateTime.now().toUtc().add(opsKstOffset);
  return DateTime(
    kst.year,
    kst.month,
    kst.day,
    kst.hour,
    kst.minute,
    kst.second,
  );
}

DateTime opsKstToday() {
  final now = opsKstNow();
  return DateTime(now.year, now.month, now.day);
}

DateTime opsKstDayFloor(DateTime value) {
  final kst = opsAsKstWallTime(value);
  return DateTime(kst.year, kst.month, kst.day);
}

DateTime opsAsKstWallTime(DateTime value) {
  final kst = value.toUtc().add(opsKstOffset);
  return DateTime(
    kst.year,
    kst.month,
    kst.day,
    kst.hour,
    kst.minute,
    kst.second,
  );
}

DateTime? opsParseKstDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return opsAsKstWallTime(value);

  var raw = value.toString().trim();
  if (raw.isEmpty) return null;
  raw = raw.replaceAll(' ', ' ');
  raw = raw.replaceAll(RegExp(r'\s+'), ' ');
  raw = raw.replaceAll('/', '-').replaceAll('.', '-');
  raw = raw.replaceAll(RegExp(r'-+'), '-');
  raw = raw.replaceAll(RegExp(r'-$'), '');

  if (_hasZone(raw)) {
    final parsed = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
    return parsed == null ? null : opsAsKstWallTime(parsed);
  }

  final match = RegExp(
    r'^(\d{4})-(\d{1,2})-(\d{1,2})(?:[ T](\d{1,2}):(\d{1,2})(?::(\d{1,2}))?)?$',
  ).firstMatch(raw);
  if (match == null) return null;

  final year = int.tryParse(match.group(1)!);
  final month = int.tryParse(match.group(2)!);
  final day = int.tryParse(match.group(3)!);
  final hour = int.tryParse(match.group(4) ?? '0');
  final minute = int.tryParse(match.group(5) ?? '0');
  final second = int.tryParse(match.group(6) ?? '0');
  if (year == null ||
      month == null ||
      day == null ||
      hour == null ||
      minute == null ||
      second == null) {
    return null;
  }

  final parsed = DateTime(year, month, day, hour, minute, second);
  if (parsed.year != year ||
      parsed.month != month ||
      parsed.day != day ||
      parsed.hour != hour ||
      parsed.minute != minute ||
      parsed.second != second) {
    return null;
  }
  return parsed;
}

String opsKstToDbTimestamp(DateTime value) {
  final utc = DateTime.utc(
    value.year,
    value.month,
    value.day,
    value.hour,
    value.minute,
    value.second,
  ).subtract(opsKstOffset);
  return utc.toIso8601String();
}

String opsFormatKstDateTime(DateTime value) {
  final kst = opsAsKstWallTime(value);
  return '${kst.year}-${_two(kst.month)}-${_two(kst.day)} '
      '${_two(kst.hour)}:${_two(kst.minute)}';
}

String opsFormatKstDate(DateTime value) {
  final kst = opsAsKstWallTime(value);
  return '${kst.year}-${_two(kst.month)}-${_two(kst.day)}';
}

String opsKstDateKey(DateTime value) => opsFormatKstDate(value);

String opsFormatKstCompactDateWithWeekday(DateTime value) {
  final kst = opsAsKstWallTime(value);
  final yy = (kst.year % 100).toString().padLeft(2, '0');
  return '$yy.${_two(kst.month)}.${_two(kst.day)}(${opsKoreanWeekday(kst)})';
}

String opsFormatKstTime(DateTime value) {
  final kst = opsAsKstWallTime(value);
  return '${_two(kst.hour)}:${_two(kst.minute)}';
}

String opsKoreanWeekday(DateTime value) {
  const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
  return weekdays[value.weekday - 1];
}

bool _hasZone(String value) {
  return RegExp(r'(?:Z|[+-]\d{2}:?\d{2})$').hasMatch(value);
}

String _two(int n) => n.toString().padLeft(2, '0');
