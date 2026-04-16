/// Controls the privacy posture for on-chain address lookups.
///
/// - [PrivacyMode.strict] — Only ZK (zero-knowledge / encrypted) on-chain
///   lookups are permitted. Calling [BrantaClient.getPaymentsAsync] directly
///   will throw a [BrantaPaymentException]; plain-address branches inside
///   [BrantaClient.getPaymentsByQRCodeAsync] will silently return `[]`.
///   Lightning invoices and all POST operations are unaffected by this setting.
///
/// - [PrivacyMode.loose] — Both plain and ZK on-chain lookups are allowed.
///   No restrictions are enforced.
enum PrivacyMode {
  /// Only ZK (zero-knowledge / encrypted) on-chain lookups are permitted.
  strict,

  /// Both plain and ZK on-chain lookups are allowed.
  loose,
}
