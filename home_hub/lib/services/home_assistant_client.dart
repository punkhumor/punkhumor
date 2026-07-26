import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/device.dart';

/// Home Assistant REST 客户端：把各类品牌接入 HA 后，本 App 即可统一访问与控制。
class HomeAssistantClient {
  HomeAssistantClient({
    required this.baseUrl,
    required this.token,
    http.Client? client,
  }) : _client = client ?? http.Client();

  String baseUrl;
  String token;
  final http.Client _client;

  Uri _uri(String path) {
    final root = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return Uri.parse('$root$path');
  }

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

  Future<bool> ping() async {
    try {
      final res = await _client
          .get(_uri('/api/'), headers: _headers)
          .timeout(const Duration(seconds: 6));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<List<SmartDevice>> fetchEntities() async {
    final res = await _client
        .get(_uri('/api/states'), headers: _headers)
        .timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) {
      throw Exception('Home Assistant 拉取失败 (${res.statusCode})');
    }
    final list = jsonDecode(res.body) as List<dynamic>;
    final devices = <SmartDevice>[];
    for (final raw in list) {
      final map = raw as Map<String, dynamic>;
      final entityId = map['entity_id'] as String? ?? '';
      if (!_isSupported(entityId)) continue;
      final attrs = (map['attributes'] as Map<String, dynamic>?) ?? {};
      final state = map['state'] as String? ?? 'off';
      final type = _mapType(entityId, attrs);
      devices.add(
        SmartDevice(
          id: 'ha:$entityId',
          name: (attrs['friendly_name'] as String?) ?? entityId,
          room: (attrs['area_id'] as String?) ??
              (attrs['room'] as String?) ??
              'Home Assistant',
          type: type,
          protocol: DeviceProtocol.homeAssistant,
          online: state != 'unavailable' && state != 'unknown',
          powerOn: state == 'on' || state == 'open' || state == 'playing',
          brightness: _brightness(attrs),
          colorTemp: (attrs['color_temp_kelvin'] as num?)?.toDouble() ?? 4000,
          temperature: (attrs['current_temperature'] as num?)?.toDouble() ??
              (attrs['temperature'] as num?)?.toDouble() ??
              26,
          targetTemp: (attrs['temperature'] as num?)?.toDouble() ?? 26,
          humidity: (attrs['humidity'] as num?)?.toDouble() ?? 50,
          position: (attrs['current_position'] as num?)?.toDouble() ??
              (state == 'open' ? 100 : 0),
          fanSpeed: (attrs['percentage'] as num?)?.toInt() ?? 2,
          mode: (attrs['hvac_mode'] as String?) ??
              (attrs['preset_mode'] as String?) ??
              'auto',
          entityId: entityId,
          brand: 'Home Assistant',
          lastSeen: DateTime.now(),
        ),
      );
    }
    return devices;
  }

  Future<void> callService({
    required String domain,
    required String service,
    required String entityId,
    Map<String, dynamic>? data,
  }) async {
    final body = {
      'entity_id': entityId,
      ...?data,
    };
    final res = await _client
        .post(
          _uri('/api/services/$domain/$service'),
          headers: _headers,
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 10));
    if (res.statusCode >= 300) {
      throw Exception('控制失败 (${res.statusCode}): ${res.body}');
    }
  }

  Future<void> applyDevice(SmartDevice device) async {
    final entityId = device.entityId;
    if (entityId == null) return;
    final domain = entityId.split('.').first;

    switch (device.type) {
      case DeviceType.light:
        if (!device.powerOn) {
          await callService(
            domain: domain,
            service: 'turn_off',
            entityId: entityId,
          );
        } else {
          await callService(
            domain: domain,
            service: 'turn_on',
            entityId: entityId,
            data: {
              'brightness_pct': device.brightness.round(),
              if (device.colorTemp > 0)
                'color_temp_kelvin': device.colorTemp.round(),
            },
          );
        }
      case DeviceType.plug:
      case DeviceType.switchPanel:
      case DeviceType.fan:
      case DeviceType.airPurifier:
      case DeviceType.speaker:
        await callService(
          domain: domain,
          service: device.powerOn ? 'turn_on' : 'turn_off',
          entityId: entityId,
        );
      case DeviceType.airConditioner:
        if (!device.powerOn) {
          await callService(
            domain: 'climate',
            service: 'turn_off',
            entityId: entityId,
          );
        } else {
          await callService(
            domain: 'climate',
            service: 'set_temperature',
            entityId: entityId,
            data: {'temperature': device.targetTemp},
          );
          await callService(
            domain: 'climate',
            service: 'set_hvac_mode',
            entityId: entityId,
            data: {'hvac_mode': device.mode},
          );
        }
      case DeviceType.curtain:
        await callService(
          domain: 'cover',
          service: 'set_cover_position',
          entityId: entityId,
          data: {'position': device.position.round()},
        );
      case DeviceType.sensor:
      case DeviceType.camera:
      case DeviceType.unknown:
        break;
    }
  }

  bool _isSupported(String entityId) {
    const prefixes = [
      'light.',
      'switch.',
      'fan.',
      'climate.',
      'cover.',
      'media_player.',
      'sensor.',
      'binary_sensor.',
      'camera.',
    ];
    return prefixes.any(entityId.startsWith);
  }

  DeviceType _mapType(String entityId, Map<String, dynamic> attrs) {
    if (entityId.startsWith('light.')) return DeviceType.light;
    if (entityId.startsWith('switch.')) {
      final deviceClass = attrs['device_class'] as String?;
      return deviceClass == 'outlet' ? DeviceType.plug : DeviceType.switchPanel;
    }
    if (entityId.startsWith('climate.')) return DeviceType.airConditioner;
    if (entityId.startsWith('cover.')) return DeviceType.curtain;
    if (entityId.startsWith('fan.')) {
      final name = ((attrs['friendly_name'] as String?) ?? '').toLowerCase();
      if (name.contains('purif') || name.contains('净化')) {
        return DeviceType.airPurifier;
      }
      return DeviceType.fan;
    }
    if (entityId.startsWith('media_player.')) return DeviceType.speaker;
    if (entityId.startsWith('camera.')) return DeviceType.camera;
    if (entityId.startsWith('sensor.') ||
        entityId.startsWith('binary_sensor.')) {
      return DeviceType.sensor;
    }
    return DeviceType.unknown;
  }

  double _brightness(Map<String, dynamic> attrs) {
    final pct = attrs['brightness_pct'];
    if (pct is num) return pct.toDouble();
    final raw = attrs['brightness'];
    if (raw is num) return (raw.toDouble() / 255 * 100).clamp(0, 100);
    return 80;
  }
}
