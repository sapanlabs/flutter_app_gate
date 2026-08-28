# flutter_app_gate

[![pub package](https://img.shields.io/pub/v/flutter_app_gate.svg)](https://pub.dev/packages/flutter_app_gate)
[![CI](https://github.com/sapanlabs/flutter_app_gate/actions/workflows/ci.yml/badge.svg)](https://github.com/sapanlabs/flutter_app_gate/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

A lightweight, concurrency-safe coordination package for Flutter and Dart that allows developers to defer actions until one or more named conditions ("gates") are open.

---

## Overview

In modern application development, events often arrive before the app is ready to process them:
- A push notification payload arrives before `Navigator` or routing is mounted.
- A deep link arrives before authentication state is resolved.
- An analytics event or data sync triggers before local storage or SDK initialization is complete.

`flutter_app_gate` solves this by introducing named **Gates**. You define what gates an action requires. If all required gates are open, the action executes immediately. If any required gate is closed, the action is safely queued and automatically executes as soon as all its required gates become open.

```
Incoming Action
       ↓
Check required gates
       ↓
Are all gates open?
       │
   ┌───┴────┐
   │        │
  YES       NO
   │        │
Execute    Queue
            │
       Gate changes (e.g., appGate.open('navigation'))
            │
            ↓
       Re-check gates
            │
            ↓
        Execute safely in FIFO order
```

### Highlights

- **Pure Dart Core**: Zero runtime dependencies. Fully compatible with Flutter (Android, iOS, Web, Desktop) and standalone Dart applications.
- **Non-blocking FIFO Queue**: A blocked action never blocks later actions whose gates are open.
- **Dynamic Gate Evaluation**: Gates are re-verified right before each queued action runs.
- **Re-entrancy & Concurrency Safety**: Guaranteed safe under rapid gate flipping and concurrent action submissions.
- **Duplicate Protection**: Optional action IDs prevent duplicate pending executions without long-lived memory leaks.
- **Error Isolation**: An unhandled exception in one action never crashes the queue or stops subsequent actions.
- **Fine-grained Stream**: Listen to lifecycle events (`gateOpened`, `queued`, `executing`, `completed`, `failed`, etc.).

---

## Installation

Add `flutter_app_gate` to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_app_gate: ^0.1.0
```

Or via terminal:

```bash
dart pub add flutter_app_gate
```

---

## Quick Start

```dart
import 'package:flutter_app_gate/flutter_app_gate.dart';

void main() async {
  final appGate = AppGate();

  // 1. Submit an action requiring 'auth' and 'navigation'
  await appGate.run(
    requires: ['auth', 'navigation'],
    action: () {
      print('User is authenticated and navigation is ready!');
    },
  );

  // 2. Open gates when your app lifecycle milestones are reached
  appGate.open('auth');        // Action remains queued (navigation is still closed)
  appGate.open('navigation');  // Action automatically executes!
}
```

---

## Opening and Closing Gates

Gates are named `String` identifiers. Whitespace is automatically trimmed and empty names are rejected.

```dart
final appGate = AppGate();

// Open a gate (triggers pending action processing)
appGate.open('app_ready');

// Check gate status
bool isReady = appGate.isOpen('app_ready'); // true

// Close a gate
appGate.close('app_ready');

// Check multiple gates
bool allReady = appGate.areOpen(['app_ready', 'database']);
```

---

## Waiting for Multiple Gates

An action can require any number of gates. It will only execute once **every** required gate is open:

```dart
await appGate.run(
  requires: ['firebase', 'auth', 'navigation'],
  action: () {
    // Executes only when all 3 gates are open simultaneously.
  },
);
```

---

## Deferred Actions & Immediate Execution

When calling `appGate.run()`:
- If all required gates are open (or `requires: []` is empty), the action executes immediately.
- If one or more gates are closed, the action is queued.

The returned `AppGateRunResult` provides status details:

```dart
final result = await appGate.run(
  id: 'profile_load',
  requires: ['auth'],
  action: () async {
    // work
  },
);

if (result.isExecuted) {
  print('Action executed immediately.');
} else if (result.isQueued) {
  print('Action was deferred to pending queue.');
}
```

---

## Async Actions

Actions can be synchronous or asynchronous (`FutureOr<void> Function()`):

```dart
await appGate.run(
  requires: ['database'],
  action: () async {
    await database.syncPendingWrites();
  },
);
```

---

## Duplicate Protection

To prevent the same incoming event (e.g. duplicate push notification payload) from queueing multiple times, pass a unique `id`:

```dart
// First submission (queued)
final res1 = await appGate.run(
  id: 'push_order_42',
  requires: ['navigation'],
  action: () => navigateToOrder(42),
);
print(res1.status); // AppGateRunStatus.queued

// Duplicate submission while still pending (safely ignored)
final res2 = await appGate.run(
  id: 'push_order_42',
  requires: ['navigation'],
  action: () => navigateToOrder(42),
);
print(res2.status); // AppGateRunStatus.duplicateIgnored
```

> **Note**: Once an action completes or fails, its ID is immediately released. The same ID can be used again for future distinct actions without memory leaks.

---

## Events

Subscribe to the broadcast stream `appGate.events` to monitor gate transitions and queue lifecycle:

```dart
final subscription = appGate.events.listen((event) {
  switch (event.status) {
    case AppGateStatus.gateOpened:
      print('Gate opened: ${event.gate}');
      break;
    case AppGateStatus.gateClosed:
      print('Gate closed: ${event.gate}');
      break;
    case AppGateStatus.queued:
      print('Action queued: ${event.actionId} (requires: ${event.requiredGates})');
      break;
    case AppGateStatus.executing:
      print('Action executing: ${event.actionId}');
      break;
    case AppGateStatus.completed:
      print('Action completed: ${event.actionId}');
      break;
    case AppGateStatus.failed:
      print('Action failed: ${event.actionId} with error: ${event.error}');
      break;
    case AppGateStatus.duplicateIgnored:
      print('Duplicate action ignored: ${event.actionId}');
      break;
    case AppGateStatus.queueFull:
      print('Queue capacity exceeded!');
      break;
    case AppGateStatus.reset:
      print('AppGate was reset.');
      break;
    case AppGateStatus.disposed:
      print('AppGate was disposed.');
      break;
  }
});
```

---

## Error Handling & Isolation

If an action throws an exception, `flutter_app_gate` catches it, emits an `AppGateStatus.failed` event, and passes the structured `AppGateActionException` to your `onError` callback.

**The failure of one action never halts or corrupts the queue.** Subsequent eligible actions will continue to execute.

```dart
final appGate = AppGate(
  onError: (AppGateException exception) {
    if (exception is AppGateActionException) {
      print('Action ${exception.actionId} failed: ${exception.cause}');
    }
  },
);
```

### Exception Types

- `AppGateException`: Base abstract class for all package exceptions.
- `AppGateActionException`: Wraps an unhandled error thrown by an action callback (`actionId`, `requiredGates`, `cause`, `stackTrace`).
- `AppGateDisposedException`: Thrown when mutating or executing through a disposed instance.
- `AppGateInvalidGateException`: Thrown when an empty or whitespace-only gate name is used.
- `AppGateQueueFullException`: Thrown when `maxPendingActions` capacity is exceeded.

---

## Queue Behavior & Head-of-Line Non-blocking

`flutter_app_gate` enforces FIFO ordering among eligible actions while preventing head-of-line blocking:

```
Queue State:
1. Action A (requires: 'auth')
2. Action B (requires: 'app')

If 'app' opens while 'auth' remains closed:
- Action B executes immediately.
- Action A remains safely in the pending queue until 'auth' opens.
```

---

## Configuration

Customize queue limits via `AppGateConfig`:

```dart
final appGate = AppGate(
  config: const AppGateConfig(
    maxPendingActions: 500, // Default: 1000
  ),
);
```

If `pendingCount` reaches `maxPendingActions`, new queue attempts throw `AppGateQueueFullException` and emit `AppGateStatus.queueFull`.

---

## Reset & Disposal

### Reset

`reset()` clears all open gates and pending queues without disposing the instance. The instance remains ready for reuse.

```dart
appGate.reset();
```

### Disposal

`dispose()` releases all resources, clears queues, and closes the event stream. Any subsequent attempt to run actions or modify gates throws `AppGateDisposedException`.

```dart
appGate.dispose();
```

---

## Complete Example

```dart
import 'dart:async';
import 'package:flutter_app_gate/flutter_app_gate.dart';

void main() async {
  final appGate = AppGate(
    onError: (e) => print('Error: $e'),
  );

  // Subscribe to events
  appGate.events.listen((e) => print('[Event] ${e.status.name} (gate: ${e.gate})'));

  // Defer navigation until app and navigator are ready
  unawaited(appGate.run(
    id: 'open_chat_screen',
    requires: ['app_init', 'navigator_ready'],
    action: () async {
      print('Navigating to chat screen...');
    },
  ));

  // Simulate app lifecycle milestones
  await Future<void>.delayed(const Duration(milliseconds: 100));
  print('App initialization finished.');
  appGate.open('app_init');

  await Future<void>.delayed(const Duration(milliseconds: 100));
  print('Navigator mounted.');
  appGate.open('navigator_ready'); // Automatically triggers 'open_chat_screen'

  await Future<void>.delayed(const Duration(milliseconds: 50));
  appGate.dispose();
}
```

---

## Common Use Cases

### 1. Flutter Push Notification Routing
When a notification is tapped while the app is killed or in background:
```dart
// In your notification callback:
appGate.run(
  id: message.messageId,
  requires: ['navigation_ready', 'auth_ready'],
  action: () => router.push('/notifications/${message.data['id']}'),
);

// In your root widget / auth listener:
appGate.open('navigation_ready');
appGate.open('auth_ready');
```

### 2. Deep Linking
Ensure deep links wait for your initial onboarding/authentication checks before routing:
```dart
appGate.run(
  requires: ['auth_resolved', 'navigation_ready'],
  action: () => router.go(deepLinkPath),
);
```

### 3. Service & SDK Initialization
Defer analytics tracking or background syncs until local storage and network services are ready:
```dart
appGate.run(
  requires: ['local_db_ready', 'analytics_sdk_ready'],
  action: () => analytics.logEvent('app_opened'),
);
```

---

## Limitations

- **Process Memory Lifetime**: `AppGate` maintains state in memory. If your application process is killed, in-memory pending actions are not persisted to disk. For persistence across process termination, serialize incoming payloads to local storage before enqueueing.
- **Pure Dart Scope**: `flutter_app_gate` coordinates state transitions through Dart async primitives; it does not automatically listen to Flutter widget trees or native OS signals without you calling `open()` or `close()`.
