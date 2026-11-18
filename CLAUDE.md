# Branta Dart SDK

Dart SDK published as `branta` on pub.dev. Consumers (wallets, platforms, parent platforms) call `BrantaService` to look up or post payments to Branta. `README.md` is the install, constructor, and samples guide.

## Behavior contract

What `verify` returns and how ERC-681 is parsed: [Status rules](https://developer.branta.pro/setup/send/status-rules). Which rails encrypt with what key: [Encryption](https://developer.branta.pro/setup/receive/encryption). Send handling is on [Send](https://developer.branta.pro/setup/send), and the type list on [Destination types](https://developer.branta.pro/destination-types). Do not restate them here. Change the docs first, then the SDK.

Invariants that break silently. Check them before you change `verify` or `addPayment`:

- A raw on-chain address (including `tb1` / `bcrt1` / bare `0x`) is `unknown` and does not GET.
- A swapped address is `tampered`. `unknown`, `tampered`, and `incomplete` are returned, never thrown.
- The token is `matchedDestinations[].type`, never the URI scheme.
- A logo-domain mismatch throws. Every other lookup failure is a status.
- `addPayment` encrypts a copy and leaves the caller's `Payment` unchanged.
- Keep parity with every 4.x Branta SDK. A public method added or changed here is mirrored in each of them.

## Dart specifics

- A logo-domain mismatch throws `BrantaPaymentException`.
- `DestinationType` is only what `addPayment` accepts. It also includes `usdt_tron`, `usdt_ton`, `usdt_solana`, and `usdc_solana`. They can be posted but no URI verifies them, and they are not on the public Destination types page. There is no `usdc_ton`.

## Commands

```bash
dart test
dart analyze
make coverage
```

Live example-QR lookups run only when `BRANTA_RUN_INTEGRATION=1`.

Release: bump `version` in `pubspec.yaml`, add a `CHANGELOG.md` entry, `dart pub publish`, then tag the release commit `vX.Y.Z` and push the tag. Do not publish until asked.

## Layout

Public API is whatever `lib/branta.dart` exports: `BrantaService`, `PaymentBuilder`, `BrantaApiOptions`, `BrantaEnvironment`, `DestinationType`, `VerifyResult`, and the payment models. Export `DestinationType` only from the enum library — do not re-export `evmTokenRails`, `evmTokenType`, or `isSecretKeyAddressType`.

- `lib/src/services/branta_service.dart` orchestrates encrypt/decrypt around HTTP. `branta_client.dart` is the raw HTTP layer. Do not export it.
