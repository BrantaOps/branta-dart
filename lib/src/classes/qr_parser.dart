import '../enums/destination_type.dart';
import '../helpers/branta_extensions.dart';

class QrDestination {
  final String value;

  /// Known rail type when the scheme or payload names one (e.g. bitcoin).
  /// Not set for chain URI schemes (`pol:`, `eth:`, `tron:`, …) — token comes from the matched payment destination.
  final DestinationType? type;

  /// True when this instruction is a secret-key address rail for verify.
  final bool secretKey;

  const QrDestination(this.value, this.type, {this.secretKey = false});
}

String normalizeQrText(String qrText) {
  var value = qrText.trim();
  bool isC0OrSpace(int code) => code <= 0x20;
  var start = 0;
  var end = value.length;
  while (start < end && isC0OrSpace(value.codeUnitAt(start))) {
    start++;
  }
  while (end > start && isC0OrSpace(value.codeUnitAt(end - 1))) {
    end--;
  }
  value = value.substring(start, end);
  return value.replaceAll(RegExp(r'[\t\n\r]'), '');
}

DestinationType? detectDestinationType(String value) {
  if (value.isBolt11()) return DestinationType.bolt11;
  if (value.isArk()) return DestinationType.arkAddress;
  if (value.isSilentPayment()) return DestinationType.silentPayment;
  final lower = value.toLowerCase();
  if (value.startsWith('1') ||
      value.startsWith('3') ||
      lower.startsWith('bc1') ||
      lower.startsWith('tb1') ||
      lower.startsWith('bcrt1')) {
    return DestinationType.bitcoinAddress;
  }
  return null;
}

Map<String, String> parseQueryString(String query) {
  final result = <String, String>{};
  final trimmed = query.startsWith('?') ? query.substring(1) : query;
  if (trimmed.isEmpty) return result;
  for (final part in trimmed.split('&')) {
    if (part.isEmpty) continue;
    final idx = part.indexOf('=');
    final rawKey = idx == -1 ? part : part.substring(0, idx);
    final rawValue = idx == -1 ? '' : part.substring(idx + 1);
    if (rawKey.isEmpty) continue;
    try {
      final key = Uri.decodeComponent(rawKey).toLowerCase();
      final value = Uri.decodeComponent(rawValue);
      result.putIfAbsent(key, () => value);
    } on ArgumentError {
      // Uri.decodeComponent throws ArgumentError for bad % escapes.
    } on FormatException {
      // skip malformed parameter
    }
  }
  return result;
}

String? _getDestination(String text) {
  final match = RegExp(r'(?<=:)[^?]*').firstMatch(text);
  return match?.group(0);
}

bool _startsWithI(String value, String prefix) =>
    value.toLowerCase().startsWith(prefix.toLowerCase());

DestinationType? _getDestinationType(String text) {
  if (_startsWithI(text, 'bitcoin:')) return DestinationType.bitcoinAddress;
  if (_startsWithI(text, 'lightning:')) {
    final dest = _getDestination(text);
    if (dest != null && dest.isBolt11()) return DestinationType.bolt11;
  }
  return null;
}

String _queryFromText(String text) {
  final q = text.indexOf('?');
  if (q == -1) return '';
  final hash = text.indexOf('#', q);
  return text.substring(q, hash == -1 ? text.length : hash);
}

class QRParser {
  final List<QrDestination> destinations = [];
  String? onChainEncryptionText;
  String? onChainEncryptionSecret;

  /// Destination types `verify` may bind for this QR's scheme (match-if-any).
  /// Set from the URI scheme — not from a token stamped on the address.
  List<DestinationType>? expectedSecretKeyTypes;

  /// A payable instruction this SDK cannot bind to a decrypted destination.
  bool hasUnverifiableInstruction = false;

  QRParser(String qrText) {
    final text = normalizeQrText(qrText);
    final uri = Uri.tryParse(text);

    if (uri == null || !uri.hasScheme || uri.scheme.length == 1) {
      destinations.add(QrDestination(text, detectDestinationType(text)));
      return;
    }

    final scheme = uri.scheme.toLowerCase();
    final secretKeyFamily = secretKeyUriFamilies[scheme];
    if (secretKeyFamily != null) {
      final dest = _getDestination(text);
      if (dest != null) {
        // Address only — token comes from the matched payment destination after verify.
        destinations.add(QrDestination(dest, null, secretKey: true));
        expectedSecretKeyTypes = List.of(secretKeyFamily);
      }
      final queryParams = parseQueryString(_queryFromText(text));
      onChainEncryptionText = queryParams['branta_id'];
      onChainEncryptionSecret = queryParams['branta_secret'];
      return;
    }

    if (scheme == 'bitcoin' || scheme == 'lightning') {
      final dest = _getDestination(text);
      if (dest != null) {
        final destType = _getDestinationType(text);
        destinations.add(
          QrDestination(
            dest,
            destType,
            secretKey: destType == DestinationType.bitcoinAddress,
          ),
        );
        if (dest.isNotEmpty &&
            destType != DestinationType.bitcoinAddress &&
            dest.getDerivedKeyType() == null) {
          hasUnverifiableInstruction = true;
        }
      }

      final queryParams = parseQueryString(_queryFromText(text));
      onChainEncryptionText = queryParams['branta_id'];
      onChainEncryptionSecret = queryParams['branta_secret'];

      void addBindable(
        String? value,
        DestinationType? type, {
        required bool onChain,
      }) {
        if (value == null) return;
        if (value.isNotEmpty && !onChain && value.getDerivedKeyType() == null) {
          hasUnverifiableInstruction = true;
          return;
        }
        destinations.add(QrDestination(value, type, secretKey: onChain));
      }

      addBindable(
        queryParams['lightning'],
        detectDestinationType(queryParams['lightning'] ?? ''),
        onChain: false,
      );
      addBindable(
        queryParams['ark'],
        detectDestinationType(queryParams['ark'] ?? ''),
        onChain: false,
      );
      addBindable(
        queryParams['silent_payment'],
        detectDestinationType(queryParams['silent_payment'] ?? ''),
        onChain: false,
      );
      addBindable(
        queryParams['bc'],
        DestinationType.bitcoinAddress,
        onChain: true,
      );
      addBindable(
        queryParams['tb'],
        DestinationType.bitcoinAddress,
        onChain: true,
      );
      addBindable(
        queryParams['sp'],
        detectDestinationType(queryParams['sp'] ?? ''),
        onChain: false,
      );
      if (queryParams.containsKey('bolt12')) hasUnverifiableInstruction = true;
      if (queryParams.containsKey('lno')) hasUnverifiableInstruction = true;
      if (queryParams.containsKey('pay')) hasUnverifiableInstruction = true;

      if (destinations.any((d) => d.secretKey)) {
        expectedSecretKeyTypes = [DestinationType.bitcoinAddress];
      }
      return;
    }

    destinations.add(QrDestination(text, null));
  }

  String? get destination =>
      destinations.isNotEmpty ? destinations.first.value : null;
  DestinationType? get destinationType =>
      destinations.isNotEmpty ? destinations.first.type : null;

  bool hasBrantaParams() =>
      onChainEncryptionText != null && onChainEncryptionSecret != null;
}
