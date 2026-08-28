import 'app_gate_status.dart';

/// An immutable event describing state changes, action lifecycle transitions,
/// and errors emitted by [AppGate].
class AppGateEvent {
  /// Creates an [AppGateEvent].
  AppGateEvent({
    required this.status,
    this.gate,
    this.actionId,
    Set<String>? requiredGates,
    DateTime? timestamp,
    this.error,
    this.stackTrace,
  })  : requiredGates = requiredGates != null
            ? Set<String>.unmodifiable(requiredGates)
            : const <String>{},
        timestamp = timestamp ?? DateTime.now();

  /// The status classification of this event.
  final AppGateStatus status;

  /// The name of the gate associated with this event, if applicable.
  final String? gate;

  /// The action identifier associated with this event, if provided.
  final String? actionId;

  /// The set of required gates associated with the action, if applicable.
  final Set<String> requiredGates;

  /// The exact timestamp when the event occurred.
  final DateTime timestamp;

  /// The error or exception object if this is a failure or error event.
  final Object? error;

  /// The stack trace associated with [error], if any.
  final StackTrace? stackTrace;

  @override
  String toString() {
    return 'AppGateEvent('
        'status: $status, '
        'gate: $gate, '
        'actionId: $actionId, '
        'requiredGates: $requiredGates, '
        'timestamp: $timestamp, '
        'error: $error'
        ')';
  }
}
