import 'dart:async';
import 'package:flutter_app_gate/flutter_app_gate.dart';

void main() async {
  // 1. Create an AppGate instance with an error handler.
  final appGate = AppGate(
    config: const AppGateConfig(maxPendingActions: 100),
    onError: (exception) {
      // ignore: avoid_print
      print('[ErrorHandler] Caught exception: $exception');
    },
  );

  // 7. Listen to lifecycle and operational events.
  final subscription = appGate.events.listen((event) {
    // ignore: avoid_print
    print('[Event] ${event.status.name.padRight(16)} '
        '| Gate: ${(event.gate ?? '-').padRight(12)} '
        '| ActionID: ${(event.actionId ?? '-').padRight(18)} '
        '| Required: ${event.requiredGates}');
  });

  // ignore: avoid_print
  print('--- Step 1: Submitting actions before gates are open ---');

  // 2 & 3. Submitting an action requiring both 'app' and 'navigation' before gates are open.
  final result1 = await appGate.run(
    id: 'navigate_to_home',
    requires: ['app', 'navigation'],
    action: () async {
      // ignore: avoid_print
      print('🚀 [Action Executed] Navigating to Home Screen!');
      await Future<void>.delayed(const Duration(milliseconds: 50));
    },
  );

  // ignore: avoid_print
  print(
      'Action 1 submitted. Status: ${result1.status.name} (isQueued: ${result1.isQueued})');

  // Submitting an action requiring only 'app' gate.
  final result2 = await appGate.run(
    id: 'analytics_init',
    requires: ['app'],
    action: () {
      // ignore: avoid_print
      print('🚀 [Action Executed] Analytics initialized!');
    },
  );
  // ignore: avoid_print
  print(
      'Action 2 submitted. Status: ${result2.status.name} (isQueued: ${result2.isQueued})');

  // Attempting duplicate action with same ID while pending.
  final duplicateResult = await appGate.run(
    id: 'navigate_to_home',
    requires: ['app', 'navigation'],
    action: () {
      // ignore: avoid_print
      print('This duplicate should not run!');
    },
  );
  // ignore: avoid_print
  print(
      'Duplicate submitted. Status: ${duplicateResult.status.name} (isDuplicateIgnored: ${duplicateResult.isDuplicateIgnored})');

  // ignore: avoid_print
  print('\nCurrent pending actions count: ${appGate.pendingCount}');

  // 4. Open the 'app' gate.
  // ignore: avoid_print
  print('\n--- Step 2: Opening "app" gate ---');
  appGate.open('app');

  // Allow event loop to process eligible pending action ('analytics_init').
  await Future<void>.delayed(const Duration(milliseconds: 60));

  // ignore: avoid_print
  print('Open gates: ${appGate.openGates}');
  // ignore: avoid_print
  print('Pending actions count after opening "app": ${appGate.pendingCount}');

  // 5 & 6. Open the 'navigation' gate -> automatically executes 'navigate_to_home'.
  // ignore: avoid_print
  print('\n--- Step 3: Opening "navigation" gate ---');
  appGate.open('navigation');

  // Wait for queued action to complete.
  await Future<void>.delayed(const Duration(milliseconds: 100));

  // ignore: avoid_print
  print(
      'Pending actions count after opening all required gates: ${appGate.pendingCount}');

  // Step 4: Submitting an action when all required gates are already open (executes immediately).
  // ignore: avoid_print
  print(
      '\n--- Step 4: Submitting action when required gates are already open ---');
  final immediateResult = await appGate.run(
    id: 'fetch_user_profile',
    requires: ['app', 'navigation'],
    action: () {
      // ignore: avoid_print
      print('🚀 [Action Executed] Fetching user profile immediately!');
    },
  );
  // ignore: avoid_print
  print(
      'Immediate action status: ${immediateResult.status.name} (isExecuted: ${immediateResult.isExecuted})');

  // Cleanup
  await subscription.cancel();
  appGate.dispose();
  // ignore: avoid_print
  print('\nAppGate disposed successfully. isDisposed: ${appGate.isDisposed}');
}
