# Security Policy

The maintainers of `flutter_app_gate` take the security and integrity of this project seriously. We appreciate the responsible disclosure of any vulnerability.

---

## Supported Versions

Only the latest release of `flutter_app_gate` receives security patches and updates. We recommend always running the latest published version.

| Version | Supported          |
| :------ | :----------------- |
| `0.1.x` | :white_check_mark: |
| `< 0.1` | :x:                |

---

## Security Scope

`flutter_app_gate` is a pure Dart, zero-dependency in-memory coordination package.

### In Scope
- Concurrency flaws, race conditions, or re-entrancy vulnerabilities leading to unexpected state corruption.
- Memory leak vectors or unhandled exceptions escaping internal queue execution boundaries.
- Denial of Service (DoS) conditions within the queue processing engine (e.g., unintended unbounded growth or deadlocks).

### Out of Scope
- Security of client application code executed inside action callbacks.
- Platform-level vulnerabilities in the Dart VM or Flutter engine.
- Attacks requiring direct process memory inspection or physical device compromise.

---

## Reporting a Vulnerability

Please **do not** open public GitHub issues or public discussions for security vulnerabilities.

### Preferred Method: GitHub Private Vulnerability Reporting
We strongly recommend using GitHub's built-in Private Vulnerability Reporting feature:
1. Navigate to the [Security Advisories](https://github.com/sapanlabs/flutter_app_gate/security/advisories) page of the repository.
2. Click **"Report a vulnerability"** to submit a confidential report directly to project maintainers.

---

## What to Include in a Report

To help us triage and resolve the issue quickly, please provide as much detail as possible:

1. **Summary**: A concise overview of the vulnerability and its potential impact.
2. **Steps to Reproduce**: Minimal, reproducible Dart/Flutter sample code or test case demonstrating the vulnerability.
3. **Affected Versions**: The package version(s) and Dart/Flutter SDK versions tested.
4. **Impact Assessment**: What an attacker could achieve or what failure condition is triggered.
5. **Proposed Fix** *(Optional)*: If you have identified a potential fix, patch, or workaround.

---

## Response Timeline

We commit to the following response timeline for valid security reports:

- **Initial Acknowledgement**: Within **48 hours** of receiving the report.
- **Triage & Assessment**: Within **5 business days**, confirming severity and affected versions.
- **Fix & Disclosure**: We will work to release a patch promptly and coordinate public disclosure once the fix is published on [pub.dev](https://pub.dev/packages/flutter_app_gate).
