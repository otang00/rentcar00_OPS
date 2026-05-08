class StatusKeys {
  const StatusKeys._();

  static const pending = 'rc00_ops_status_pending';
  static const waitingForId = 'rc00_ops_status_waiting_for_id';
  static const waitingForAddress = 'rc00_ops_status_waiting_for_address';
  static const ready = 'rc00_ops_status_ready';
  static const readyForDispatch = 'rc00_ops_status_ready_for_dispatch';
  static const dispatchPrepared = 'rc00_ops_status_dispatch_prepared';
  static const dispatchInProgress = 'rc00_ops_status_dispatch_in_progress';
  static const pickupCompleted = 'rc00_ops_status_pickup_completed';
  static const inUse = 'rc00_ops_status_in_use';
  static const returnPreparing = 'rc00_ops_status_return_preparing';
  static const extensionReview = 'rc00_ops_status_extension_review';
  static const issueHandling = 'rc00_ops_status_issue_handling';
  static const returnDue = 'rc00_ops_status_return_due';
  static const returnInProgress = 'rc00_ops_status_return_in_progress';
  static const settlementNeeded = 'rc00_ops_status_settlement_needed';
  static const returnCompleted = 'rc00_ops_status_return_completed';
  static const hold = 'rc00_ops_status_hold';
  static const done = 'rc00_ops_status_done';
}
