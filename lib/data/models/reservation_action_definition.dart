class ReservationActionDefinition {
  const ReservationActionDefinition({
    required this.key,
    required this.label,
    required this.description,
    this.createsOutbox = false,
  });

  final String key;
  final String label;
  final String description;
  final bool createsOutbox;
}
