import 'package:flutter/services.dart';

class OpsPhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final formatted = opsFormatPhoneInput(newValue.text);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class OpsBirthDateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D+'), '');
    final clipped = digits.length > 8 ? digits.substring(0, 8) : digits;
    final formatted = opsFormatBirthDateDigits(clipped);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class OpsDateTimeInputFormatter extends TextInputFormatter {
  OpsDateTimeInputFormatter({required this.defaultYear});

  final int defaultYear;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final formatted = opsFormatDateTimeInput(
      newValue.text,
      defaultYear: defaultYear,
    );
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

String opsYearPrefix([DateTime? value]) {
  return '${(value ?? DateTime.now()).year}-';
}

String opsFormatEditorDateTime(DateTime value) {
  final local = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
}

String opsFormatPhoneInput(String value) {
  final digits = value.replaceAll(RegExp(r'\D+'), '');
  final clipped = digits.length > 11 ? digits.substring(0, 11) : digits;
  if (clipped.isEmpty) return '';
  if (clipped.startsWith('02')) {
    if (clipped.length <= 2) {
      return clipped;
    }
    if (clipped.length <= 6) {
      return '${clipped.substring(0, 2)}-${clipped.substring(2)}';
    }
    return '${clipped.substring(0, 2)}-${clipped.substring(2, clipped.length - 4)}-${clipped.substring(clipped.length - 4)}';
  }
  if (clipped.length == 8) {
    return '${clipped.substring(0, 4)}-${clipped.substring(4)}';
  }
  if (clipped.length <= 3) {
    return clipped;
  }
  if (clipped.length <= 7) {
    return '${clipped.substring(0, 3)}-${clipped.substring(3)}';
  }
  if (clipped.length <= 10) {
    return '${clipped.substring(0, 3)}-${clipped.substring(3, 6)}-${clipped.substring(6)}';
  }
  return '${clipped.substring(0, 3)}-${clipped.substring(3, 7)}-${clipped.substring(7)}';
}

String opsNormalizePhoneForStorage(String value) {
  return value.replaceAll(RegExp(r'\D+'), '');
}

bool opsIsValidPhoneForStorage(String value) {
  final digits = opsNormalizePhoneForStorage(value);
  return RegExp(r'^(\d{8}|\d{10}|\d{11})$').hasMatch(digits);
}

String opsFormatBirthDateInput(String value) {
  final digits = value.replaceAll(RegExp(r'\D+'), '');
  if (digits.isEmpty) return value.trim();
  final clipped = digits.length > 8 ? digits.substring(0, 8) : digits;
  return opsFormatBirthDateDigits(clipped);
}

String opsFormatBirthDateDigits(String digits) {
  if (digits.length <= 4) return digits;
  if (digits.length <= 6) {
    return '${digits.substring(0, 4)}-${digits.substring(4)}';
  }
  return '${digits.substring(0, 4)}-${digits.substring(4, 6)}-${digits.substring(6)}';
}

String opsNormalizeBirthDateForStorage(String value) {
  final digits = value.replaceAll(RegExp(r'\D+'), '');
  if (digits.length != 8) return value.trim().replaceAll(RegExp(r'[./]'), '-');
  return opsFormatBirthDateDigits(digits);
}

bool opsIsCompleteBirthDate(String value) {
  final normalized = opsNormalizeBirthDateForStorage(value);
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(normalized);
  if (match == null) return false;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final parsed = DateTime(year, month, day);
  return parsed.year == year && parsed.month == month && parsed.day == day;
}

String opsFormatDateTimeInput(String value, {required int defaultYear}) {
  final year = defaultYear.toString().padLeft(4, '0');
  final digits = value.replaceAll(RegExp(r'\D+'), '');
  final rest = digits.startsWith(year) ? digits.substring(4) : digits;
  final clipped = rest.length > 8 ? rest.substring(0, 8) : rest;
  if (clipped.isEmpty) return '$year-';
  if (clipped.length <= 2) return '$year-$clipped';
  if (clipped.length <= 4) {
    return '$year-${clipped.substring(0, 2)}-${clipped.substring(2)}';
  }
  if (clipped.length <= 6) {
    return '$year-${clipped.substring(0, 2)}-${clipped.substring(2, 4)} ${clipped.substring(4)}';
  }
  return '$year-${clipped.substring(0, 2)}-${clipped.substring(2, 4)} ${clipped.substring(4, 6)}:${clipped.substring(6)}';
}

DateTime? opsTryParseEditorDateTime(
  String value, {
  DateTime? fallback,
  int defaultHour = 10,
  int defaultMinute = 0,
}) {
  final raw = value.trim();
  if (raw.isEmpty || RegExp(r'^\d{4}-$').hasMatch(raw)) {
    return null;
  }
  final digits = raw.replaceAll(RegExp(r'\D+'), '');
  if (digits.length != 8 && digits.length != 10 && digits.length != 12) {
    final parsed = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
    if (parsed != null) return parsed;
    return null;
  }

  final year = int.tryParse(digits.substring(0, 4));
  final month = int.tryParse(digits.substring(4, 6));
  final day = int.tryParse(digits.substring(6, 8));
  if (year == null || month == null || day == null) return null;

  final hour = digits.length >= 10
      ? int.tryParse(digits.substring(8, 10))
      : fallback?.hour ?? defaultHour;
  final minute = digits.length == 12
      ? int.tryParse(digits.substring(10, 12))
      : fallback?.minute ?? defaultMinute;
  if (hour == null || minute == null) return null;

  final result = DateTime(year, month, day, hour, minute);
  if (result.year != year ||
      result.month != month ||
      result.day != day ||
      result.hour != hour ||
      result.minute != minute) {
    return null;
  }
  return result;
}
