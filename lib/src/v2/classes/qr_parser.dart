import '../../enums/destination_type.dart';
import '../../helpers/branta_extensions.dart';

class QrDestination {
  final String value;
  final DestinationType? type;
  const QrDestination(this.value, this.type);
}

class QRParser {
  final List<QrDestination> destinations = [];
  String? onChainEncryptionText;
  String? onChainEncryptionSecret;

  QRParser(String qrText) {
    final text = qrText.trim();
    final uri = Uri.tryParse(text);

    if (uri == null || !uri.hasScheme || uri.scheme.length == 1) {
      // Not a URI — treat as plain text
      destinations.add(QrDestination(text, _detectPlainTextType(text)));
      return;
    }

    if (uri.scheme == 'bitcoin' || uri.scheme == 'lightning') {
      final dest = _getDestination(text);
      if (dest != null) {
        destinations.add(QrDestination(dest, _getDestinationType(text)));
      }

      final queryParams = _parseQueryString(uri.query);
      onChainEncryptionText = queryParams['branta_id'];
      onChainEncryptionSecret = queryParams['branta_secret'];

      final lightningValue = queryParams['lightning'];
      if (lightningValue != null) {
        destinations.add(QrDestination(lightningValue, _detectPlainTextType(lightningValue)));
      }

      final bolt12Value = queryParams['bolt12'];
      if (bolt12Value != null) {
        destinations.add(QrDestination(bolt12Value, _detectPlainTextType(bolt12Value)));
      }

      final arkValue = queryParams['ark'];
      if (arkValue != null) {
        destinations.add(QrDestination(arkValue, _detectPlainTextType(arkValue)));
      }

      return;
    }

    destinations.add(QrDestination(text, null));
  }

  String? get destination => destinations.isNotEmpty ? destinations.first.value : null;
  DestinationType? get destinationType => destinations.isNotEmpty ? destinations.first.type : null;

  bool isOnChainZk() => onChainEncryptionText != null && onChainEncryptionSecret != null;

  static String? _getDestination(String text) {
    final colonIdx = text.indexOf(':');
    if (colonIdx == -1) return null;
    final questionIdx = text.indexOf('?');
    if (questionIdx == -1) return text.substring(colonIdx + 1);
    return text.substring(colonIdx + 1, questionIdx);
  }

  static DestinationType? _getDestinationType(String text) {
    if (text.toLowerCase().startsWith('bitcoin:')) {
      return DestinationType.bitcoinAddress;
    }
    if (text.toLowerCase().startsWith('lightning:')) {
      final dest = _getDestination(text);
      if (dest != null) {
        if (dest.isBolt11()) return DestinationType.bolt11;
        if (dest.toLowerCase().startsWith('lno')) return DestinationType.bolt12;
        if (dest.toLowerCase().startsWith('lnurl')) return DestinationType.lnUrl;
      }
    }
    return null;
  }

  static DestinationType? _detectPlainTextType(String value) {
    if (value.isBolt11()) return DestinationType.bolt11;
    if (value.toLowerCase().startsWith('lno')) return DestinationType.bolt12;
    if (value.toLowerCase().startsWith('lnurl')) return DestinationType.lnUrl;
    if (value.isArk()) return DestinationType.arkAddress;
    if (_isEthereumAddress(value)) return DestinationType.tetherAddress;
    if (_isTronAddress(value)) return DestinationType.tetherAddress;
    if (_isLnAddress(value)) return DestinationType.lnAddress;
    final lower = value.toLowerCase();
    if (value.startsWith('1') || value.startsWith('3') || lower.startsWith('bc1')) {
      return DestinationType.bitcoinAddress;
    }
    return null;
  }

  static bool _isEthereumAddress(String value) {
    if (value.length != 42) return false;
    if (!value.startsWith('0x') && !value.startsWith('0X')) return false;
    return RegExp(r'^[0-9a-fA-F]{40}$').hasMatch(value.substring(2));
  }

  static bool _isTronAddress(String value) {
    return value.length == 34 && value.startsWith('T');
  }

  static bool _isLnAddress(String value) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
  }

  static Map<String, String> _parseQueryString(String query) {
    if (query.isEmpty) return {};
    final result = <String, String>{};
    final parts = query.startsWith('?') ? query.substring(1) : query;
    for (final part in parts.split('&')) {
      if (part.isEmpty) continue;
      final eqIdx = part.indexOf('=');
      if (eqIdx == -1) {
        final key = Uri.decodeComponent(part);
        if (key.isNotEmpty) result[key] = '';
      } else {
        final key = Uri.decodeComponent(part.substring(0, eqIdx));
        final value = Uri.decodeComponent(part.substring(eqIdx + 1));
        if (key.isNotEmpty) result[key] = value;
      }
    }
    return result;
  }
}
