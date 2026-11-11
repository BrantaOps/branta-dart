## Unreleased

- Added: multi-rail stablecoin destination types `usdt_ethereum`, `usdc_ethereum`, `usdt_bsc`, `usdc_bsc`, `usdt_tron`, `usdt_ton`, `usdc_ton`, `usdt_solana`, `usdc_solana`. `addPayment` encrypts them with a random secret. `verify()` parses `eth:`, `bsc:`, `tron:`, `ton:`, and `sol:` URIs with `branta_id` / `branta_secret` (`secretKeyUriFamilies`), match-if-any within the scheme's family. A bare address is `unknown`.

## 4.2.0

- Added: `DestinationType.usdtPolygon` for Polygon USDT. `addPayment` encrypts the recipient with a random secret (same pattern as bitcoin). `verify()` parses `pol:` URIs with `branta_id` / `branta_secret`; other query params (`value`, `currency`, `user`) are ignored for binding. A bare `0x` address is `unknown`. EVM address compare is case-insensitive.
- Added: `DestinationType.usdcPolygon` for Polygon USDC. Same secret-key encrypt / `pol:` verify path as `usdt_polygon`. Token is the destination type on the payment; `pol:` remains the Polygon EVM scheme for both.
- Added: `verify()` `match` includes `matchedDestinations`: the rails this scan bound (plaintext + `type`). Wallets should send from that list instead of filtering `payments[].destinations`.
- Changed: `polygonEvmDestinationTypes` is `{usdt_polygon, usdc_polygon}`. `verify()` of a `pol:` URI binds any family member whose decrypted address matches (match-if-any).
- Changed: `pol:` parsing no longer stamps a token `DestinationType` on the QR address. The scheme maps to the Polygon EVM family for verify; the token still comes from the matched payment destination.
- Fixed: `verify()` swap-checks only the secret-key rail family for the QR scheme, so a payment with both bitcoin and a Polygon rail no longer returns `tampered` for a valid single-rail QR.

## 4.0.1

- Fixed: malformed percent-encoded QR query params (`%ZZ`, truncated `1%`) no longer throw `ArgumentError` out of `verify()`; bad params are skipped as intended

## 4.0.0

- Breaking: `verify` replaces `getPaymentsAsync` and `getPaymentsByQrCodeAsync`. It returns `match`, `unknown`, `tampered`, or `incomplete`. A swapped address is `tampered`. A 404, a bare address, and a bolt11 / Ark / silent-payment lookup that does not decrypt are `unknown`. 5xx, 429, and no network are `incomplete`.
- Breaking: removed `PrivacyMode`. Every destination is encrypted. `BrantaClientOptions` and `BrantaServerBaseUrl` are now `BrantaApiOptions` and `BrantaEnvironment`.
- Breaking: `Destination.id` is the public name for the wire field `zk_id`. `addPayment` encrypts a copy and leaves the caller's `Payment` unchanged. Description is stored in encrypted metadata. An unset TTL is omitted. `DestinationType` is `bitcoin_address`, `bolt11`, `ark_address`, and `silent_payment`.
- The public library no longer exports the HTTP client, QR parser, AES helpers, or `QRParseException`.
- Breaking: removed `Payment.getDefaultValue`.

## 3.2.4

- Fixed: `getPaymentsByQrCodeAsync` now requires every payment instruction in a scanned QR code to match a decrypted destination. A swapped address with a rewritten `branta_secret`, an added lightning/ark/silent-payment leg that does not match the registered record, or a conflicting `bc=`/`tb=` address no longer comes back as verified. QR codes carrying `bolt12`, `lno=`, `pay=`, or LNURL instructions return no payments (ported from `branta-js`)
- Added: BIP-321 `bc`, `tb`, `sp`, and `lno` query parameters are parsed by `QRParser`; `QRParser.hasUnverifiableInstruction` flags instructions the SDK cannot bind to a decrypted destination

## 3.2.3

- Added: recognize signet and regtest Ark addresses (`tark1`) as `arkAddress`, alongside mainnet `ark1`. Strict-mode hash-ZK lookup and registration treat them the same way as `ark1`.

## 3.2.2

- Fixed: a same-origin validation gap: if the first payment in a `getPayments` response had no `platformLogoUrl`, validation silently stopped checking every later payment's logo URLs entirely. Logo-URL checks now run independently per payment, and now also cover `platformLogoLightUrl`, `parentPlatform.logoUrl`/`logoLightUrl`, and `childPlatform.logoUrl`/`logoLightUrl` (previously only `platformLogoUrl` was checked)

## 3.2.1

- Fixed: `getPaymentsByQrCodeAsync` now verifies that the plaintext Bitcoin address parsed from a scanned QR code matches the address decrypted via `branta_id`/`branta_secret`, throwing `BrantaPaymentException` with `reason: BrantaPaymentExceptionReason.tampered` on mismatch. Closes a gap where an attacker could swap the visible address in a `bitcoin:` URI while leaving a legitimate, verified `branta_id`/`branta_secret` pair untouched (ported from `branta-js` 3.2.1)

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
