import 'dart:async';
import 'package:flutter_app_gate/flutter_app_gate.dart';
import 'package:test/test.dart';

void main() {
  group('Concurrency & Race Condition Safety', () {
    late AppGate appGate;

    setUp(() {
      appGate = AppGate();
    });

    tearDown(() {
      if (!appGate.isDisposed) {
        appGate.dispose();
      }
    });

    test('rapid gate opening and closing handles pending actions safely',
        () async {
      int count = 0;

      for (int i = 0; i < 20; i++) {
        await appGate.run(
          id: 'action_$i',
          requires: ['fast_gate'],
          action: () {
            count++;
          },
        );
      }

      expect(appGate.pendingCount, equals(20));

      // Trigger rapid open/close/open calls
      appGate.open('fast_gate');
      appGate.open('fast_gate');
      appGate.close('fast_gate');
      appGate.open('fast_gate');

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(count, equals(20));
      expect(appGate.pendingCount, equals(0));
    });

    test('rechecks gates dynamically before executing each pending action',
        () async {
      final executedActions = <String>[];

      // Action 1 requires 'gateA' and takes 30ms
      await appGate.run(
        id: 'action_1',
        requires: ['gateA'],
        action: () async {
          executedActions.add('action_1');
          await Future<void>.delayed(const Duration(milliseconds: 30));
        },
      );

      // Action 2 requires 'gateB'
      await appGate.run(
        id: 'action_2',
        requires: ['gateB'],
        action: () {
          executedActions.add('action_2');
        },
      );

      // Open both gates
      appGate.open('gateA');
      appGate.open('gateB');

      // While action_1 is actively running (delayed), close gateB!
      await Future<void>.delayed(const Duration(milliseconds: 10));
      appGate.close('gateB');

      // Wait for all processing to complete
      await Future<void>.delayed(const Duration(milliseconds: 60));

      // Action 1 must have executed, but Action 2 must be held back in queue because gateB closed
      expect(executedActions, equals(['action_1']));
      expect(appGate.pendingCount, equals(1));
      expect(appGate.isOpen('gateB'), isFalse);

      // Reopening gateB allows Action 2 to execute safely
      appGate.open('gateB');
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(executedActions, equals(['action_1', 'action_2']));
      expect(appGate.pendingCount, equals(0));
    });

    test(
        'manual processPendingActions concurrent with automatic trigger executes safely',
        () async {
      int execCount = 0;

      for (int i = 0; i < 15; i++) {
        await appGate.run(
          id: 'item_$i',
          requires: ['shared_gate'],
          action: () async {
            execCount++;
            await Future<void>.delayed(const Duration(milliseconds: 2));
          },
        );
      }

      appGate.open('shared_gate');

      // Concurrent manual triggers
      await Future.wait([
        appGate.processPendingActions(),
        appGate.processPendingActions(),
        appGate.processPendingActions(),
      ]);

      expect(execCount, equals(15));
      expect(appGate.pendingCount, equals(0));
    });

    test(
        'actions are never executed more than once under concurrent submission',
        () async {
      final counter = <String, int>{};

      for (int i = 0; i < 30; i++) {
        final id = 'id_$i';
        counter[id] = 0;
        await appGate.run(
          id: id,
          requires: ['heavy_gate'],
          action: () async {
            counter[id] = (counter[id] ?? 0) + 1;
            await Future<void>.delayed(const Duration(milliseconds: 1));
          },
        );
      }

      appGate.open('heavy_gate');
      await appGate.processPendingActions();

      for (final entry in counter.entries) {
        expect(entry.value, equals(1),
            reason: '${entry.key} executed ${entry.value} times instead of 1');
      }
      expect(appGate.pendingCount, equals(0));
    });
  });
}
