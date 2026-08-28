import 'dart:async';
import 'package:flutter_app_gate/flutter_app_gate.dart';
import 'package:test/test.dart';

void main() {
  group('Duplicate Action Protection', () {
    late AppGate appGate;

    setUp(() {
      appGate = AppGate();
    });

    tearDown(() {
      if (!appGate.isDisposed) {
        appGate.dispose();
      }
    });

    test('ignores duplicate action ID when already pending', () async {
      final events = <AppGateEvent>[];
      appGate.events.listen(events.add);

      int runCount1 = 0;
      int runCount2 = 0;

      final res1 = await appGate.run(
        id: 'dup_id',
        requires: ['app'],
        action: () {
          runCount1++;
        },
      );

      final res2 = await appGate.run(
        id: 'dup_id',
        requires: ['app'],
        action: () {
          runCount2++;
        },
      );

      expect(res1.status, equals(AppGateRunStatus.queued));
      expect(res2.status, equals(AppGateRunStatus.duplicateIgnored));
      expect(res2.isDuplicateIgnored, isTrue);
      expect(appGate.pendingCount, equals(1));

      appGate.open('app');
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(runCount1, equals(1));
      expect(runCount2, equals(0));
      expect(events.any((e) => e.status == AppGateStatus.duplicateIgnored),
          isTrue);
    });

    test('completed action frees ID for subsequent reuse', () async {
      int executions = 0;

      // 1. Queue and execute first action with ID 'notification_1'
      await appGate.run(
        id: 'notification_1',
        requires: ['app'],
        action: () {
          executions++;
        },
      );

      appGate.open('app');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(executions, equals(1));
      expect(appGate.pendingCount, equals(0));

      // 2. Submit new action with same ID 'notification_1'
      final res2 = await appGate.run(
        id: 'notification_1',
        requires: ['app'],
        action: () {
          executions++;
        },
      );

      expect(res2.status, equals(AppGateRunStatus.executed));
      expect(executions, equals(2));
    });

    test('failed action frees ID for subsequent reuse', () async {
      int executions = 0;

      // 1. Queue action that fails
      await appGate.run(
        id: 'failing_action',
        requires: ['app'],
        action: () {
          throw Exception('Intentional failure');
        },
      );

      appGate.open('app');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(appGate.pendingCount, equals(0));

      // 2. Reuse ID after failure
      final res2 = await appGate.run(
        id: 'failing_action',
        requires: ['app'],
        action: () {
          executions++;
        },
      );

      expect(res2.status, equals(AppGateRunStatus.executed));
      expect(executions, equals(1));
    });

    test('actions without ID (null) are never treated as duplicates', () async {
      int count = 0;

      await appGate.run(
        requires: ['app'],
        action: () => count++,
      );

      await appGate.run(
        requires: ['app'],
        action: () => count++,
      );

      expect(appGate.pendingCount, equals(2));

      appGate.open('app');
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(count, equals(2));
    });

    test('reset clears pending IDs allowing re-queueing', () async {
      await appGate.run(
        id: 'reset_id',
        requires: ['gate1'],
        action: () {},
      );

      expect(appGate.pendingCount, equals(1));
      appGate.reset();
      expect(appGate.pendingCount, equals(0));

      final res = await appGate.run(
        id: 'reset_id',
        requires: ['gate1'],
        action: () {},
      );

      expect(res.status, equals(AppGateRunStatus.queued));
      expect(appGate.pendingCount, equals(1));
    });
  });
}
