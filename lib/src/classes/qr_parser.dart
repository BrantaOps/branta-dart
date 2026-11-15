import '../enums/destination_type.dart';
import '../helpers/branta_extensions.dart';

class QrDestination {
  final String value;

  /// Rail this value belongs to. Set for bitcoin and ERC-681 transfers.
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
  // A "?" after the "#" belongs to the fragment, not the query.
  final hash = text.indexOf('#');
  final beforeFragment = hash == -1 ? text : text.substring(0, hash);
  final q = beforeFragment.indexOf('?');
  return q == -1 ? '' : beforeFragment.substring(q);
}

final RegExp _erc681PathPattern = RegExp(
  r'^(0x[0-9a-fA-F]{40})@([0-9]+)/transfer$',
);
final RegExp _evmAddress = RegExp(r'^0x[0-9a-fA-F]{40}$', caseSensitive: false);

/// Path of an ethereum: URI, without scheme, query, or fragment. One leading slash is dropped.
String _erc681UriPath(String text) {
  var rest = text.substring(text.indexOf(':') + 1);
  for (final delimiter in ['?', '#']) {
    final cut = rest.indexOf(delimiter);
    if (cut != -1) rest = rest.substring(0, cut);
  }
  return rest.startsWith('/') ? rest.substring(1) : rest;
}

/// ERC-681 token transfer. Chain id and contract select one destination type.
/// The deposit address is the `address` query param.
({DestinationType type, String address})? _parseErc681(String text) {
  final match = _erc681PathPattern.firstMatch(_erc681UriPath(text));
  if (match == null) return null;
  final chainDigits = match.group(2)!.replaceFirst(RegExp(r'^0+'), '');
  // No supported chain id has more than 15 digits. This also keeps the parse
  // inside int range on every platform.
  if (chainDigits.length > 15) return null;
  final type = evmTokenType(
    chainDigits.isEmpty ? 0 : int.parse(chainDigits),
    match.group(1)!,
  );
  if (type == null) return null;
  final address = parseQueryString(_queryFromText(text))['address'];
  if (address == null || !_evmAddress.hasMatch(address)) return null;
  return (type: type, address: address);
}

class QRParser {
  final List<QrDestination> destinations = [];
  String? onChainEncryptionText;
  String? onChainEncryptionSecret;

  /// Destination types this scan may decrypt.
  /// ERC-681 sets one type from the chain id and token contract.
  /// Bitcoin sets `bitcoin_address`.
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
    if (scheme == 'ethereum') {
      final transfer = _parseErc681(text);
      if (transfer == null) {
        destinations.add(QrDestination(text, null));
        return;
      }
      destinations.add(
        QrDestination(transfer.address, transfer.type, secretKey: true),
      );
      expectedSecretKeyTypes = [transfer.type];
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
