import 'package:flutter_app_gate/flutter_app_gate.dart';
import 'package:test/test.dart';

void main() {
  group('Gate Validation & Management', () {
    late AppGate appGate;

    setUp(() {
      appGate = AppGate();
    });

    tearDown(() {
      appGate.dispose();
    });

    test('opening and closing gates updates state correctly', () {
      expect(appGate.isOpen('app'), isFalse);
      expect(appGate.openGates, isEmpty);

      appGate.open('app');
      expect(appGate.isOpen('app'), isTrue);
      expect(appGate.openGates, contains('app'));

      appGate.close('app');
      expect(appGate.isOpen('app'), isFalse);
      expect(appGate.openGates, isEmpty);
    });

    test('areOpen returns true only when all specified gates are open', () {
      expect(appGate.areOpen([]), isTrue);
      expect(appGate.areOpen(['app', 'navigation']), isFalse);

      appGate.open('app');
      expect(appGate.areOpen(['app']), isTrue);
      expect(appGate.areOpen(['app', 'navigation']), isFalse);

      appGate.open('navigation');
      expect(appGate.areOpen(['app', 'navigation']), isTrue);
    });

    test('trims surrounding whitespace from gate names', () {
      appGate.open('  app  ');
      expect(appGate.isOpen('app'), isTrue);
      expect(appGate.isOpen('  app  '), isTrue);
      expect(appGate.openGates, contains('app'));

      appGate.close(' app ');
      expect(appGate.isOpen('app'), isFalse);
    });

    test(
        'throws AppGateInvalidGateException on empty or whitespace-only gate names',
        () {
      expect(
          () => appGate.open(''), throwsA(isA<AppGateInvalidGateException>()));
      expect(() => appGate.open('   '),
          throwsA(isA<AppGateInvalidGateException>()));
      expect(
          () => appGate.close(''), throwsA(isA<AppGateInvalidGateException>()));
      expect(() => appGate.close(' \t\n '),
          throwsA(isA<AppGateInvalidGateException>()));
      expect(() => appGate.isOpen(''),
          throwsA(isA<AppGateInvalidGateException>()));
      expect(() => appGate.areOpen(['app', '']),
          throwsA(isA<AppGateInvalidGateException>()));
    });

    test('normalizes duplicate gate names in requirements', () async {
      final events = <AppGateEvent>[];
      appGate.events.listen(events.add);

      final result = await appGate.run(
        id: 'dup_test',
        requires: ['app', 'app', 'navigation', 'navigation'],
        action: () {},
      );

      expect(result.requiredGates, equals({'app', 'navigation'}));
      expect(events.first.requiredGates, equals({'app', 'navigation'}));
    });

    test('gate names are case-sensitive', () {
      appGate.open('App');
      expect(appGate.isOpen('App'), isTrue);
      expect(appGate.isOpen('app'), isFalse);
      expect(appGate.openGates, contains('App'));
      expect(appGate.openGates, isNot(contains('app')));
    });
  });
}
