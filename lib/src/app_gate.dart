import 'dart:async';

import 'config/app_gate_config.dart';
import 'errors/app_gate_exception.dart';
import 'models/app_gate_event.dart';
import 'models/app_gate_run_result.dart';
import 'models/app_gate_run_status.dart';
import 'models/app_gate_status.dart';
import 'queue/pending_action.dart';

/// Coordinates and defers actions until one or more named gates are open.
///
/// [AppGate] is concurrency-safe, has zero third-party dependencies, and
/// ensures non-blocking FIFO queue execution for all eligible actions.
class AppGate {
  /// Creates an [AppGate] instance with optional [config] and [onError] handler.
  AppGate({
    AppGateConfig? config,
    AppGateErrorHandler? onError,
  })  : config = config ?? const AppGateConfig(),
        _onError = onError;

  /// The configuration applied to this [AppGate] instance.
  final AppGateConfig config;

  final AppGateErrorHandler? _onError;
  final Set<String> _openGates = <String>{};
  final List<PendingAction> _pendingQueue = <PendingAction>[];
  final Set<String> _pendingIds = <String>{};
  final StreamController<AppGateEvent> _eventController =
      StreamController<AppGateEvent>.broadcast();

  bool _isDisposed = false;
  bool _isProcessing = false;
  bool _needsReprocess = false;
  Completer<void>? _activeProcessingCompleter;

  /// Stream of all status changes, lifecycle events, and errors.
  Stream<AppGateEvent> get events => _eventController.stream;

  /// Whether this [AppGate] instance has been disposed.
  bool get isDisposed => _isDisposed;

  /// The current number of actions waiting in the pending queue.
  int get pendingCount => _pendingQueue.length;

  /// An unmodifiable view of all currently open gate names.
  Set<String> get openGates => Set<String>.unmodifiable(_openGates);

  /// Opens the gate with the given [gate] name.
  ///
  /// Opening a gate triggers immediate processing of any pending actions
  /// that have all their required gates open.
  ///
  /// Throws [AppGateDisposedException] if disposed.
  /// Throws [AppGateInvalidGateException] if [gate] is empty or whitespace.
  void open(String gate) {
    _checkNotDisposed();
    final name = _normalizeGateName(gate);
    if (_openGates.add(name)) {
      _emitEvent(
        AppGateEvent(
          status: AppGateStatus.gateOpened,
          gate: name,
        ),
      );
      unawaited(processPendingActions());
    }
  }

  /// Closes the gate with the given [gate] name.
  ///
  /// Closing a gate prevents pending actions requiring this gate from running
  /// until it is reopened.
  ///
  /// Throws [AppGateDisposedException] if disposed.
  /// Throws [AppGateInvalidGateException] if [gate] is empty or whitespace.
  void close(String gate) {
    _checkNotDisposed();
    final name = _normalizeGateName(gate);
    if (_openGates.remove(name)) {
      _emitEvent(
        AppGateEvent(
          status: AppGateStatus.gateClosed,
          gate: name,
        ),
      );
    }
  }

  /// Returns `true` if the gate with the given [gate] name is currently open.
  ///
  /// Throws [AppGateDisposedException] if disposed.
  /// Throws [AppGateInvalidGateException] if [gate] is empty or whitespace.
  bool isOpen(String gate) {
    _checkNotDisposed();
    final name = _normalizeGateName(gate);
    return _openGates.contains(name);
  }

  /// Returns `true` if all specified [gates] are currently open.
  ///
  /// If [gates] is empty, returns `true`.
  ///
  /// Throws [AppGateDisposedException] if disposed.
  /// Throws [AppGateInvalidGateException] if any gate name is empty or whitespace.
  bool areOpen(Iterable<String> gates) {
    _checkNotDisposed();
    final normalized = _normalizeGateNames(gates);
    return _areOpenNormalized(normalized);
  }

  /// Submits an [action] to be executed immediately or deferred until all [requires] gates are open.
  ///
  /// - If all [requires] gates are open, [action] executes immediately and returns
  ///   an [AppGateRunResult] with status [AppGateRunStatus.executed].
  /// - If any required gate is closed, [action] is added to the pending queue and returns
  ///   an [AppGateRunResult] with status [AppGateRunStatus.queued].
  /// - If [id] is provided and an action with the same ID is already pending, the new action is
  ///   ignored and returns an [AppGateRunResult] with status [AppGateRunStatus.duplicateIgnored].
  /// - If the queue is at maximum capacity when attempting to queue, emits [AppGateStatus.queueFull],
  ///   calls [onError] if configured, and throws [AppGateQueueFullException].
  ///
  /// Throws [AppGateDisposedException] if disposed.
  /// Throws [AppGateInvalidGateException] if any gate name is empty or whitespace.
  Future<AppGateRunResult> run({
    String? id,
    required Iterable<String> requires,
    required FutureOr<void> Function() action,
  }) async {
    _checkNotDisposed();
    final normalizedRequires = _normalizeGateNames(requires);

    if (id != null && _pendingIds.contains(id)) {
      _emitEvent(
        AppGateEvent(
          status: AppGateStatus.duplicateIgnored,
          actionId: id,
          requiredGates: normalizedRequires,
        ),
      );
      return AppGateRunResult(
        status: AppGateRunStatus.duplicateIgnored,
        actionId: id,
        requiredGates: normalizedRequires,
      );
    }

    if (_areOpenNormalized(normalizedRequires)) {
      final error = await _executeAction(
        action: action,
        actionId: id,
        requiredGates: normalizedRequires,
      );
      return AppGateRunResult(
        status: AppGateRunStatus.executed,
        actionId: id,
        requiredGates: normalizedRequires,
        error: error,
      );
    }

    if (_pendingQueue.length >= config.maxPendingActions) {
      final exception = AppGateQueueFullException(
        config.maxPendingActions,
        actionId: id,
      );
      _emitEvent(
        AppGateEvent(
          status: AppGateStatus.queueFull,
          actionId: id,
          requiredGates: normalizedRequires,
          error: exception,
        ),
      );
      _onError?.call(exception);
      throw exception;
    }

    final pendingItem = PendingAction(
      id: id,
      requiredGates: normalizedRequires,
      action: action,
    );
    _pendingQueue.add(pendingItem);
    if (id != null) {
      _pendingIds.add(id);
    }

    _emitEvent(
      AppGateEvent(
        status: AppGateStatus.queued,
        actionId: id,
        requiredGates: normalizedRequires,
      ),
    );

    return AppGateRunResult(
      status: AppGateRunStatus.queued,
      actionId: id,
      requiredGates: normalizedRequires,
    );
  }

  /// Processes all pending actions whose required gates are currently open.
  ///
  /// This method is concurrency-safe and re-entrant. If processing is already active,
  /// this method registers a re-process request and completes when the active processing cycle finishes.
  ///
  /// Throws [AppGateDisposedException] if disposed.
  Future<void> processPendingActions() async {
    _checkNotDisposed();

    if (_isProcessing) {
      _needsReprocess = true;
      return _activeProcessingCompleter?.future ?? Future<void>.value();
    }

    _isProcessing = true;
    final completer = Completer<void>();
    _activeProcessingCompleter = completer;

    try {
      while (!_isDisposed) {
        _needsReprocess = false;
        int eligibleIndex = -1;

        for (int i = 0; i < _pendingQueue.length; i++) {
          if (_areOpenNormalized(_pendingQueue[i].requiredGates)) {
            eligibleIndex = i;
            break;
          }
        }

        if (eligibleIndex != -1) {
          final item = _pendingQueue.removeAt(eligibleIndex);
          if (item.id != null) {
            _pendingIds.remove(item.id);
          }

          await _executeAction(
            action: item.action,
            actionId: item.id,
            requiredGates: item.requiredGates,
          );
        } else {
          if (!_needsReprocess) {
            break;
          }
        }
      }
    } finally {
      _isProcessing = false;
      _activeProcessingCompleter = null;
      if (!completer.isCompleted) {
        completer.complete();
      }
    }
  }

  /// Clears all open gates, pending actions, and pending IDs without disposing this instance.
  ///
  /// The instance remains fully functional and reusable after resetting.
  ///
  /// Throws [AppGateDisposedException] if disposed.
  void reset() {
    _checkNotDisposed();
    _openGates.clear();
    _pendingQueue.clear();
    _pendingIds.clear();
    _emitEvent(
      AppGateEvent(
        status: AppGateStatus.reset,
      ),
    );
  }

  /// Disposes this [AppGate] instance, releasing resources and closing the event stream.
  ///
  /// Subsequent calls to mutate or execute via this instance will throw [AppGateDisposedException].
  /// Calling [dispose] multiple times is safe and idempotent.
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _openGates.clear();
    _pendingQueue.clear();
    _pendingIds.clear();

    _emitEvent(
      AppGateEvent(
        status: AppGateStatus.disposed,
      ),
    );
    unawaited(_eventController.close());
  }

  Future<Object?> _executeAction({
    required FutureOr<void> Function() action,
    required Set<String> requiredGates,
    String? actionId,
  }) async {
    _emitEvent(
      AppGateEvent(
        status: AppGateStatus.executing,
        actionId: actionId,
        requiredGates: requiredGates,
      ),
    );

    try {
      await action();
      _emitEvent(
        AppGateEvent(
          status: AppGateStatus.completed,
          actionId: actionId,
          requiredGates: requiredGates,
        ),
      );
      return null;
    } catch (error, stackTrace) {
      final actionException = AppGateActionException(
        originalError: error,
        requiredGates: requiredGates,
        actionId: actionId,
        stackTrace: stackTrace,
      );

      _emitEvent(
        AppGateEvent(
          status: AppGateStatus.failed,
          actionId: actionId,
          requiredGates: requiredGates,
          error: error,
          stackTrace: stackTrace,
        ),
      );

      try {
        _onError?.call(actionException);
      } catch (_) {
        // Prevent exceptions in user-provided error handlers from breaking the internal queue loop.
      }
      return error;
    }
  }

  bool _areOpenNormalized(Set<String> gates) {
    return _openGates.containsAll(gates);
  }

  String _normalizeGateName(String gate) {
    final trimmed = gate.trim();
    if (trimmed.isEmpty) {
      throw AppGateInvalidGateException(gate);
    }
    return trimmed;
  }

  Set<String> _normalizeGateNames(Iterable<String> gates) {
    final normalized = <String>{};
    for (final gate in gates) {
      normalized.add(_normalizeGateName(gate));
    }
    return Set<String>.unmodifiable(normalized);
  }

  void _emitEvent(AppGateEvent event) {
    if (!_eventController.isClosed) {
      _eventController.add(event);
    }
  }

  void _checkNotDisposed() {
    if (_isDisposed) {
      throw const AppGateDisposedException();
    }
  }
}
