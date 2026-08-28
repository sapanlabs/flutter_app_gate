# Security Policy

The maintainers of `flutter_app_gate` take security, reliability, and code safety seriously. This document outlines our security policy, supported versions, security architecture scope, and procedures for reporting vulnerabilities responsibly.

---

## Supported Versions

We provide security updates and patches for the following versions:

| Version | Supported          |
| :------ | :----------------- |
| 0.1.x   | :white_check_mark: |
| < 0.1.0 | :x:                |

We strongly recommend always using the latest release available on [pub.dev](https://pub.dev/packages/flutter_app_gate).

---

## Security Scope

`flutter_app_gate` is a pure Dart, zero-runtime-dependency coordination library designed for managing named conditions ("gates") and deferring in-memory asynchronous action execution.

The package runs entirely in memory within the host Dart/Flutter runtime process and:
- Does **not** make network requests or open sockets.
- Does **not** execute shell commands, eval scripts, or use reflection.
- Does **not** deserialize untrusted external binary payloads.

Security and reliability boundaries specifically cover:
- **Action Queue Processing**: Safe FIFO scheduling, preventing action deadlock, corruption, or double-execution.
- **Gate Validation**: Normalization and sanitization of gate names to prevent malformed, blank, or colliding gate conditions.
- **Duplicate Protection**: Prevention of redundant pending actions without memory leaks or cache retention flaws.
- **Concurrency & Re-entrancy**: Strict loop locking and dynamic re-evaluation to withstand rapid gate state changes and asynchronous callbacks.
- **Untrusted Application Inputs**: Graceful handling of invalid configuration values, empty strings, and malformed identifiers.
- **Denial of Service (DoS) Concerns**: Enforcement of `maxPendingActions` to guard against unbounded queue growth and memory exhaustion.
- **Error Isolation**: Containment of exceptions within individual action closures and error callbacks so the shared queue processor remains operational.

---

## Reporting a Vulnerability

**DO NOT report security vulnerabilities through public GitHub Issues or public discussions.**

### Preferred Method: GitHub Private Vulnerability Reporting

Please submit reports privately via GitHub Security Advisories:
[https://github.com/sapanlabs/flutter_app_gate/security/advisories/new](https://github.com/sapanlabs/flutter_app_gate/security/advisories/new)

### Fallback Contact Method

If GitHub Private Vulnerability Reporting is unavailable, you may reach out privately through the maintainer's GitHub profile:
[https://github.com/sapanlabs](https://github.com/sapanlabs)

---

## What to Include in a Vulnerability Report

To help us triage and resolve the issue swiftly, please include:

1. **Vulnerability Description**: A clear explanation of the flaw and its mechanism.
2. **Potential Impact**: The security or reliability impact (e.g. memory exhaustion, stuck queue, state corruption, error leakage).
3. **Reproduction Steps**: Detailed instructions to reproduce the behavior.
4. **Minimal Dart Example**: A self-contained code snippet or unit test reproducing the issue.
5. **Affected Package Version**: The version of `flutter_app_gate` being used.
6. **Dart SDK Version**: Output from `dart --version` (and Flutter version if applicable).
7. **Proposed Fix (Optional)**: Any patch or mitigation recommendation you may have.

---

## Response Timeline

- **Initial Acknowledgement**: We aim to acknowledge receipt of your report within **48 hours**.
- **Investigation & Validation**: We will investigate and validate the report within **5 business days**, keeping you informed of the status.
- **Fix & Disclosure**: Confirmed vulnerabilities will be patched and released on [pub.dev](https://pub.dev/packages/flutter_app_gate) before public disclosure, accompanied by a coordinated security advisory.
