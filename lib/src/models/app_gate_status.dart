/// Lifecycle and operational status events emitted by [AppGate].
enum AppGateStatus {
  /// A named gate was opened.
  gateOpened,

  /// A named gate was closed.
  gateClosed,

  /// An action was deferred and placed into the pending queue.
  queued,

  /// An action has begun executing.
  executing,

  /// An action completed successfully.
  completed,

  /// An action threw an exception during execution.
  failed,

  /// An action with an already-pending ID was safely ignored.
  duplicateIgnored,

  /// An action was rejected because the pending queue capacity was exceeded.
  queueFull,

  /// The gate state and pending queues were cleared.
  reset,

  /// The [AppGate] instance was disposed.
  disposed,
}
