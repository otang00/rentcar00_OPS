String normalizeLoginId(String value) {
  return value.trim().toLowerCase();
}

String buildAliasEmail(String loginId) {
  final normalized = normalizeLoginId(loginId);
  return '$normalized@ops.00rentcar.local';
}
