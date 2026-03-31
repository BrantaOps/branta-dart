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
