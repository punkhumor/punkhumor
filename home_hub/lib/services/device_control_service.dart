import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/device.dart';
import 'home_assistant_client.dart';

class ControlResult {
  const ControlResult({
    required this.ok,
    this.message,
    this.device,
  });

  final bool ok;
  final String? message;
  final SmartDevice? device;
}

/// 真实下发：Shelly / Tasmota / ESPHome / Yeelight / 通用 HTTP / Home Assistant
class DeviceControlService {
  DeviceControlService({
    http.Client? client,
    this.haClient,
  }) : _client = client ?? http.Client();

  final http.Client _client;
  HomeAssistantClient? haClient;

  Future<ControlResult> apply(SmartDevice device) async {
    try {
      switch (device.protocol) {
        case DeviceProtocol.demo:
          return ControlResult(ok: true, device: device.copyWith(clearError: true));
        case DeviceProtocol.homeAssistant:
          if (haClient == null) {
            return const ControlResult(ok: false, message: '未配置 Home Assistant');
          }
          await haClient!.applyDevice(device);
          return ControlResult(
            ok: true,
            device: device.copyWith(online: true, clearError: true, lastSeen: DateTime.now()),
          );
        case DeviceProtocol.shelly:
          return ControlResult(ok: true, device: await _shelly(device));
        case DeviceProtocol.tasmota:
          return ControlResult(ok: true, device: await _tasmota(device));
        case DeviceProtocol.esphome:
          return ControlResult(ok: true, device: await _esphome(device));
        case DeviceProtocol.yeelight:
          return ControlResult(ok: true, device: await _yeelight(device));
        case DeviceProtocol.http:
          return ControlResult(ok: true, device: await _genericHttp(device));
        case DeviceProtocol.mqtt:
          return const ControlResult(
            ok: false,
            message: 'MQTT 请通过 Home Assistant 或手动 HTTP/Tasmota 接入',
          );
      }
    } catch (e) {
      return ControlResult(
        ok: false,
        message: e.toString(),
        device: device.copyWith(online: false, lastError: '$e'),
      );
    }
  }

  Future<SmartDevice> refresh(SmartDevice device) async {
    try {
      switch (device.protocol) {
        case DeviceProtocol.shelly:
          return _shellyStatus(device);
        case DeviceProtocol.tasmota:
          return _tasmotaStatus(device);
        case DeviceProtocol.esphome:
          return _esphomeStatus(device);
        case DeviceProtocol.yeelight:
          return _yeelightStatus(device);
        case DeviceProtocol.http:
          return _genericHttpStatus(device);
        case DeviceProtocol.homeAssistant:
          return device.copyWith(online: true, clearError: true);
        case DeviceProtocol.demo:
        case DeviceProtocol.mqtt:
          return device.copyWith(online: true, clearError: true);
      }
    } catch (e) {
      return device.copyWith(online: false, lastError: '$e');
    }
  }

  Future<SmartDevice> _shelly(SmartDevice device) async {
    final base = device.baseUrl;
    // Gen1 relay
    try {
      final turn = device.powerOn ? 'on' : 'off';
      final uri = Uri.parse('$base/relay/0?turn=$turn');
      final res = await _client.get(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode < 300) {
        return device.copyWith(
          online: true,
          clearError: true,
          lastSeen: DateTime.now(),
        );
      }
    } catch (_) {}

    // Gen2 RPC
    final action = device.powerOn ? 'on' : 'off';
    final uri = Uri.parse('$base/rpc/Switch.Set?id=0&on=${device.powerOn}');
    final res = await _client.get(uri).timeout(const Duration(seconds: 4));
    if (res.statusCode >= 300) {
      throw Exception('Shelly 控制失败 (${res.statusCode}) $action');
    }
    return device.copyWith(online: true, clearError: true, lastSeen: DateTime.now());
  }

  Future<SmartDevice> _shellyStatus(SmartDevice device) async {
    final base = device.baseUrl;
    try {
      final res = await _client
          .get(Uri.parse('$base/relay/0'))
          .timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final map = jsonDecode(res.body) as Map<String, dynamic>;
        return device.copyWith(
          online: true,
          powerOn: map['ison'] == true,
          clearError: true,
          lastSeen: DateTime.now(),
        );
      }
    } catch (_) {}
    final res = await _client
        .get(Uri.parse('$base/rpc/Switch.GetStatus?id=0'))
        .timeout(const Duration(seconds: 3));
    final map = jsonDecode(res.body) as Map<String, dynamic>;
    return device.copyWith(
      online: true,
      powerOn: map['output'] == true,
      clearError: true,
      lastSeen: DateTime.now(),
    );
  }

  Future<SmartDevice> _tasmota(SmartDevice device) async {
    final base = device.baseUrl;
    final cmd = device.powerOn ? 'Power ON' : 'Power OFF';
    final uri = Uri.parse('$base/cm').replace(queryParameters: {'cmnd': cmd});
    final res = await _client.get(uri).timeout(const Duration(seconds: 4));
    if (res.statusCode >= 300) {
      throw Exception('Tasmota 控制失败 (${res.statusCode})');
    }
    if (device.type == DeviceType.light && device.powerOn) {
      final dim = Uri.parse('$base/cm').replace(
        queryParameters: {'cmnd': 'Dimmer ${device.brightness.round()}'},
      );
      await _client.get(dim).timeout(const Duration(seconds: 4));
    }
    return device.copyWith(online: true, clearError: true, lastSeen: DateTime.now());
  }

  Future<SmartDevice> _tasmotaStatus(SmartDevice device) async {
    final base = device.baseUrl;
    final uri = Uri.parse('$base/cm').replace(queryParameters: {'cmnd': 'STATUS 11'});
    final res = await _client.get(uri).timeout(const Duration(seconds: 4));
    if (res.statusCode >= 300) throw Exception('Tasmota 状态失败');
    final map = jsonDecode(res.body) as Map<String, dynamic>;
    final status = map['StatusSTS'] as Map<String, dynamic>? ?? map;
    final power = '${status['POWER'] ?? status['POWER1'] ?? ''}'.toUpperCase();
    return device.copyWith(
      online: true,
      powerOn: power == 'ON',
      clearError: true,
      lastSeen: DateTime.now(),
    );
  }

  Future<SmartDevice> _esphome(SmartDevice device) async {
    final base = device.baseUrl;
    final id = device.entityId ?? 'switch_1';
    final path = device.powerOn ? '/switch/$id/turn_on' : '/switch/$id/turn_off';
    var res = await _client.post(Uri.parse('$base$path')).timeout(const Duration(seconds: 4));
    if (res.statusCode >= 300) {
      final lightPath =
          device.powerOn ? '/light/$id/turn_on' : '/light/$id/turn_off';
      res = await _client
          .post(
            Uri.parse('$base$lightPath'),
            headers: {'Content-Type': 'application/json'},
            body: device.powerOn
                ? jsonEncode({
                    'state': 'ON',
                    'brightness': (device.brightness / 100 * 255).round(),
                  })
                : jsonEncode({'state': 'OFF'}),
          )
          .timeout(const Duration(seconds: 4));
      if (res.statusCode >= 300) {
        throw Exception('ESPHome 控制失败 (${res.statusCode})');
      }
    }
    return device.copyWith(online: true, clearError: true, lastSeen: DateTime.now());
  }

  Future<SmartDevice> _esphomeStatus(SmartDevice device) async {
    final base = device.baseUrl;
    final res =
        await _client.get(Uri.parse(base)).timeout(const Duration(seconds: 3));
    if (res.statusCode >= 300) throw Exception('ESPHome 离线');
    return device.copyWith(online: true, clearError: true, lastSeen: DateTime.now());
  }

  Future<SmartDevice> _yeelight(SmartDevice device) async {
    final host = device.host;
    if (host == null) throw Exception('Yeelight 缺少 IP');
    final port = device.port ?? 55443;
    final cmds = <Map<String, dynamic>>[
      {
        'id': 1,
        'method': 'set_power',
        'params': [device.powerOn ? 'on' : 'off', 'smooth', 300],
      },
    ];
    if (device.powerOn && device.type == DeviceType.light) {
      cmds.add({
        'id': 2,
        'method': 'set_bright',
        'params': [device.brightness.round().clamp(1, 100), 'smooth', 300],
      });
      cmds.add({
        'id': 3,
        'method': 'set_ct_abx',
        'params': [device.colorTemp.round().clamp(1700, 6500), 'smooth', 300],
      });
    }
    final socket = await Socket.connect(host, port, timeout: const Duration(seconds: 3));
    try {
      for (final cmd in cmds) {
        socket.add(utf8.encode('${jsonEncode(cmd)}\r\n'));
        await socket.flush();
        await Future<void>.delayed(const Duration(milliseconds: 80));
      }
      await Future<void>.delayed(const Duration(milliseconds: 120));
    } finally {
      await socket.close();
    }
    return device.copyWith(online: true, clearError: true, lastSeen: DateTime.now());
  }

  Future<SmartDevice> _yeelightStatus(SmartDevice device) async {
    final host = device.host;
    if (host == null) throw Exception('Yeelight 缺少 IP');
    final port = device.port ?? 55443;
    final socket = await Socket.connect(host, port, timeout: const Duration(seconds: 3));
    try {
      final cmd = jsonEncode({
        'id': 1,
        'method': 'get_prop',
        'params': ['power', 'bright', 'ct'],
      });
      socket.add(utf8.encode('$cmd\r\n'));
      await socket.flush();
      final bytes = await socket.timeout(const Duration(seconds: 2)).first;
      final reply = utf8.decode(bytes);
      final map = jsonDecode(reply.trim()) as Map<String, dynamic>;
      final result = (map['result'] as List<dynamic>?) ?? [];
      final power = result.isNotEmpty ? '${result[0]}' : 'off';
      final bright = result.length > 1 ? double.tryParse('${result[1]}') ?? device.brightness : device.brightness;
      final ct = result.length > 2 ? double.tryParse('${result[2]}') ?? device.colorTemp : device.colorTemp;
      return device.copyWith(
        online: true,
        powerOn: power == 'on',
        brightness: bright,
        colorTemp: ct,
        clearError: true,
        lastSeen: DateTime.now(),
      );
    } finally {
      await socket.close();
    }
  }

  Future<SmartDevice> _genericHttp(SmartDevice device) async {
    final base = device.baseUrl;
    if (base.isEmpty) throw Exception('缺少设备地址');
    // 约定：/on /off 或 ?power=1/0
    final candidates = device.powerOn
        ? ['$base/on', '$base/?power=1', '$base/relay?state=1']
        : ['$base/off', '$base/?power=0', '$base/relay?state=0'];
    Object? lastError;
    for (final url in candidates) {
      try {
        final res =
            await _client.get(Uri.parse(url)).timeout(const Duration(seconds: 3));
        if (res.statusCode < 300) {
          return device.copyWith(
            online: true,
            clearError: true,
            lastSeen: DateTime.now(),
          );
        }
        lastError = 'HTTP ${res.statusCode}';
      } catch (e) {
        lastError = e;
      }
    }
    throw Exception('HTTP 控制失败: $lastError');
  }

  Future<SmartDevice> _genericHttpStatus(SmartDevice device) async {
    final base = device.baseUrl;
    if (base.isEmpty) throw Exception('缺少设备地址');
    final res =
        await _client.get(Uri.parse(base)).timeout(const Duration(seconds: 3));
    if (res.statusCode >= 300) throw Exception('设备无响应');
    return device.copyWith(online: true, clearError: true, lastSeen: DateTime.now());
  }
}
