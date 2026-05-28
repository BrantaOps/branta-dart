/// Controls the privacy posture for on-chain address lookups.
///
/// - [PrivacyMode.strict] — Only ZK (zero-knowledge / encrypted) lookups are
///   permitted. [BrantaService.getPaymentsAsync] throws a
///   [BrantaPaymentException] for plain bitcoin-address lookups;
///   [BrantaService.getPaymentsByQrCodeAsync] silently returns an empty result
///   for plain-address QR codes; [BrantaService.addPaymentAsync] throws if any
///   destination has [Destination.isZk] = false.
///
/// - [PrivacyMode.loose] — Both plain and ZK lookups are allowed.
enum PrivacyMode {
  strict,
  loose,
}
