class AuthFlowException implements Exception {
  const AuthFlowException(this.message);

  final String message;

  @override
  String toString() => message;
}

class StaffAccountNotApprovedException extends AuthFlowException {
  const StaffAccountNotApprovedException() : super('승인되지 않은 계정입니다.');
}

class StaffAccountInactiveException extends AuthFlowException {
  const StaffAccountInactiveException() : super('비활성화된 계정입니다.');
}
