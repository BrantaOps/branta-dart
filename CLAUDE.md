# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
make install    # dart pub get
make build      # dart run build_runner build  (regenerates *.g.dart files)
make run        # runs example/branta_example.dart
make coverage   # run tests and generate coverage/lcov.info
dart test       # run all tests
dart test test/branta_test.dart  # run a single test file
dart analyze    # run linter
```

Run `make build` whenever models with `@JsonSerializable` are changed — the generated `*.g.dart` files are gitignored and must be regenerated.

## Architecture

This is a Dart SDK package for interacting with Branta's payment server. Public API is exported from `lib/branta.dart` → `lib/src/v2/api.dart`.

**Key layers:**

- `lib/src/v2/clients/branta_client.dart` — HTTP client; all API calls go through here. Uses Bearer token auth. Has both plain and ZK (zero-knowledge / encrypted) variants of get/post.
- `lib/src/v2/models/` — `Payment` and `Destination` JSON-serializable models (via `json_serializable`; generated files end in `.g.dart`).
- `lib/src/v2/classes/payment_builder.dart` — Fluent builder for constructing `Payment` objects.
- `lib/src/helpers/aes_encryption.dart` — Static AES-256-GCM encrypt/decrypt. Key is derived as SHA256(secret). Format: 12-byte nonce + ciphertext + 16-byte auth tag.

**Zero-knowledge (ZK) payments** encrypt destination addresses before sending and decrypt them on retrieval using a shared `secret`. The `zk` flag on `Destination` marks which addresses are encrypted.

**Versioning:** Code lives under `v2/`; structure anticipates future API versions.

## Features and Bug Fixes

All new features and bug fixes require unit tests that bring the relevant code to full coverage.

**New features:** write the implementation, then add tests covering all branches and edge cases.

**Bug fixes:** use TDD — write a failing test that reproduces the bug first, confirm it fails, then fix the code until the test passes. This proves the bug existed and is now resolved.
