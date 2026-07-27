import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:home_hub/models/device.dart';
import 'package:home_hub/services/device_control_service.dart';
import 'package:home_hub/services/discovery_service.dart';
import 'package:http/http.dart' as http;

/// 端到端证明：假路由器不会入库；Tasmota 能识别且能真实下发。
void main() {
  test('自动扫描不会把普通 HTTP 主机当成设备', () async {
    final junk = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    junk.listen((req) async {
      req.response
        ..statusCode = 200
        ..headers.set('server', 'nginx')
        ..write('<html><title>Router Admin</title><body>welcome</body></html>');
      await req.response.close();
    });

    final discovery = DiscoveryService();
    final device = await discovery.fingerprint(
      '127.0.0.1',
      junk.port,
    );
    expect(device, isNull, reason: '普通路由/网页不应出现在扫描结果');

    await junk.close(force: true);
  });

  test('Tasmota 能识别，且开关会真实打到设备', () async {
    var power = false;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      final path = req.uri.path;
      if (path == '/' || path.isEmpty) {
        req.response
          ..statusCode = 200
          ..write('<html><title>Tasmota</title>Tasmota</html>');
      } else if (path == '/cm') {
        final cmnd = req.uri.queryParameters['cmnd'] ?? '';
        if (cmnd.toUpperCase().contains('POWER ON')) {
          power = true;
          req.response.write(jsonEncode({'POWER': 'ON'}));
        } else if (cmnd.toUpperCase().contains('POWER OFF')) {
          power = false;
          req.response.write(jsonEncode({'POWER': 'OFF'}));
        } else if (cmnd.toUpperCase().startsWith('STATUS')) {
          req.response.write(jsonEncode({
            'Status': {'FriendlyName': ['Proof Plug']},
            'StatusSTS': {'POWER': power ? 'ON' : 'OFF'},
          }));
        } else {
          req.response.write(jsonEncode({'POWER': power ? 'ON' : 'OFF'}));
        }
      } else {
        req.response.statusCode = 404;
      }
      await req.response.close();
    });

    final port = server.port;
    final discovery = DiscoveryService();
    final found = await discovery.fingerprint('127.0.0.1', port);
    expect(found, isNotNull);
    expect(found!.protocol, DeviceProtocol.tasmota);

    final control = DeviceControlService(client: http.Client());
    final onResult = await control.apply(found.copyWith(powerOn: true));
    expect(onResult.ok, isTrue);
    expect(power, isTrue, reason: '设备端电源状态必须被真正改写');

    final offResult = await control.apply(found.copyWith(powerOn: false));
    expect(offResult.ok, isTrue);
    expect(power, isFalse);

    await server.close(force: true);
  });

  test('Shelly 能识别并真实下发', () async {
    var ison = false;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      if (req.uri.path == '/' ) {
        req.response
          ..headers.set('server', 'Shelly')
          ..write('shelly');
      } else if (req.uri.path == '/shelly') {
        req.response.write(jsonEncode({'type': 'SHSW-1', 'mac': 'AA'}));
      } else if (req.uri.path == '/relay/0') {
        final turn = req.uri.queryParameters['turn'];
        if (turn == 'on') ison = true;
        if (turn == 'off') ison = false;
        req.response.write(jsonEncode({'ison': ison}));
      } else {
        req.response.statusCode = 404;
      }
      await req.response.close();
    });

    final port = server.port;
    final found = await DiscoveryService().fingerprint('127.0.0.1', port);
    expect(found, isNotNull);
    expect(found!.protocol, DeviceProtocol.shelly);

    final result = await DeviceControlService(client: http.Client())
        .apply(found.copyWith(powerOn: true));
    expect(result.ok, isTrue);
    expect(ison, isTrue);

    await server.close(force: true);
  });
}
