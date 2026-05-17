class StaffAccount {
  const StaffAccount({
    required this.id,
    required this.authUserId,
    required this.loginId,
    required this.displayName,
    required this.role,
    required this.isActive,
  });

  factory StaffAccount.fromJson(Map<String, dynamic> json) {
    return StaffAccount(
      id: json['id'] as String,
      authUserId: json['auth_user_id'] as String,
      loginId: json['login_id'] as String,
      displayName: (json['display_name'] as String?)?.trim().isNotEmpty == true
          ? json['display_name'] as String
          : (json['login_id'] as String),
      role: (json['role'] as String?) ?? 'staff',
      isActive: (json['is_active'] as bool?) ?? false,
    );
  }

  final String id;
  final String authUserId;
  final String loginId;
  final String displayName;
  final String role;
  final bool isActive;

  bool get isAdmin => role.trim().toLowerCase() == 'admin';
}
