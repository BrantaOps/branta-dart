import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../enums/destination_type.dart';

extension StringBrantaExtensions on String {
  bool isBolt11() {
    final lower = toLowerCase();
    return lower.startsWith('lnbc') ||
        lower.startsWith('lntb') ||
        lower.startsWith('lnbcrt');
  }

  bool isArk() => toLowerCase().startsWith('ark1');

  DestinationType? getHashZkType() {
    if (isBolt11()) return DestinationType.bolt11;
    if (isArk()) return DestinationType.arkAddress;
    return null;
  }

  String toNormalizedHash() {
    final normalized = toLowerCase();
    final bytes = utf8.encode(normalized);
    final hash = sha256.convert(bytes);
    return hash.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}

extension MapUrlFragmentExtension on Map<String, String> {
  String toUrlFragment() {
    final fragments = entries.map((e) => 'k-${e.key}=${e.value}');
    return '#${fragments.join('&')}';
  }
}
