import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

String normalizePhoneForLaunch(String value) {
  final digits = value.replaceAll(RegExp(r'[^0-9+]'), '');
  return digits.trim();
}

bool hasCallablePhone(String value) {
  final normalized = normalizePhoneForLaunch(value);
  return normalized.isNotEmpty && normalized.replaceAll('+', '').isNotEmpty;
}

Future<bool> launchPhoneCall(String phone) async {
  final normalized = normalizePhoneForLaunch(phone);
  if (normalized.isEmpty) return false;
  final uri = Uri(scheme: 'tel', path: normalized);
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

Future<bool> launchSms(String phone) async {
  final normalized = normalizePhoneForLaunch(phone);
  if (normalized.isEmpty) return false;
  final uri = Uri(scheme: 'sms', path: normalized);
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

Future<void> tryLaunchPhoneCall(
  BuildContext context,
  String phone,
) async {
  final ok = await launchPhoneCall(phone);
  if (!context.mounted || ok) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('전화 앱을 열지 못했습니다.')),
  );
}

Future<void> tryLaunchSms(
  BuildContext context,
  String phone,
) async {
  final ok = await launchSms(phone);
  if (!context.mounted || ok) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('문자 앱을 열지 못했습니다.')),
  );
}
