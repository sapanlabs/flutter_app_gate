/// Configuration options for [AppGate].
class AppGateConfig {
  /// Creates an [AppGateConfig].
  ///
  /// [maxPendingActions] must be greater than zero. Defaults to `1000`.
  const AppGateConfig({
    this.maxPendingActions = 1000,
  }) : assert(maxPendingActions > 0,
            'maxPendingActions must be greater than zero.');

  /// The maximum number of actions that can be held in the pending queue simultaneously.
  final int maxPendingActions;
}
