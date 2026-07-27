import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:home_hub/models/device.dart';
import 'package:home_hub/services/device_control_service.dart';
import 'package:home_hub/services/discovery_service.dart';
import 'package:http/http.dart' as http;

void main() {
  test('协议指纹识别', () {
    expect(
      DiscoveryService.detectProtocolFromBody('<html>Tasmota</html>'),
      DeviceProtocol.tasmota,
    );
    expect(
      DiscoveryService.detectProtocolFromBody('ok', server: 'Shelly'),
      DeviceProtocol.shelly,
    );
    expect(
      DiscoveryService.detectProtocolFromBody('ESPHome web server'),
      DeviceProtocol.esphome,
    );
  });

  test('Tasmota 真实 HTTP 下发', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final hits = <String>[];
    server.listen((req) async {
      hits.add('${req.uri}');
      req.response
        ..statusCode = 200
        ..write(jsonEncode({'POWER': 'ON'}));
      await req.response.close();
    });

    final port = server.port;
    final control = DeviceControlService(client: http.Client());
    final device = SmartDevice(
      id: 't1',
      name: '测试插座',
      room: '实验室',
      type: DeviceType.plug,
      protocol: DeviceProtocol.tasmota,
      host: '127.0.0.1',
      port: port,
      endpoint: 'http://127.0.0.1:$port',
      powerOn: true,
    );

    final result = await control.apply(device);
    expect(result.ok, isTrue);
    expect(hits.any((e) => e.contains('cmnd=Power+ON') || e.contains('Power%20ON') || e.contains('Power ON')), isTrue);

    await server.close(force: true);
  });

  test('Shelly Gen1 真实 HTTP 下发', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var turnedOn = false;
    server.listen((req) async {
      if (req.uri.path == '/relay/0') {
        final turn = req.uri.queryParameters['turn'];
        turnedOn = turn == 'on';
        req.response
          ..statusCode = 200
          ..write(jsonEncode({'ison': turnedOn}));
      } else {
        req.response.statusCode = 404;
      }
      await req.response.close();
    });

    final port = server.port;
    final control = DeviceControlService(client: http.Client());
    final device = SmartDevice(
      id: 's1',
      name: 'Shelly',
      room: '客厅',
      type: DeviceType.plug,
      protocol: DeviceProtocol.shelly,
      host: '127.0.0.1',
      port: port,
      endpoint: 'http://127.0.0.1:$port',
      powerOn: true,
    );

    final result = await control.apply(device);
    expect(result.ok, isTrue);
    expect(turnedOn, isTrue);

    await server.close(force: true);
  });
}
