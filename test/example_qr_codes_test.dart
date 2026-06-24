import 'dart:io' as io;

import 'package:branta/branta.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

BrantaService _makeService(BrantaServerBaseUrl baseUrl, PrivacyMode privacy) {
  final apiKey = io.Platform.environment['BRANTA_API_KEY'] ?? '';
  final options = BrantaClientOptions(
    baseUrl: baseUrl,
    defaultApiKey: apiKey,
    privacy: privacy,
  );
  return BrantaService(
    client: BrantaClient(
      httpClient: http.Client(),
      defaultOptions: options,
    ),
    aesEncryption: AesEncryptionService(),
    defaultOptions: options,
  );
}

void main() {
  group('Production', () {
    late BrantaService service;

    setUpAll(() {
      service = _makeService(BrantaServerBaseUrl.production, PrivacyMode.loose);
    });

    const onChain = 'bitcoin:bc1qu3k6geqdjncaarsu2vq56tt8php5vsug9kasmq';
    const lightning =
        'lightning:lnbc17760n1p4r4tqupp5yuapqmxldkc8smuwa6t8shkdg9gezulu0vc7htepfsvweph8kqfsdphgfexzmn5vysygetkv4kx7ur9wgsyc6t8dp6xu6twvusy27rpd4cxcegcqzzsxq97zvuqsp53564rg6w4xjqy7jamcfqxyy83a0j8nzfs0wpevs37t5ln49q6hrs9qxpqysgq47hpqmv34g25le8sceq9jdvul2nz7ucyu0vucv56nlfe40x7n3jsu8duxjrn6tgvdspt872crk9zeatafznm9c57m039z7wyx6g3njsqkchkdh';
    const zkOnChain =
        'bitcoin:bc1q6745z6cy3u0k9nprurh3x804c4r7u3u8vxca2n?branta_id=z15b5EsbP5LHJrFco38%2BFp%2BHVaiopAY676NCKek8e1Q%2B4a370TyYhvloS8uLCUHfJ4CzeI%2FbOFmFDGpAQszB0gu1pJ1HOQ%3D%3D&branta_secret=c6e9eb30-6258-4432-9847-bdcc4fd4b0db';
    const zkLightning =
        'lightning:lnbc17760n1p4r4flypp5k56kq3v2935rl3glkqu9vngfueud2zj87hjcff3t0kn0yrge0pfqdzjgfexzmn5vysz6gzyv4mx2mr0wpjhygzvd9nksarwd9hxwgz6v4ex7gztdehhwmr9v3nk2gz90psk6urvv5cqzzsxq97zvuqsp5hut3t0l0s5mvp9yr06v4253kqtf452z6c65s6g9sga445hc03v6s9qxpqysgqqm430zkk9uymjgvllr3aha88hc6q59etxasfqswn8r8pfm3dstlpp46azv906xtcj3wzprxup5fxn65a5wymt7zzq9sw9qdzx8rgdhcpk80nrg';
    const notFound = 'bitcoin:bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4';

    test('on-chain returns payment', () async {
      final result = await service.getPaymentsByQrCodeAsync(onChain);
      expect(result.payments, isNotEmpty);
    });

    test('lightning returns payment', () async {
      final result = await service.getPaymentsByQrCodeAsync(lightning);
      expect(result.payments, isNotEmpty);
    });

    test('zk on-chain returns payment', () async {
      final result = await service.getPaymentsByQrCodeAsync(zkOnChain);
      expect(result.payments, isNotEmpty);
    });

    test('zk lightning returns payment', () async {
      final result = await service.getPaymentsByQrCodeAsync(zkLightning);
      expect(result.payments, isNotEmpty);
    });

    test('not found returns empty', () async {
      final result = await service.getPaymentsByQrCodeAsync(notFound);
      expect(result.payments, isEmpty);
    });
  });

  group('Staging', () {
    late BrantaService service;

    setUpAll(() {
      service = _makeService(BrantaServerBaseUrl.staging, PrivacyMode.loose);
    });

    const onChain = 'bitcoin:bc1qgw3dzmhnyvcswc9r0v0z0ajtp8ulm4nuyeahwr';
    const lightning =
        'lightning:lnbc25830n1p4quq9ppp5zszvpgxtu6uwyur6sf7rayc0meqprqlkv30xjzclh6nzm7gavd8sdzh2d6xzemfdenjqsnjv9h8gcfq95sygetkv4kx7ur9wgsyc6t8dp6xu6twvusy27rpd4cxcefq9pfhgct8d9hxw2gcqzzsxqzursp5fcfx5st7x8rgxra42j47hskmzkcz96mx84xcnvs9lpsmjyzqhw2q9qxpqysgq06lxdc93jjpuqsal9unlfct6wuv0v53yxa8kksl85g3qdw7qks7z9jkq39c6wgzar72luwd38sfj0klyqv0zgns4rq7nafnd8qeuudcqql7at4';
    const zkOnChain =
        'bitcoin:bc1q6745z6cy3u0k9nprurh3x804c4r7u3u8vxca2n?branta_id=z15b5EsbP5LHJrFco38%2BFp%2BHVaiopAY676NCKek8e1Q%2B4a370TyYhvloS8uLCUHfJ4CzeI%2FbOFmFDGpAQszB0gu1pJ1HOQ%3D%3D&branta_secret=c6e9eb30-6258-4432-9847-bdcc4fd4b0db';
    const zkLightning =
        'lightning:lnbc25840n1p4qml83pp5aztzddx4k87m0wkd6wmgxr9753400mcj7sa89sa392krmueqv9qqdz92d6xzemfdenjqsnjv9h8gcfq95s9xarpva5kueeqtf9jqsn0d36zqvf3ypzhsctdwpkx2cqzzsxqzursp5c6dt82gqpn5vucmqtctur0p3cuur6xqgc6348wtz7adtgug9uf2q9qxpqysgq5yt6x946w3664th4h02pug9yhgszpznqyfwzndjk2sxe0878slqkdhgce4mr5ky2ux4gy4yt0vsy536tencls8fvu5wdzyaq548yf4qqu0lyg7';
    const notFound = 'bitcoin:bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4';

    test('on-chain returns payment', () async {
      final result = await service.getPaymentsByQrCodeAsync(onChain);
      expect(result.payments, isNotEmpty);
    });

    test('lightning returns payment', () async {
      final result = await service.getPaymentsByQrCodeAsync(lightning);
      expect(result.payments, isNotEmpty);
    });

    test('zk on-chain returns payment', () async {
      final result = await service.getPaymentsByQrCodeAsync(zkOnChain);
      expect(result.payments, isNotEmpty);
    });

    test('zk lightning returns payment', () async {
      final result = await service.getPaymentsByQrCodeAsync(zkLightning);
      expect(result.payments, isNotEmpty);
    });

    test('not found returns empty', () async {
      final result = await service.getPaymentsByQrCodeAsync(notFound);
      expect(result.payments, isEmpty);
    });
  });

  // Production — Strict (plain-text addresses return empty)
  group('Production (strict)', () {
    late BrantaService service;

    setUpAll(() {
      service = _makeService(BrantaServerBaseUrl.production, PrivacyMode.strict);
    });

    const onChain = 'bitcoin:bc1qu3k6geqdjncaarsu2vq56tt8php5vsug9kasmq';
    const lightning =
        'lightning:lnbc17760n1p4r4tqupp5yuapqmxldkc8smuwa6t8shkdg9gezulu0vc7htepfsvweph8kqfsdphgfexzmn5vysygetkv4kx7ur9wgsyc6t8dp6xu6twvusy27rpd4cxcegcqzzsxq97zvuqsp53564rg6w4xjqy7jamcfqxyy83a0j8nzfs0wpevs37t5ln49q6hrs9qxpqysgq47hpqmv34g25le8sceq9jdvul2nz7ucyu0vucv56nlfe40x7n3jsu8duxjrn6tgvdspt872crk9zeatafznm9c57m039z7wyx6g3njsqkchkdh';
    const zkOnChain =
        'bitcoin:bc1q6745z6cy3u0k9nprurh3x804c4r7u3u8vxca2n?branta_id=z15b5EsbP5LHJrFco38%2BFp%2BHVaiopAY676NCKek8e1Q%2B4a370TyYhvloS8uLCUHfJ4CzeI%2FbOFmFDGpAQszB0gu1pJ1HOQ%3D%3D&branta_secret=c6e9eb30-6258-4432-9847-bdcc4fd4b0db';
    const zkLightning =
        'lightning:lnbc17760n1p4r4flypp5k56kq3v2935rl3glkqu9vngfueud2zj87hjcff3t0kn0yrge0pfqdzjgfexzmn5vysz6gzyv4mx2mr0wpjhygzvd9nksarwd9hxwgz6v4ex7gztdehhwmr9v3nk2gz90psk6urvv5cqzzsxq97zvuqsp5hut3t0l0s5mvp9yr06v4253kqtf452z6c65s6g9sga445hc03v6s9qxpqysgqqm430zkk9uymjgvllr3aha88hc6q59etxasfqswn8r8pfm3dstlpp46azv906xtcj3wzprxup5fxn65a5wymt7zzq9sw9qdzx8rgdhcpk80nrg';
    const notFound = 'bitcoin:bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4';

    test('on-chain plain text returns empty', () async {
      final result = await service.getPaymentsByQrCodeAsync(onChain);
      expect(result.payments, isEmpty);
    });

    test('lightning plain text returns empty', () async {
      final result = await service.getPaymentsByQrCodeAsync(lightning);
      expect(result.payments, isEmpty);
    });

    test('zk on-chain returns payment', () async {
      final result = await service.getPaymentsByQrCodeAsync(zkOnChain);
      expect(result.payments, isNotEmpty);
    });

    test('zk lightning returns payment', () async {
      final result = await service.getPaymentsByQrCodeAsync(zkLightning);
      expect(result.payments, isNotEmpty);
    });

    test('not found plain text returns empty', () async {
      final result = await service.getPaymentsByQrCodeAsync(notFound);
      expect(result.payments, isEmpty);
    });
  });

  // Staging — Strict (plain-text addresses return empty)
  group('Staging (strict)', () {
    late BrantaService service;

    setUpAll(() {
      service = _makeService(BrantaServerBaseUrl.staging, PrivacyMode.strict);
    });

    const onChain = 'bitcoin:bc1qgw3dzmhnyvcswc9r0v0z0ajtp8ulm4nuyeahwr';
    const lightning =
        'lightning:lnbc25830n1p4quq9ppp5zszvpgxtu6uwyur6sf7rayc0meqprqlkv30xjzclh6nzm7gavd8sdzh2d6xzemfdenjqsnjv9h8gcfq95sygetkv4kx7ur9wgsyc6t8dp6xu6twvusy27rpd4cxcefq9pfhgct8d9hxw2gcqzzsxqzursp5fcfx5st7x8rgxra42j47hskmzkcz96mx84xcnvs9lpsmjyzqhw2q9qxpqysgq06lxdc93jjpuqsal9unlfct6wuv0v53yxa8kksl85g3qdw7qks7z9jkq39c6wgzar72luwd38sfj0klyqv0zgns4rq7nafnd8qeuudcqql7at4';
    const zkOnChain =
        'bitcoin:bc1q6745z6cy3u0k9nprurh3x804c4r7u3u8vxca2n?branta_id=z15b5EsbP5LHJrFco38%2BFp%2BHVaiopAY676NCKek8e1Q%2B4a370TyYhvloS8uLCUHfJ4CzeI%2FbOFmFDGpAQszB0gu1pJ1HOQ%3D%3D&branta_secret=c6e9eb30-6258-4432-9847-bdcc4fd4b0db';
    const zkLightning =
        'lightning:lnbc25840n1p4qml83pp5aztzddx4k87m0wkd6wmgxr9753400mcj7sa89sa392krmueqv9qqdz92d6xzemfdenjqsnjv9h8gcfq95s9xarpva5kueeqtf9jqsn0d36zqvf3ypzhsctdwpkx2cqzzsxqzursp5c6dt82gqpn5vucmqtctur0p3cuur6xqgc6348wtz7adtgug9uf2q9qxpqysgq5yt6x946w3664th4h02pug9yhgszpznqyfwzndjk2sxe0878slqkdhgce4mr5ky2ux4gy4yt0vsy536tencls8fvu5wdzyaq548yf4qqu0lyg7';
    const notFound = 'bitcoin:bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4';

    test('on-chain plain text returns empty', () async {
      final result = await service.getPaymentsByQrCodeAsync(onChain);
      expect(result.payments, isEmpty);
    });

    test('lightning plain text returns empty', () async {
      final result = await service.getPaymentsByQrCodeAsync(lightning);
      expect(result.payments, isEmpty);
    });

    test('zk on-chain returns payment', () async {
      final result = await service.getPaymentsByQrCodeAsync(zkOnChain);
      expect(result.payments, isNotEmpty);
    });

    test('zk lightning returns payment', () async {
      final result = await service.getPaymentsByQrCodeAsync(zkLightning);
      expect(result.payments, isNotEmpty);
    });

    test('not found plain text returns empty', () async {
      final result = await service.getPaymentsByQrCodeAsync(notFound);
      expect(result.payments, isEmpty);
    });
  });
}
