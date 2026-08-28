import 'dart:async';
import 'package:flutter_app_gate/flutter_app_gate.dart';
import 'package:test/test.dart';

void main() {
  group('Error Isolation & Exception Handling', () {
    late AppGate appGate;
    late List<AppGateException> caughtExceptions;

    setUp(() {
      caughtExceptions = <AppGateException>[];
      appGate = AppGate(
        onError: (ex) => caughtExceptions.add(ex),
      );
    });

    tearDown(() {
      if (!appGate.isDisposed) {
        appGate.dispose();
      }
    });

    test('failure of one action does not stop other eligible actions in queue',
        () async {
      final executionTracker = <String>[];

      // Action A will fail
      await appGate.run(
        id: 'action_A',
        requires: ['app'],
        action: () {
          executionTracker.add('A_started');
          throw StateError('Action A failed');
        },
      );

      // Action B should still succeed
      await appGate.run(
        id: 'action_B',
        requires: ['app'],
        action: () {
          executionTracker.add('B_completed');
        },
      );

      appGate.open('app');
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(executionTracker, equals(['A_started', 'B_completed']));
      expect(appGate.pendingCount, equals(0));

      expect(caughtExceptions.length, equals(1));
      expect(caughtExceptions.first, isA<AppGateActionException>());

      final actionEx = caughtExceptions.first as AppGateActionException;
      expect(actionEx.actionId, equals('action_A'));
      expect(actionEx.requiredGates, equals({'app'}));
      expect(actionEx.cause, isA<StateError>());
    });

    test(
        'immediate execution failure reports error without throwing unhandled exception',
        () async {
      appGate.open('app');

      final result = await appGate.run(
        id: 'immediate_fail',
        requires: ['app'],
        action: () {
          throw const FormatException('Bad format');
        },
      );

      expect(result.status, equals(AppGateRunStatus.executed));
      expect(result.hasError, isTrue);
      expect(result.error, isA<FormatException>());
      expect(caughtExceptions.length, equals(1));
      expect(caughtExceptions.first, isA<AppGateActionException>());
    });

    test('emits failed event with error and stack trace', () async {
      final events = <AppGateEvent>[];
      appGate.events.listen(events.add);

      appGate.open('app');
      await appGate.run(
        id: 'failing_event_test',
        requires: ['app'],
        action: () => throw Exception('Event error test'),
      );

      await Future<void>.delayed(const Duration(milliseconds: 10));

      final failedEvent =
          events.firstWhere((e) => e.status == AppGateStatus.failed);
      expect(failedEvent.actionId, equals('failing_event_test'));
      expect(failedEvent.error, isA<Exception>());
      expect(failedEvent.stackTrace, isNotNull);
    });

    test(
        'throwing exception inside onError handler does not crash queue or block later actions',
        () async {
      final crashingGate = AppGate(
        onError: (ex) {
          throw StateError('Uncaught user error inside onError handler!');
        },
      );

      final executed = <String>[];

      // Action 1 fails, which triggers the throwing onError handler
      await crashingGate.run(
        id: 'action_1',
        requires: ['app'],
        action: () {
          executed.add('action_1_ran');
          throw Exception('Action 1 failed');
        },
      );

      // Action 2 is valid and must still execute
      await crashingGate.run(
        id: 'action_2',
        requires: ['app'],
        action: () {
          executed.add('action_2_ran');
        },
      );

      crashingGate.open('app');
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(executed, equals(['action_1_ran', 'action_2_ran']));
      expect(crashingGate.pendingCount, equals(0));

      crashingGate.dispose();
    });

    test(
        'throwing exception in onError during queue full still throws AppGateQueueFullException',
        () async {
      final crashingGate = AppGate(
        config: const AppGateConfig(maxPendingActions: 1),
        onError: (ex) {
          throw StateError('Crashing onError during queue full');
        },
      );

      // Queue first action
      await crashingGate.run(
        requires: ['closed_gate'],
        action: () {},
      );

      // Second action exceeds capacity
      expect(
        () => crashingGate.run(
          requires: ['closed_gate'],
          action: () {},
        ),
        throwsA(isA<AppGateQueueFullException>()),
      );

      crashingGate.dispose();
    });
  });
}
