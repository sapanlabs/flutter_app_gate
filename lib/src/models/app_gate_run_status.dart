/// The immediate outcome of calling `AppGate.run()`.
enum AppGateRunStatus {
  /// The action executed immediately because all required gates were open.
  executed,

  /// The action was queued because one or more required gates were closed.
  queued,

  /// The action was ignored because an action with the same ID is currently pending.
  duplicateIgnored,

  /// The action was rejected (e.g., maximum queue capacity was exceeded).
  rejected,
}
