import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:multicast_dns/multicast_dns.dart';
import 'package:uuid/uuid.dart';

import '../models/device.dart';

/// 可控并发的局域网发现：mDNS + 指纹探测（不会打爆端口）
class DiscoveryService {
  static const _uuid = Uuid();

  Future<List<SmartDevice>> discoverLocal({
    Duration timeout = const Duration(seconds: 6),
  }) async {
    final found = <String, SmartDevice>{};

    await Future.wait([
      _discoverMdns(found).timeout(timeout, onTimeout: () {}),
      _scanSubnet(found, timeout: timeout).timeout(
        timeout + const Duration(seconds: 1),
        onTimeout: () {},
      ),
    ]);

    if (found.isEmpty) {
      return demoCandidates();
    }
    return found.values.toList();
  }

  Future<SmartDevice?> probeAddress({
    required String host,
    int? port,
    DeviceProtocol? forceProtocol,
  }) async {
    final ports = port != null
        ? [port]
        : [80, 8080, 8123, 55443, 6053, 1883];
    for (final p in ports) {
      final device = await _fingerprint(host, p, forceProtocol: forceProtocol);
      if (device != null) return device;
    }
    return null;
  }

  Future<void> _discoverMdns(Map<String, SmartDevice> found) async {
    final client = MDnsClient();
    try {
      await client.start();
      const services = [
        '_http._tcp.local',
        '_home-assistant._tcp.local',
        '_shelly._tcp.local',
        '_esphomelib._tcp.local',
      ];
      for (final service in services) {
        await for (final ptr in client.lookup<PtrResourceRecord>(
          ResourceRecordQuery.serverPointer(service),
        ).timeout(const Duration(seconds: 2), onTimeout: (sink) => sink.close())) {
          await for (final srv in client.lookup<SrvResourceRecord>(
            ResourceRecordQuery.service(ptr.domainName),
          ).timeout(const Duration(seconds: 1), onTimeout: (sink) => sink.close())) {
            await for (final ip in client.lookup<IPAddressResourceRecord>(
              ResourceRecordQuery.addressIPv4(srv.target),
            ).timeout(const Duration(seconds: 1), onTimeout: (sink) => sink.close())) {
              final device = await _fingerprint(
                ip.address.address,
                srv.port,
              );
              if (device != null) {
                found[device.id] = device;
              }
            }
          }
        }
      }
    } catch (_) {
      // mDNS 在部分手机 ROM 上不可用，忽略即可
    } finally {
      client.stop();
    }
  }

  Future<void> _scanSubnet(
    Map<String, SmartDevice> found, {
    required Duration timeout,
  }) async {
    final subnet = await guessSubnet();
    if (subnet == null) return;

    final ports = [80, 8080, 8123, 55443];
    final hosts = [for (var i = 1; i <= 254; i++) '$subnet.$i'];
    const concurrency = 32;
    var index = 0;

    Future<void> worker() async {
      while (index < hosts.length) {
        final i = index++;
        final host = hosts[i];
        for (final port in ports) {
          final device = await _fingerprint(
            host,
            port,
            connectTimeout: const Duration(milliseconds: 180),
          );
          if (device != null) {
            found[device.id] = device;
          }
        }
      }
    }

    await Future.wait(
      List.generate(concurrency, (_) => worker()),
    ).timeout(timeout, onTimeout: () => const []);
  }

  Future<SmartDevice?> _fingerprint(
    String host,
    int port, {
    Duration connectTimeout = const Duration(milliseconds: 250),
    DeviceProtocol? forceProtocol,
  }) async {
    try {
      final socket = await Socket.connect(host, port, timeout: connectTimeout);
      await socket.close();
    } catch (_) {
      return null;
    }

    if (forceProtocol == DeviceProtocol.yeelight || port == 55443) {
      return SmartDevice(
        id: 'yeelight:$host:$port',
        name: 'Yeelight $host',
        room: '未分配',
        type: DeviceType.light,
        protocol: DeviceProtocol.yeelight,
        brand: 'Yeelight',
        host: host,
        port: port,
        endpoint: 'tcp://$host:$port',
        lastSeen: DateTime.now(),
      );
    }

    if (port == 8123 || forceProtocol == DeviceProtocol.homeAssistant) {
      return SmartDevice(
        id: 'ha-gateway:$host:$port',
        name: 'Home Assistant ($host)',
        room: '网关',
        type: DeviceType.unknown,
        protocol: DeviceProtocol.homeAssistant,
        brand: 'Home Assistant',
        host: host,
        port: port,
        endpoint: 'http://$host:$port',
        lastSeen: DateTime.now(),
      );
    }

    try {
      final client = http.Client();
      try {
        final res = await client
            .get(Uri.parse('http://$host:$port/'))
            .timeout(const Duration(milliseconds: 700));
        final body = res.body.toLowerCase();
        final server = (res.headers['server'] ?? '').toLowerCase();
        final title = _titleOf(res.body);

        if (body.contains('tasmota') ||
            body.contains('sonoff') ||
            forceProtocol == DeviceProtocol.tasmota) {
          return SmartDevice(
            id: 'tasmota:$host:$port',
            name: title.isEmpty ? 'Tasmota $host' : title,
            room: '未分配',
            type: DeviceType.plug,
            protocol: DeviceProtocol.tasmota,
            brand: 'Tasmota',
            host: host,
            port: port,
            endpoint: 'http://$host:$port',
            lastSeen: DateTime.now(),
          );
        }

        if (body.contains('shelly') ||
            server.contains('shelly') ||
            forceProtocol == DeviceProtocol.shelly) {
          return SmartDevice(
            id: 'shelly:$host:$port',
            name: title.isEmpty ? 'Shelly $host' : title,
            room: '未分配',
            type: DeviceType.plug,
            protocol: DeviceProtocol.shelly,
            brand: 'Shelly',
            host: host,
            port: port,
            endpoint: 'http://$host:$port',
            lastSeen: DateTime.now(),
          );
        }

        if (body.contains('esphome') ||
            forceProtocol == DeviceProtocol.esphome) {
          return SmartDevice(
            id: 'esphome:$host:$port',
            name: title.isEmpty ? 'ESPHome $host' : title,
            room: '未分配',
            type: DeviceType.switchPanel,
            protocol: DeviceProtocol.esphome,
            brand: 'ESPHome',
            host: host,
            port: port,
            endpoint: 'http://$host:$port',
            entityId: 'switch_1',
            lastSeen: DateTime.now(),
          );
        }

        if (body.contains('home assistant')) {
          return SmartDevice(
            id: 'ha-gateway:$host:$port',
            name: 'Home Assistant ($host)',
            room: '网关',
            type: DeviceType.unknown,
            protocol: DeviceProtocol.homeAssistant,
            brand: 'Home Assistant',
            host: host,
            port: port,
            endpoint: 'http://$host:$port',
            lastSeen: DateTime.now(),
          );
        }

        return SmartDevice(
          id: 'http:$host:$port',
          name: title.isEmpty ? 'HTTP 设备 $host' : title,
          room: '未分配',
          type: DeviceType.plug,
          protocol: DeviceProtocol.http,
          brand: '局域网',
          host: host,
          port: port,
          endpoint: 'http://$host:$port',
          lastSeen: DateTime.now(),
        );
      } finally {
        client.close();
      }
    } catch (_) {
      return SmartDevice(
        id: 'tcp:$host:$port',
        name: '可联网设备 $host:$port',
        room: '未分配',
        type: DeviceType.unknown,
        protocol: DeviceProtocol.http,
        brand: '局域网',
        host: host,
        port: port,
        endpoint: 'http://$host:$port',
        lastSeen: DateTime.now(),
      );
    }
  }

  String _titleOf(String html) {
    final match =
        RegExp(r'<title>(.*?)</title>', caseSensitive: false).firstMatch(html);
    return match?.group(1)?.trim() ?? '';
  }

  Future<String?> guessSubnet() async {
    try {
      for (final iface in await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      )) {
        for (final addr in iface.addresses) {
          if (addr.isLoopback) continue;
          final parts = addr.address.split('.');
          if (parts.length == 4) {
            return '${parts[0]}.${parts[1]}.${parts[2]}';
          }
        }
      }
    } catch (_) {}
    return null;
  }

  List<SmartDevice> demoCandidates() {
    final now = DateTime.now();
    return [
      SmartDevice(
        id: _uuid.v4(),
        name: '演示 · 筒灯（仅本地）',
        room: '客厅',
        type: DeviceType.light,
        protocol: DeviceProtocol.demo,
        brand: '演示',
        powerOn: true,
        brightness: 70,
        lastSeen: now,
      ),
      SmartDevice(
        id: _uuid.v4(),
        name: '演示 · 插座（仅本地）',
        room: '阳台',
        type: DeviceType.plug,
        protocol: DeviceProtocol.demo,
        brand: '演示',
        powerOn: false,
        lastSeen: now,
      ),
    ];
  }

  List<SmartDevice> seedHome() {
    final now = DateTime.now();
    return [
      SmartDevice(
        id: 'demo-living-light',
        name: '客厅主灯（演示）',
        room: '客厅',
        type: DeviceType.light,
        protocol: DeviceProtocol.demo,
        brand: '演示',
        powerOn: true,
        brightness: 85,
        colorTemp: 3800,
        lastSeen: now,
      ),
      SmartDevice(
        id: 'demo-kitchen-plug',
        name: '厨房插座（演示）',
        room: '厨房',
        type: DeviceType.plug,
        protocol: DeviceProtocol.demo,
        brand: '演示',
        powerOn: false,
        lastSeen: now,
      ),
      SmartDevice(
        id: 'demo-bed-ac',
        name: '主卧空调（演示）',
        room: '主卧',
        type: DeviceType.airConditioner,
        protocol: DeviceProtocol.demo,
        brand: '演示',
        powerOn: false,
        targetTemp: 26,
        mode: 'cool',
        lastSeen: now,
      ),
    ];
  }

  /// 识别常见响应体，供单测使用
  static DeviceProtocol? detectProtocolFromBody(String body, {String server = ''}) {
    final b = body.toLowerCase();
    final s = server.toLowerCase();
    if (b.contains('tasmota') || b.contains('sonoff')) {
      return DeviceProtocol.tasmota;
    }
    if (b.contains('shelly') || s.contains('shelly')) {
      return DeviceProtocol.shelly;
    }
    if (b.contains('esphome')) return DeviceProtocol.esphome;
    if (b.contains('home assistant')) return DeviceProtocol.homeAssistant;
    return null;
  }
}
