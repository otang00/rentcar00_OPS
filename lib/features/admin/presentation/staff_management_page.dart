import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentcar00_ops/features/admin/domain/admin_staff_account.dart';
import 'package:rentcar00_ops/features/admin/shared/admin_staff_providers.dart';
import 'package:rentcar00_ops/features/auth/shared/auth_providers.dart';

class StaffManagementPage extends ConsumerWidget {
  const StaffManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentStaffAsync = ref.watch(currentStaffAccountProvider);
    final staffAccountsAsync = ref.watch(adminStaffAccountsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('직원관리')),
      body: currentStaffAsync.when(
        data: (currentStaff) {
          if (currentStaff?.isAdmin != true) {
            return const _AdminOnlyView();
          }

          return staffAccountsAsync.when(
            data: (staffAccounts) {
              if (staffAccounts.isEmpty) {
                return const Center(child: Text('등록된 직원 계정이 없습니다.'));
              }
              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(adminStaffAccountsProvider);
                  await ref.read(adminStaffAccountsProvider.future);
                },
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: staffAccounts.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final staff = staffAccounts[index];
                    return _StaffAccountCard(staff: staff);
                  },
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('직원 목록을 불러오지 못했습니다.\n$error'),
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('관리자 권한을 확인하지 못했습니다.\n$error'),
          ),
        ),
      ),
    );
  }
}

class _AdminOnlyView extends StatelessWidget {
  const _AdminOnlyView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text('관리자만 접근할 수 있습니다.', textAlign: TextAlign.center),
      ),
    );
  }
}

class _StaffAccountCard extends ConsumerStatefulWidget {
  const _StaffAccountCard({required this.staff});

  final AdminStaffAccount staff;

  @override
  ConsumerState<_StaffAccountCard> createState() => _StaffAccountCardState();
}

class _StaffAccountCardState extends ConsumerState<_StaffAccountCard> {
  bool _passwordVisible = false;

  @override
  Widget build(BuildContext context) {
    final staff = widget.staff;
    final colorScheme = Theme.of(context).colorScheme;
    final password = staff.adminVisiblePassword.trim();
    final passwordText = password.isEmpty
        ? '미등록'
        : (_passwordVisible ? password : '••••••');

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: staff.isAdmin
                      ? colorScheme.primaryContainer
                      : colorScheme.surfaceContainerHighest,
                  child: Icon(
                    staff.isAdmin
                        ? Icons.admin_panel_settings_outlined
                        : Icons.person_outline,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        staff.displayName,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        staff.loginId,
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                _StatusChip(
                  label: staff.isActive ? '활성' : '비활성',
                  color: staff.isActive ? Colors.green : Colors.grey,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _InfoRow(label: '권한', value: staff.isAdmin ? '관리자' : '스태프'),
            _InfoRow(
              label: '전화번호',
              value: staff.phoneNumber.isEmpty ? '-' : staff.phoneNumber,
            ),
            _InfoRow(
              label: '마지막활동',
              value: _formatDateTime(staff.lastActivityAt),
            ),
            _InfoRow(label: '위치', value: _formatLocation(staff)),
            Row(
              children: [
                const SizedBox(width: 92, child: Text('비밀번호')),
                Expanded(
                  child: Text(
                    passwordText,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  tooltip: _passwordVisible ? '비밀번호 숨기기' : '비밀번호 보기',
                  onPressed: password.isEmpty
                      ? null
                      : () => setState(
                          () => _passwordVisible = !_passwordVisible,
                        ),
                  icon: Icon(
                    _passwordVisible
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showEditDialog(context, ref, staff),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('수정'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showPasswordDialog(context, ref, staff),
                    icon: const Icon(Icons.password_outlined),
                    label: const Text('비밀번호'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value.isEmpty ? '-' : value)),
        ],
      ),
    );
  }
}

Future<void> _showEditDialog(
  BuildContext context,
  WidgetRef ref,
  AdminStaffAccount staff,
) async {
  final nameController = TextEditingController(text: staff.displayName);
  final phoneController = TextEditingController(text: staff.phoneNumber);
  var role = staff.isAdmin ? 'admin' : 'staff';
  var isActive = staff.isActive;

  final result = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text('${staff.loginId} 수정'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: '직원 이름'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: '전화번호'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: role,
                decoration: const InputDecoration(labelText: '권한'),
                items: const [
                  DropdownMenuItem(value: 'admin', child: Text('관리자')),
                  DropdownMenuItem(value: 'staff', child: Text('스태프')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => role = value);
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: isActive,
                title: const Text('활성 계정'),
                onChanged: (value) => setState(() => isActive = value),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('저장'),
          ),
        ],
      ),
    ),
  );

  final displayName = nameController.text;
  final phoneNumber = phoneController.text;
  nameController.dispose();
  phoneController.dispose();
  if (result != true || !context.mounted) return;

  try {
    await ref
        .read(adminStaffRepositoryProvider)
        .updateStaffAccount(
          staffAccountId: staff.id,
          displayName: displayName,
          phoneNumber: phoneNumber,
          role: role,
          isActive: isActive,
        );
    ref.invalidate(adminStaffAccountsProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('직원 정보를 저장했습니다.')));
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('직원 정보 저장 실패\n$error')));
  }
}

Future<void> _showPasswordDialog(
  BuildContext context,
  WidgetRef ref,
  AdminStaffAccount staff,
) async {
  final passwordController = TextEditingController(
    text: staff.adminVisiblePassword.trim().isEmpty
        ? _randomSixDigitPassword()
        : staff.adminVisiblePassword.trim(),
  );

  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('${staff.loginId} 비밀번호'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: passwordController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            decoration: const InputDecoration(labelText: '표시용 비밀번호 6자리'),
          ),
          const SizedBox(height: 10),
          const Text(
            '현재 단계에서는 관리자 화면 표시용 값입니다. Auth 실제 비밀번호 변경은 서버 관리자 API 연결 후 동기화합니다.',
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('저장'),
        ),
      ],
    ),
  );

  final password = passwordController.text.trim();
  passwordController.dispose();
  if (result != true || !context.mounted) return;
  if (!RegExp(r'^\d{6}$').hasMatch(password)) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('비밀번호는 숫자 6자리여야 합니다.')));
    return;
  }

  try {
    await ref
        .read(adminStaffRepositoryProvider)
        .upsertAdminVisiblePassword(
          staffAccountId: staff.id,
          password: password,
        );
    ref.invalidate(adminStaffAccountsProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('표시용 비밀번호를 저장했습니다.')));
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('비밀번호 저장 실패\n$error')));
  }
}

String _formatDateTime(DateTime? value) {
  if (value == null) return '-';
  final local = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
}

String _formatLocation(AdminStaffAccount staff) {
  if (staff.lastLocationText.trim().isNotEmpty) {
    return staff.lastLocationText.trim();
  }
  if (staff.lastLat != null && staff.lastLng != null) {
    return '${staff.lastLat}, ${staff.lastLng}';
  }
  return '-';
}

String _randomSixDigitPassword() {
  final random = Random.secure();
  return List.generate(6, (_) => random.nextInt(10).toString()).join();
}
