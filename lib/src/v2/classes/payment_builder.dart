import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../../enums/destination_type.dart';
import '../models/destination.dart';
import '../models/payment.dart';
import '../models/platform.dart';

class PaymentBuilder {
  final Payment _payment = Payment(destinations: []);

  PaymentBuilder addDestination(String value, {DestinationType? type}) {
    _payment.destinations.add(
      Destination(value: value, type: type, id: const Uuid().v4()),
    );
    return this;
  }

  PaymentBuilder setDescription(String description) {
    return addMetadata('description', description);
  }

  PaymentBuilder addMetadata(String key, String value) {
    final existing = _payment.metadata;
    final map = existing != null && existing.isNotEmpty
        ? Map<String, dynamic>.from(jsonDecode(existing) as Map)
        : <String, dynamic>{};
    map[key] = value;
    _payment.metadata = jsonEncode(map);
    return this;
  }

  /// Time to live in seconds.
  PaymentBuilder setTtl(int ttl) {
    _payment.ttl = ttl;
    return this;
  }

  PaymentBuilder setPlatformLogoUrl(String platformLogoUrl) {
    _payment.platformLogoUrl = platformLogoUrl;
    return this;
  }

  PaymentBuilder setChildPlatform(
    String name, {
    String? logoUrl,
    String? logoLightUrl,
  }) {
    _payment.childPlatform = Platform(
      name: name,
      logoUrl: logoUrl,
      logoLightUrl: logoLightUrl,
    );
    return this;
  }

  Payment build() => _payment;
}
