import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const _naverMapAppName = 'com.rentcar00.rentcar00_ops';

bool hasMappableAddress(String value) {
  final normalized = value.trim();
  return normalized.isNotEmpty && normalized != '-';
}

Future<bool> launchNaverMapSearch(String address) async {
  final query = address.trim();
  if (!hasMappableAddress(query)) return false;

  final appUri = Uri(
    scheme: 'nmap',
    host: 'search',
    queryParameters: {'query': query, 'appname': _naverMapAppName},
  );
  if (await launchUrl(appUri, mode: LaunchMode.externalApplication)) {
    return true;
  }

  final webUri = Uri.https('map.naver.com', '/p/search/$query');
  return launchUrl(webUri, mode: LaunchMode.externalApplication);
}

Future<void> tryLaunchNaverMapSearch(
  BuildContext context,
  String address,
) async {
  final ok = await launchNaverMapSearch(address);
  if (!context.mounted || ok) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('네이버지도를 열지 못했습니다.')));
}
