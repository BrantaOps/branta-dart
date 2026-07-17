## 3.2.0

- Added `silentPayment` (`sp1`/`tsp1`) to `DestinationType`, with hash-based ZK support and QR parsing (`silent_payment` param, plain-text detection)
- Added encrypted metadata support: `addPaymentAsync` encrypts `Payment.metadata` with a per-payment DEK that is itself encrypted per-destination (`Destination.encryptedDek`); metadata is decrypted automatically alongside destinations on retrieval
- Added `Payment.childPlatform` and `PaymentBuilder.setChildPlatform()` for the child platform flow, mirroring the existing `parentPlatform` support

## 3.1.1

- Sync README with sibling SDKs

## 3.1.0

- Complete rewrite to achieve feature parity with `branta-dotnet` and `branta-js` v3.1.0
- Replaced `BrantaConfig` with `BrantaClientOptions` (adds `privacy`, `hmacSecret`, `defaultApiKey`)
- Added `PrivacyMode` enum (`strict` / `loose`); strict is the default
- Split HTTP layer into `BrantaClient` (raw HTTP) and `BrantaService` (orchestration)
- `getPaymentsAsync` and `getPaymentsByQrCodeAsync` now return `PaymentsResult` (payments + `verifyUrl`)
- `addPaymentAsync` now returns `AddPaymentResult` (payment + secret + `verifyUrl`)
- Added ZK support: hash-based deterministic encryption for bolt11 and ark addresses; secret-based for bitcoin addresses
- `QRParser` rewritten to support combined QR codes (`bitcoin:` + `lightning=` / `ark=` params), `branta_id`/`branta_secret`, and plain-text address detection
- `PaymentBuilder.setZk()` marks the last destination as ZK and assigns a UUID `zkId`
- `verifyUrl` includes `#k-{zkId}={key}` fragments for each decrypted ZK destination
- Removed `json_serializable` / `build_runner` in favour of hand-written `fromJson`/`toJson`
- Added `Platform` model and `parentPlatform` / `btcPayServerPluginVersion` fields on `Payment`

## 1.0.2

- [#18](https://github.com/BrantaOps/branta-dart/issues/18) Add platform_logo_light_url to payment

## 1.0.1

- [#15](https://github.com/BrantaOps/branta-dart/issues/15) Added `ark` and `ln_address` destination types to `DestinationType` enum

## 1.0.0

- SDK parity with `branta-core`: `getPaymentsAsync`, `getZKPaymentsAsync`, `addPaymentAsync` now return/throw `BrantaPaymentException` on errors instead of silently returning empty lists
- `addPaymentAsync` throws `BrantaPaymentException('Unauthorized')` when no API key is configured
- `getPaymentsAsync` validates `platformLogoUrl` domain against configured `baseUrl` to prevent open redirect attacks
- Payments returned from all fetch methods now include a `verifyUrl` built from the configured base URL
- Address parameter in `getPaymentsAsync` is now URL-encoded
- Added `DestinationType` enum and `type` field on `Destination`
- Added CI/CD workflow via GitHub Actions

## 0.0.3

- [#10](https://github.com/BrantaOps/branta-dart/issues/10) Add `.pubignore` to exclude development files (tests, Makefile, CLAUDE.md) from the published package

## 0.0.2

- [#2](https://github.com/BrantaOps/branta-dart/issues/2) Allow configuration per environment via `BrantaConfig`
- [#3](https://github.com/BrantaOps/branta-dart/issues/3) V2 Get Payment by QR Code — parse QR text directly to retrieve a payment
- [#4](https://github.com/BrantaOps/branta-dart/issues/4) V2 Payment by Parent Platform with HMAC — authenticate requests using an HMAC signature
- [#5](https://github.com/BrantaOps/branta-dart/issues/5) Add CLAUDE.md with project architecture and development guidelines

## 0.0.1

- Initial version.
