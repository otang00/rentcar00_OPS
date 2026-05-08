class SyncRunEntry {
  const SyncRunEntry({
    required this.id,
    required this.title,
    required this.status,
    required this.note,
    required this.executedAt,
  });

  final String id;
  final String title;
  final String status;
  final String note;
  final DateTime executedAt;
}
