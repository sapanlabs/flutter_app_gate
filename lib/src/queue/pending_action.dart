import 'dart:async';

/// Internal representation of an action waiting for its required gates to open.
class PendingAction {
  /// Creates a [PendingAction].
  PendingAction({
    required this.requiredGates,
    required this.action,
    this.id,
    DateTime? queuedAt,
  }) : queuedAt = queuedAt ?? DateTime.now();

  /// Optional unique identifier for duplicate deduplication.
  final String? id;

  /// Normalized set of gate names required before execution.
  final Set<String> requiredGates;

  /// The deferred callback to execute once all [requiredGates] are open.
  final FutureOr<void> Function() action;

  /// Timestamp when this action was placed into the pending queue.
  final DateTime queuedAt;

  @override
  String toString() {
    return 'PendingAction(id: $id, requiredGates: $requiredGates, queuedAt: $queuedAt)';
  }
}
