# Contributing to flutter_app_gate

Thank you for your interest in contributing to `flutter_app_gate`! This guide explains how to get set up, develop, and submit contributions.

## Principles

1. **Pure Dart Core**: The package must have zero third-party runtime dependencies and must not depend directly on the Flutter SDK.
2. **Safety & Concurrency**: All gate state changes and queue processing must be strictly re-entrant and concurrency-safe.
3. **Simplicity**: Avoid unnecessary abstractions, reflection, or overengineering.

---

## Development Setup

1. Ensure you have the Dart SDK (3.0.0 or later) installed.
2. Clone the repository and fetch dependencies:
   ```bash
   dart pub get
   ```

---

## Code Quality & Verification

Before submitting a pull request, ensure all checks pass:

1. **Format Code**:
   ```bash
   dart format .
   dart format --output=none --set-exit-if-changed .
   ```

2. **Analyze Code**:
   ```bash
   dart analyze --fatal-infos
   ```

3. **Run All Tests**:
   ```bash
   dart test
   ```

4. **Verify Publish Dry-Run**:
   ```bash
   dart pub publish --dry-run
   ```

---

## Pull Request Guidelines

- Ensure each PR addresses a specific fix, improvement, or feature.
- Include unit tests covering your changes.
- Update `CHANGELOG.md` with a summary of the changes if applicable.
- Ensure all public APIs have clear `dartdoc` documentation.
