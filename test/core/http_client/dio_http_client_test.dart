import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/core/http_client/dio_http_client.dart';

void main() {
  test('download retries directly when an available proxy drops the connection', () async {
    var proxyConnections = 0;
    var directRequests = 0;
    final origin = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    origin.listen((request) async {
      directRequests++;
      request.response.write('profile');
      await request.response.close();
    });
    final proxy = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    proxy.listen((socket) {
      proxyConnections++;
      socket.destroy();
    });
    final tempDir = await Directory.systemTemp.createTemp('hiddify-download-test-');
    addTearDown(() async {
      await proxy.close();
      await origin.close(force: true);
      await tempDir.delete(recursive: true);
    });

    final client = DioHttpClient(timeout: const Duration(seconds: 2), userAgent: 'test', debug: false)
      ..setProxyPort(proxy.port);
    final path = '${tempDir.path}${Platform.pathSeparator}profile.json';
    final response = await client
        .download('http://127.0.0.1:${origin.port}/profile', path)
        .timeout(const Duration(seconds: 15));

    expect(response.statusCode, 200);
    expect(await File(path).readAsString(), 'profile');
    expect(proxyConnections, greaterThan(0));
    expect(directRequests, 1);
  });
}
