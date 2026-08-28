import 'dart:async';
import 'package:flutter_app_gate/flutter_app_gate.dart';
import 'package:test/test.dart';

void main() {
  group('AppGate Core Operations', () {
    late AppGate appGate;

    setUp(() {
      appGate = AppGate();
    });

    tearDown(() {
      if (!appGate.isDisposed) {
        appGate.dispose();
      }
    });

    test('rejects configuration with non-positive maxPendingActions', () {
      expect(
        () => AppGate(config: AppGateConfig(maxPendingActions: 0)),
        throwsA(anyOf(isA<AssertionError>(), isA<ArgumentError>())),
      );
      expect(
        () => AppGate(config: AppGateConfig(maxPendingActions: -10)),
        throwsA(anyOf(isA<AssertionError>(), isA<ArgumentError>())),
      );
    });

    test('executes action immediately when all required gates are open',
        () async {
      appGate.open('app');
      appGate.open('auth');

      bool executed = false;
      final result = await appGate.run(
        id: 'action_1',
        requires: ['app', 'auth'],
        action: () {
          executed = true;
        },
      );

      expect(executed, isTrue);
      expect(result.status, equals(AppGateRunStatus.executed));
      expect(result.isExecuted, isTrue);
      expect(result.actionId, equals('action_1'));
      expect(appGate.pendingCount, equals(0));
    });

    test('executes immediately when requires is empty', () async {
      bool executed = false;
      final result = await appGate.run(
        requires: [],
        action: () {
          executed = true;
        },
      );

      expect(executed, isTrue);
      expect(result.isExecuted, isTrue);
      expect(appGate.pendingCount, equals(0));
    });

    test('queues action when gates are closed and executes when gates open',
        () async {
      bool executed = false;
      final result = await appGate.run(
        id: 'pending_1',
        requires: ['app'],
        action: () {
          executed = true;
        },
      );

      expect(executed, isFalse);
      expect(result.status, equals(AppGateRunStatus.queued));
      expect(result.isQueued, isTrue);
      expect(appGate.pendingCount, equals(1));

      // Open gate -> should trigger execution
      appGate.open('app');
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(executed, isTrue);
      expect(appGate.pendingCount, equals(0));
    });

    test('action waits until all multiple gates are open', () async {
      bool executed = false;
      await appGate.run(
        requires: ['app', 'auth', 'navigation'],
        action: () {
          executed = true;
        },
      );

      expect(appGate.pendingCount, equals(1));

      // Open 1st gate
      appGate.open('app');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(executed, isFalse);
      expect(appGate.pendingCount, equals(1));

      // Open 2nd gate
      appGate.open('auth');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(executed, isFalse);
      expect(appGate.pendingCount, equals(1));

      // Open 3rd gate
      appGate.open('navigation');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(executed, isTrue);
      expect(appGate.pendingCount, equals(0));
    });

    test('supports asynchronous actions', () async {
      final executionCompleter = Completer<String>();

      await appGate.run(
        requires: ['service'],
        action: () async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          executionCompleter.complete('done');
        },
      );

      appGate.open('service');
      final result = await executionCompleter.future;

      expect(result, equals('done'));
      expect(appGate.pendingCount, equals(0));
    });

    test('reset clears gates and pending actions without disposing', () async {
      appGate.open('app');
      await appGate.run(
        requires: ['unopened_gate'],
        action: () {},
      );

      expect(appGate.isOpen('app'), isTrue);
      expect(appGate.pendingCount, equals(1));

      appGate.reset();

      expect(appGate.isOpen('app'), isFalse);
      expect(appGate.openGates, isEmpty);
      expect(appGate.pendingCount, equals(0));
      expect(appGate.isDisposed, isFalse);

      // Verify instance is still usable after reset
      appGate.open('new_gate');
      expect(appGate.isOpen('new_gate'), isTrue);

      bool ran = false;
      await appGate.run(
        requires: ['new_gate'],
        action: () {
          ran = true;
        },
      );
      expect(ran, isTrue);
    });

    test('disposal releases resources and rejects subsequent operations',
        () async {
      final events = <AppGateEvent>[];
      appGate.events.listen(events.add);

      appGate.open('app');
      appGate.dispose();

      expect(appGate.isDisposed, isTrue);
      expect(appGate.openGates, isEmpty);
      expect(appGate.pendingCount, equals(0));

      expect(
          () => appGate.open('app'), throwsA(isA<AppGateDisposedException>()));
      expect(
          () => appGate.close('app'), throwsA(isA<AppGateDisposedException>()));
      expect(() => appGate.isOpen('app'),
          throwsA(isA<AppGateDisposedException>()));
      expect(() => appGate.areOpen(['app']),
          throwsA(isA<AppGateDisposedException>()));
      expect(() => appGate.reset(), throwsA(isA<AppGateDisposedException>()));
      expect(() => appGate.processPendingActions(),
          throwsA(isA<AppGateDisposedException>()));
      expect(
        () => appGate.run(
          requires: ['app'],
          action: () {},
        ),
        throwsA(isA<AppGateDisposedException>()),
      );

      // Multiple dispose calls are safe and idempotent
      appGate.dispose();
      appGate.dispose();

      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(events.any((e) => e.status == AppGateStatus.disposed), isTrue);
    });

    test('emits stream of lifecycle events', () async {
      final statuses = <AppGateStatus>[];
      final subscription = appGate.events.listen((e) => statuses.add(e.status));

      appGate.open('app');
      await appGate.run(
        id: 'action_evt',
        requires: ['app'],
        action: () {},
      );
      appGate.close('app');
      appGate.reset();
      appGate.dispose();

      await Future<void>.delayed(const Duration(milliseconds: 20));
      await subscription.cancel();

      expect(
          statuses,
          containsAll([
            AppGateStatus.gateOpened,
            AppGateStatus.executing,
            AppGateStatus.completed,
            AppGateStatus.gateClosed,
            AppGateStatus.reset,
            AppGateStatus.disposed,
          ]));
    });
  });
}
