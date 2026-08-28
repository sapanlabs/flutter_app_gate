## 0.1.0

- Initial release of `flutter_app_gate`.
- Pure Dart, zero runtime dependencies.
- Named gate management: `open`, `close`, `isOpen`, `areOpen`.
- Action execution coordination with `run` and async/sync support.
- Non-blocking FIFO queue behavior avoiding head-of-line blocking.
- Duplicate pending action ID protection.
- Thread/concurrency-safe processing loop with re-entrancy protection.
- Fine-grained event stream with `AppGateEvent` and `AppGateStatus`.
- Error isolation and structured `AppGateException` hierarchy.
- Configurable maximum queue capacity.
- Instance `reset` and `dispose` lifecycle management.
