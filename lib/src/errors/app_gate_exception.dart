import 'dart:core';

/// Handler for exceptions encountered during gate operations or action executions.
typedef AppGateErrorHandler = void Function(AppGateException exception);

/// Base class for all exceptions thrown or emitted by `flutter_app_gate`.
abstract class AppGateException implements Exception {
  /// Creates an [AppGateException] with an explanatory [message] and optional [cause] and [stackTrace].
  const AppGateException(this.message, {this.cause, this.stackTrace});

  /// A descriptive explanation of what caused the exception.
  final String message;

  /// The underlying cause or exception, if any.
  final Object? cause;

  /// The stack trace associated with the cause or point of failure, if any.
  final StackTrace? stackTrace;

  @override
  String toString() {
    if (cause != null) {
      return '$runtimeType: $message (Caused by: $cause)';
    }
    return '$runtimeType: $message';
  }
}

/// Thrown when an operation is attempted on an [AppGate] instance that has been disposed.
class AppGateDisposedException extends AppGateException {
  /// Creates an [AppGateDisposedException].
  const AppGateDisposedException([
    super.message = 'Cannot perform operation: AppGate has been disposed.',
  ]);
}

/// Thrown when a gate name is invalid (e.g., empty string or whitespace-only).
class AppGateInvalidGateException extends AppGateException {
  /// Creates an [AppGateInvalidGateException] for the given [gateName].
  AppGateInvalidGateException(String gateName)
      : super(
          'Invalid gate name: "$gateName". Gate names must not be empty or consist only of whitespace.',
        );
}

/// Thrown when the pending action queue has reached its maximum configured capacity.
class AppGateQueueFullException extends AppGateException {
  /// Creates an [AppGateQueueFullException].
  AppGateQueueFullException(int capacity, {String? actionId})
      : super(
          'AppGate queue is full (max: $capacity pending actions).${actionId != null ? ' Action ID: "$actionId"' : ''}',
        );
}

/// Wraps an exception thrown by an action executed through [AppGate].
class AppGateActionException extends AppGateException {
  /// Creates an [AppGateActionException] wrapping the [originalError].
  AppGateActionException({
    required Object originalError,
    required this.requiredGates,
    this.actionId,
    super.stackTrace,
  }) : super(
          'An error occurred during action execution: $originalError',
          cause: originalError,
        );

  /// The optional ID of the failed action.
  final String? actionId;

  /// The gates that were required for this action.
  final Set<String> requiredGates;
}
