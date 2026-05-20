class AdminStaffAccount {
  const AdminStaffAccount({
    required this.id,
    required this.authUserId,
    required this.loginId,
    required this.displayName,
    required this.role,
    required this.isActive,
    required this.phoneNumber,
    required this.lastActivityAt,
    required this.lastLocationText,
    required this.lastLat,
    required this.lastLng,
    required this.adminVisiblePassword,
  });

  factory AdminStaffAccount.fromJson(
    Map<String, dynamic> json, {
    String adminVisiblePassword = '',
  }) {
    return AdminStaffAccount(
      id: json['id'] as String,
      authUserId: json['auth_user_id'] as String,
      loginId: json['login_id'] as String,
      displayName: (json['display_name'] as String?)?.trim().isNotEmpty == true
          ? json['display_name'] as String
          : (json['login_id'] as String),
      role: (json['role'] as String?) ?? 'staff',
      isActive: (json['is_active'] as bool?) ?? false,
      phoneNumber: (json['phone_number'] as String?) ?? '',
      lastActivityAt: DateTime.tryParse(
        (json['last_activity_at'] ?? json['last_login_at'] ?? '').toString(),
      ),
      lastLocationText: (json['last_location_text'] as String?) ?? '',
      lastLat: (json['last_lat'] as num?)?.toDouble(),
      lastLng: (json['last_lng'] as num?)?.toDouble(),
      adminVisiblePassword: adminVisiblePassword,
    );
  }

  final String id;
  final String authUserId;
  final String loginId;
  final String displayName;
  final String role;
  final bool isActive;
  final String phoneNumber;
  final DateTime? lastActivityAt;
  final String lastLocationText;
  final double? lastLat;
  final double? lastLng;
  final String adminVisiblePassword;

  bool get isAdmin => role.trim().toLowerCase() == 'admin';
}
