class ActionLogEntry {
  const ActionLogEntry({
    required this.actionKey,
    required this.label,
    required this.executedAt,
    required this.note,
    this.actorId = '',
    this.actorName = '',
    this.targetType = '',
    this.targetRef = '',
    this.carNumber = '',
    this.reservationId = '',
    this.reservationNumber = '',
    this.resultStatus = '',
  });

  factory ActionLogEntry.fromJson(Map<String, dynamic> json) {
    final createdAt = DateTime.tryParse(json['created_at']?.toString() ?? '');
    final actionKey = json['action_key']?.toString() ?? '';
    final actionLabel = json['action_label']?.toString().trim() ?? '';
    final messageText = json['message_text']?.toString().trim() ?? '';
    final actorName = json['actor_name']?.toString().trim() ?? '';

    return ActionLogEntry(
      actionKey: actionKey,
      label: actionLabel.isEmpty ? actionKey : actionLabel,
      executedAt: createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
      note: messageText,
      actorId: json['actor_id']?.toString() ?? '',
      actorName: actorName,
      targetType: json['target_type']?.toString() ?? '',
      targetRef: json['target_ref']?.toString() ?? '',
      carNumber: json['car_number']?.toString() ?? '',
      reservationId: json['reservation_id']?.toString() ?? '',
      reservationNumber: json['reservation_number']?.toString() ?? '',
      resultStatus: json['result_status']?.toString() ?? '',
    );
  }

  final String actionKey;
  final String label;
  final DateTime executedAt;
  final String note;
  final String actorId;
  final String actorName;
  final String targetType;
  final String targetRef;
  final String carNumber;
  final String reservationId;
  final String reservationNumber;
  final String resultStatus;

  String get actorDisplayName => actorName.isEmpty ? actorId : actorName;

  String get targetSummary {
    final parts = <String>[
      if (carNumber.trim().isNotEmpty) carNumber.trim(),
      if (reservationNumber.trim().isNotEmpty) reservationNumber.trim(),
      if (reservationId.trim().isNotEmpty) reservationId.trim(),
      if (targetRef.trim().isNotEmpty && reservationId.trim().isEmpty)
        targetRef.trim(),
    ];
    if (parts.isEmpty) return '-';
    return parts.join(' · ');
  }
}
