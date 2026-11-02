import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../enums/destination_type.dart';

/// `encodeURIComponent`: percent-encode, but leave `! ' ( ) *` alone.
String encodeUriComponent(String value) {
  return Uri.encodeComponent(value)
      .replaceAll('%21', '!')
      .replaceAll('%27', "'")
      .replaceAll('%28', '(')
      .replaceAll('%29', ')')
      .replaceAll('%2A', '*');
}

extension StringBrantaExtensions on String {
  bool isBolt11() {
    final lower = toLowerCase();
    return lower.startsWith('lnbc') ||
        lower.startsWith('lntb') ||
        lower.startsWith('lnbcrt');
  }

  bool isArk() {
    final lower = toLowerCase();
    return lower.startsWith('ark1') || lower.startsWith('tark1');
  }

  bool isSilentPayment() {
    final lower = toLowerCase();
    return lower.startsWith('sp1') || lower.startsWith('tsp1');
  }

  /// bolt11, Ark, and silent payments encrypt with a key derived from the value.
  DestinationType? getDerivedKeyType() {
    if (isBolt11()) return DestinationType.bolt11;
    if (isArk()) return DestinationType.arkAddress;
    if (isSilentPayment()) return DestinationType.silentPayment;
    return null;
  }

  String toNormalizedHash() {
    final normalized = toLowerCase();
    final bytes = utf8.encode(normalized);
    final hash = sha256.convert(bytes);
    return hash.bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join()
        .toUpperCase();
  }
}

extension MapUrlFragmentExtension on Map<String, String> {
  String toUrlFragment() {
    if (isEmpty) return '';
    final fragments = entries.map(
      (e) => 'k-${encodeUriComponent(e.key)}=${encodeUriComponent(e.value)}',
    );
    return '#${fragments.join('&')}';
  }
}
