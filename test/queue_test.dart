import 'dart:async';
import 'package:flutter_app_gate/flutter_app_gate.dart';
import 'package:test/test.dart';

void main() {
  group('Queue Processing & Ordering', () {
    late AppGate appGate;

    setUp(() {
      appGate = AppGate();
    });

    tearDown(() {
      if (!appGate.isDisposed) {
        appGate.dispose();
      }
    });

    test('preserves FIFO ordering among eligible actions', () async {
      final executionOrder = <String>[];

      await appGate.run(
        id: 'action_A',
        requires: ['app'],
        action: () {
          executionOrder.add('A');
        },
      );

      await appGate.run(
        id: 'action_B',
        requires: ['app'],
        action: () {
          executionOrder.add('B');
        },
      );

      await appGate.run(
        id: 'action_C',
        requires: ['app'],
        action: () {
          executionOrder.add('C');
        },
      );

      expect(appGate.pendingCount, equals(3));

      appGate.open('app');
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(executionOrder, equals(['A', 'B', 'C']));
      expect(appGate.pendingCount, equals(0));
    });

    test('blocked action does not deadlock later eligible actions', () async {
      final executionOrder = <String>[];

      // Action A requires 'auth' (remains closed)
      await appGate.run(
        id: 'action_A',
        requires: ['auth'],
        action: () {
          executionOrder.add('A');
        },
      );

      // Action B requires 'app'
      await appGate.run(
        id: 'action_B',
        requires: ['app'],
        action: () {
          executionOrder.add('B');
        },
      );

      // Action C requires 'auth' (remains closed)
      await appGate.run(
        id: 'action_C',
        requires: ['auth'],
        action: () {
          executionOrder.add('C');
        },
      );

      // Action D requires 'app'
      await appGate.run(
        id: 'action_D',
        requires: ['app'],
        action: () {
          executionOrder.add('D');
        },
      );

      expect(appGate.pendingCount, equals(4));

      // Open only 'app'
      appGate.open('app');
      await Future<void>.delayed(const Duration(milliseconds: 30));

      // B and D should have executed in FIFO order. A and C must remain pending.
      expect(executionOrder, equals(['B', 'D']));
      expect(appGate.pendingCount, equals(2));

      // Now open 'auth'
      appGate.open('auth');
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(executionOrder, equals(['B', 'D', 'A', 'C']));
      expect(appGate.pendingCount, equals(0));
    });

    test('enforces maxPendingActions configuration limit', () async {
      final boundedGate = AppGate(
        config: const AppGateConfig(maxPendingActions: 2),
      );

      // 1st action queued
      await boundedGate.run(
        id: 'item_1',
        requires: ['gate1'],
        action: () {},
      );

      // 2nd action queued
      await boundedGate.run(
        id: 'item_2',
        requires: ['gate1'],
        action: () {},
      );

      expect(boundedGate.pendingCount, equals(2));

      // 3rd action should be rejected because queue is full
      expect(
        () => boundedGate.run(
          id: 'item_3',
          requires: ['gate1'],
          action: () {},
        ),
        throwsA(isA<AppGateQueueFullException>()),
      );

      expect(boundedGate.pendingCount, equals(2));

      boundedGate.dispose();
    });
  });
}
