import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:uuid/uuid.dart';

import '../models/device.dart';

/// 局域网发现：扫描常见智能设备 HTTP 端口，并提供演示设备。
/// 真正“全品牌”接入推荐走 Home Assistant / Matter 网关。
class DiscoveryService {
  static const _uuid = Uuid();

  Future<List<SmartDevice>> discoverLocal({
    Duration timeout = const Duration(seconds: 4),
  }) async {
    final found = <SmartDevice>[];
    final subnet = await _guessSubnet();
    if (subnet == null) {
      return demoCandidates();
    }

    final ports = [80, 8080, 8123, 1883, 6053];
    final futures = <Future<void>>[];
    for (var i = 1; i <= 254; i++) {
      final host = '$subnet.$i';
      for (final port in ports) {
        futures.add(() async {
          final device = await _probe(host, port, timeout);
          if (device != null) found.add(device);
        }());
      }
    }

    await Future.wait(futures).timeout(
      timeout + const Duration(seconds: 1),
      onTimeout: () => const [],
    );

    if (found.isEmpty) {
      return demoCandidates();
    }
    return found;
  }

  List<SmartDevice> demoCandidates() {
    final now = DateTime.now();
    return [
      SmartDevice(
        id: _uuid.v4(),
        name: '客厅筒灯',
        room: '客厅',
        type: DeviceType.light,
        protocol: DeviceProtocol.demo,
        brand: 'Yeelight',
        powerOn: true,
        brightness: 70,
        lastSeen: now,
      ),
      SmartDevice(
        id: _uuid.v4(),
        name: '主卧空调',
        room: '主卧',
        type: DeviceType.airConditioner,
        protocol: DeviceProtocol.demo,
        brand: '米家',
        powerOn: false,
        targetTemp: 26,
        mode: 'cool',
        lastSeen: now,
      ),
      SmartDevice(
        id: _uuid.v4(),
        name: '晾衣架插座',
        room: '阳台',
        type: DeviceType.plug,
        protocol: DeviceProtocol.demo,
        brand: '涂鸦',
        powerOn: true,
        lastSeen: now,
      ),
      SmartDevice(
        id: _uuid.v4(),
        name: '电动窗帘',
        room: '客厅',
        type: DeviceType.curtain,
        protocol: DeviceProtocol.demo,
        brand: '绿米',
        position: 40,
        lastSeen: now,
      ),
      SmartDevice(
        id: _uuid.v4(),
        name: '空气检测仪',
        room: '书房',
        type: DeviceType.sensor,
        protocol: DeviceProtocol.demo,
        brand: '青萍',
        temperature: 24.6,
        humidity: 52,
        lastSeen: now,
      ),
      SmartDevice(
        id: _uuid.v4(),
        name: '净化器 Pro',
        room: '客厅',
        type: DeviceType.airPurifier,
        protocol: DeviceProtocol.demo,
        brand: '智米',
        powerOn: true,
        fanSpeed: 2,
        lastSeen: now,
      ),
    ];
  }

  List<SmartDevice> seedHome() {
    final now = DateTime.now();
    return [
      SmartDevice(
        id: 'demo-living-light',
        name: '客厅主灯',
        room: '客厅',
        type: DeviceType.light,
        protocol: DeviceProtocol.demo,
        brand: 'Yeelight',
        powerOn: true,
        brightness: 85,
        colorTemp: 3800,
        lastSeen: now,
      ),
      SmartDevice(
        id: 'demo-living-ac',
        name: '客厅空调',
        room: '客厅',
        type: DeviceType.airConditioner,
        protocol: DeviceProtocol.demo,
        brand: '米家',
        powerOn: true,
        targetTemp: 25,
        temperature: 27,
        mode: 'cool',
        lastSeen: now,
      ),
      SmartDevice(
        id: 'demo-living-curtain',
        name: '落地窗窗帘',
        room: '客厅',
        type: DeviceType.curtain,
        protocol: DeviceProtocol.demo,
        brand: '绿米',
        position: 60,
        lastSeen: now,
      ),
      SmartDevice(
        id: 'demo-kitchen-plug',
        name: '咖啡机插座',
        room: '厨房',
        type: DeviceType.plug,
        protocol: DeviceProtocol.demo,
        brand: '涂鸦',
        powerOn: false,
        lastSeen: now,
      ),
      SmartDevice(
        id: 'demo-bed-light',
        name: '床头灯带',
        room: '主卧',
        type: DeviceType.light,
        protocol: DeviceProtocol.demo,
        brand: '飞利浦 Hue',
        powerOn: false,
        brightness: 40,
        colorTemp: 2700,
        lastSeen: now,
      ),
      SmartDevice(
        id: 'demo-bed-fan',
        name: '循环扇',
        room: '主卧',
        type: DeviceType.fan,
        protocol: DeviceProtocol.demo,
        brand: '智米',
        powerOn: false,
        fanSpeed: 1,
        lastSeen: now,
      ),
      SmartDevice(
        id: 'demo-study-sensor',
        name: '温湿度计',
        room: '书房',
        type: DeviceType.sensor,
        protocol: DeviceProtocol.demo,
        brand: '青萍',
        temperature: 25.2,
        humidity: 48,
        lastSeen: now,
      ),
      SmartDevice(
        id: 'demo-bath-switch',
        name: '浴室镜前灯',
        room: '卫生间',
        type: DeviceType.switchPanel,
        protocol: DeviceProtocol.demo,
        brand: '绿米',
        powerOn: true,
        lastSeen: now,
      ),
    ];
  }

  Future<String?> _guessSubnet() async {
    try {
      for (final iface in await NetworkInterface.list()) {
        for (final addr in iface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            final parts = addr.address.split('.');
            if (parts.length == 4) {
              return '${parts[0]}.${parts[1]}.${parts[2]}';
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  Future<SmartDevice?> _probe(String host, int port, Duration timeout) async {
    try {
      final socket = await Socket.connect(host, port, timeout: timeout);
      await socket.close();
      if (port == 8123) {
        return SmartDevice(
          id: 'http:$host:$port',
          name: 'Home Assistant ($host)',
          room: '网关',
          type: DeviceType.unknown,
          protocol: DeviceProtocol.homeAssistant,
          brand: 'Home Assistant',
          endpoint: 'http://$host:$port',
          lastSeen: DateTime.now(),
        );
      }
      // 尝试读取简易 JSON 描述（兼容常见 DIY / ESPHome）
      try {
        final client = HttpClient();
        client.connectionTimeout = timeout;
        final req = await client.getUrl(Uri.parse('http://$host:$port/'));
        final res = await req.close().timeout(timeout);
        final body = await res.transform(utf8.decoder).join();
        client.close(force: true);
        if (body.toLowerCase().contains('esphome') ||
            body.toLowerCase().contains('home assistant')) {
          return SmartDevice(
            id: 'http:$host:$port',
            name: '局域网设备 $host',
            room: '未分配',
            type: DeviceType.unknown,
            protocol: DeviceProtocol.http,
            brand: '局域网',
            endpoint: 'http://$host:$port',
            lastSeen: DateTime.now(),
          );
        }
      } catch (_) {}
      return SmartDevice(
        id: 'tcp:$host:$port',
        name: '可联网设备 $host:$port',
        room: '未分配',
        type: DeviceType.unknown,
        protocol: DeviceProtocol.http,
        brand: '局域网',
        endpoint: 'http://$host:$port',
        lastSeen: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }
}
