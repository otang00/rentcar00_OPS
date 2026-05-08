class ActionLogEntry {
  const ActionLogEntry({
    required this.actionKey,
    required this.label,
    required this.executedAt,
    required this.note,
  });

  final String actionKey;
  final String label;
  final DateTime executedAt;
  final String note;
}
