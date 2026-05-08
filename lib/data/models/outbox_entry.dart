class OutboxEntry {
  const OutboxEntry({
    required this.id,
    required this.reservationId,
    required this.actionKey,
    required this.sheetName,
    required this.previewLines,
    required this.createdAt,
  });

  final String id;
  final String reservationId;
  final String actionKey;
  final String sheetName;
  final List<String> previewLines;
  final DateTime createdAt;
}
