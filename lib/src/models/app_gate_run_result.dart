import 'app_gate_run_status.dart';

/// The result returned when an action is submitted via `AppGate.run()`.
class AppGateRunResult {
  /// Creates an [AppGateRunResult].
  AppGateRunResult({
    required this.status,
    this.actionId,
    Set<String>? requiredGates,
    this.error,
    this.stackTrace,
  }) : requiredGates = requiredGates != null
            ? Set<String>.unmodifiable(requiredGates)
            : const <String>{};

  /// The immediate outcome of submitting the action to [AppGate].
  final AppGateRunStatus status;

  /// The action identifier, if one was provided.
  final String? actionId;

  /// The set of gates required by this action.
  final Set<String> requiredGates;

  /// The error or exception object if immediate execution threw an error.
  final Object? error;

  /// The stack trace associated with [error], if any.
  final StackTrace? stackTrace;

  /// Returns `true` if the action executed immediately.
  bool get isExecuted => status == AppGateRunStatus.executed;

  /// Returns `true` if the action was queued waiting for closed gates to open.
  bool get isQueued => status == AppGateRunStatus.queued;

  /// Returns `true` if the action was ignored because an action with the same ID was already pending.
  bool get isDuplicateIgnored => status == AppGateRunStatus.duplicateIgnored;

  /// Returns `true` if the action was rejected (e.g. maximum queue capacity reached).
  bool get isRejected => status == AppGateRunStatus.rejected;

  /// Returns `true` if immediate execution resulted in an error.
  bool get hasError => error != null;

  @override
  String toString() {
    return 'AppGateRunResult('
        'status: $status, '
        'actionId: $actionId, '
        'requiredGates: $requiredGates, '
        'error: $error'
        ')';
  }
}
