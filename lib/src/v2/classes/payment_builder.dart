import 'package:branta/src/v2/models/destination.dart';
import 'package:branta/src/v2/models/destination_type.dart';
import 'package:branta/src/v2/models/payment.dart';
import 'dart:convert';

class PaymentBuilder {
  final Payment payment = Payment(destinations: [], ttl: 3600);

  PaymentBuilder addDestination(String address, [bool zk = false, DestinationType? type]) {
    payment.destinations.add(Destination(value: address, zk: zk, type: type));

    return this;
  }

  PaymentBuilder setDescription(String description) {
    payment.description = description;

    return this;
  }

  PaymentBuilder addMetadata(String key, String value) {
    final Map<String, dynamic> metadataMap =
        payment.metadata != null && payment.metadata!.isNotEmpty
        ? jsonDecode(payment.metadata!) as Map<String, dynamic>
        : <String, dynamic>{};

    metadataMap[key] = value;

    payment.metadata = jsonEncode(metadataMap);

    return this;
  }

  PaymentBuilder setTtl(int ttl) {
    payment.ttl = ttl;

    return this;
  }

  Payment build() {
    return payment;
  }
}
