import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:multicast_dns/multicast_dns.dart';
import 'package:uuid/uuid.dart';

import '../models/device.dart';

/// 局域网发现：只返回能指纹识别的智能设备，不再把任意开端口主机当成电器。
class DiscoveryService {
  static const _uuid = Uuid();

  Future<List<SmartDevice>> discoverLocal({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final found = <String, SmartDevice>{};

    await Future.wait([
      _discoverMdns(found).timeout(timeout, onTimeout: () {}),
      _scanSubnet(found, timeout: timeout).timeout(
        timeout + const Duration(seconds: 1),
        onTimeout: () {},
      ),
    ]);

    // 扫描为空时返回空列表，不再塞演示垃圾干扰用户
    return found.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<SmartDevice?> probeAddress({
    required String host,
    int? port,
    DeviceProtocol? forceProtocol,
  }) async {
    final ports = port != null
        ? [port]
        : switch (forceProtocol) {
            DeviceProtocol.yeelight => [55443],
            DeviceProtocol.homeAssistant => [8123, 80],
            _ => [80, 8080, 8123, 55443],
          };

    for (final p in ports) {
      final device = await fingerprint(
        host,
        p,
        forceProtocol: forceProtocol,
        allowUnknownHttp: forceProtocol == DeviceProtocol.http,
      );
      if (device != null) return device;
    }

    // 手动添加强制协议时：即使指纹弱也允许创建（用户明确指定）
    if (forceProtocol != null &&
        forceProtocol != DeviceProtocol.demo &&
        forceProtocol != DeviceProtocol.http) {
      final p = port ??
          (forceProtocol == DeviceProtocol.yeelight
              ? 55443
              : forceProtocol == DeviceProtocol.homeAssistant
                  ? 8123
                  : 80);
      final open = await _portOpen(host, p);
      if (!open) return null;
      return SmartDevice(
        id: '${forceProtocol.name}:$host:$p',
        name: '${forceProtocol.label} $host',
        room: '未分配',
        type: forceProtocol == DeviceProtocol.yeelight
            ? DeviceType.light
            : DeviceType.plug,
        protocol: forceProtocol,
        brand: forceProtocol.label,
        host: host,
        port: p,
        endpoint: forceProtocol == DeviceProtocol.yeelight
            ? 'tcp://$host:$p'
            : 'http://$host:$p',
        lastSeen: DateTime.now(),
      );
    }
    return null;
  }

  Future<void> _discoverMdns(Map<String, SmartDevice> found) async {
    final client = MDnsClient();
    try {
      await client.start();
      // 注意：不要扫通用 `_http._tcp`，会把整网打印机/路由都捞进来
      const services = [
        '_home-assistant._tcp.local',
        '_shelly._tcp.local',
        '_esphomelib._tcp.local',
        '_tasmota._tcp.local',
      ];
      for (final service in services) {
        await for (final ptr in client
            .lookup<PtrResourceRecord>(
              ResourceRecordQuery.serverPointer(service),
            )
            .timeout(const Duration(seconds: 2),
                onTimeout: (sink) => sink.close())) {
          await for (final srv in client
              .lookup<SrvResourceRecord>(
                ResourceRecordQuery.service(ptr.domainName),
              )
              .timeout(const Duration(seconds: 1),
                  onTimeout: (sink) => sink.close())) {
            await for (final ip in client
                .lookup<IPAddressResourceRecord>(
                  ResourceRecordQuery.addressIPv4(srv.target),
                )
                .timeout(const Duration(seconds: 1),
                    onTimeout: (sink) => sink.close())) {
              final device = await fingerprint(
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

    // 只扫智能设备常见端口；指纹不过关绝不入库
    final ports = [80, 8080, 8123, 55443];
    final hosts = [for (var i = 1; i <= 254; i++) '$subnet.$i'];
    const concurrency = 24;
    var index = 0;

    Future<void> worker() async {
      while (index < hosts.length) {
        final i = index++;
        final host = hosts[i];
        for (final port in ports) {
          final device = await fingerprint(
            host,
            port,
            connectTimeout: const Duration(milliseconds: 160),
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

  /// 对外暴露便于单测：只有识别成功才返回设备。
  Future<SmartDevice?> fingerprint(
    String host,
    int port, {
    Duration connectTimeout = const Duration(milliseconds: 250),
    DeviceProtocol? forceProtocol,
    bool allowUnknownHttp = false,
  }) async {
    if (!await _portOpen(host, port, timeout: connectTimeout)) {
      return null;
    }

    // Yeelight：必须握手成功，不能“端口开着就算”
    if (forceProtocol == DeviceProtocol.yeelight || port == 55443) {
      final yeelight = await _probeYeelight(host, port);
      if (yeelight != null) return yeelight;
      if (forceProtocol == DeviceProtocol.yeelight) return null;
      // 55443 若不是 Yeelight，继续走 HTTP 指纹
    }

    try {
      final client = http.Client();
      try {
        final res = await client
            .get(Uri.parse('http://$host:$port/'))
            .timeout(const Duration(milliseconds: 800));
        if (res.statusCode >= 500) return null;

        final body = res.body;
        final server = res.headers['server'] ?? '';
        final title = _titleOf(body);
        final protocol = forceProtocol ??
            detectProtocolFromBody(body, server: server);

        if (protocol == DeviceProtocol.tasmota ||
            (forceProtocol == DeviceProtocol.tasmota)) {
          // 再确认 /cm 可用更稳
          final ok = await _tasmotaAlive(client, host, port) ||
              detectProtocolFromBody(body, server: server) ==
                  DeviceProtocol.tasmota ||
              forceProtocol == DeviceProtocol.tasmota;
          if (!ok) return null;
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

        if (protocol == DeviceProtocol.shelly ||
            forceProtocol == DeviceProtocol.shelly) {
          final ok = await _shellyAlive(client, host, port) ||
              detectProtocolFromBody(body, server: server) ==
                  DeviceProtocol.shelly ||
              forceProtocol == DeviceProtocol.shelly;
          if (!ok) return null;
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

        if (protocol == DeviceProtocol.esphome ||
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

        if (protocol == DeviceProtocol.homeAssistant ||
            forceProtocol == DeviceProtocol.homeAssistant ||
            port == 8123) {
          final ha = body.toLowerCase().contains('home assistant') ||
              await _haAlive(client, host, port) ||
              forceProtocol == DeviceProtocol.homeAssistant;
          if (!ha) return null;
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

        // 自动扫描：未知 HTTP 一律丢弃，避免路由器/打印机刷屏
        if (allowUnknownHttp || forceProtocol == DeviceProtocol.http) {
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
        }
        return null;
      } finally {
        client.close();
      }
    } catch (_) {
      // 自动扫描失败即丢弃；不再生成“可联网设备”垃圾项
      return null;
    }
  }

  Future<bool> _portOpen(
    String host,
    int port, {
    Duration timeout = const Duration(milliseconds: 250),
  }) async {
    try {
      final socket = await Socket.connect(host, port, timeout: timeout);
      await socket.close();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<SmartDevice?> _probeYeelight(String host, int port) async {
    try {
      final socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(milliseconds: 400),
      );
      try {
        final cmd = jsonEncode({
          'id': 1,
          'method': 'get_prop',
          'params': ['power'],
        });
        socket.add(utf8.encode('$cmd\r\n'));
        await socket.flush();
        final bytes =
            await socket.timeout(const Duration(milliseconds: 600)).first;
        final reply = utf8.decode(bytes);
        if (!reply.contains('result') && !reply.contains('power')) {
          return null;
        }
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
      } finally {
        await socket.close();
      }
    } catch (_) {
      return null;
    }
  }

  Future<bool> _tasmotaAlive(http.Client client, String host, int port) async {
    try {
      final res = await client
          .get(
            Uri.parse('http://$host:$port/cm')
                .replace(queryParameters: {'cmnd': 'Status 0'}),
          )
          .timeout(const Duration(milliseconds: 700));
      final body = res.body.toLowerCase();
      return res.statusCode < 300 &&
          (body.contains('status') || body.contains('tasmota') || body.contains('power'));
    } catch (_) {
      return false;
    }
  }

  Future<bool> _shellyAlive(http.Client client, String host, int port) async {
    try {
      final res = await client
          .get(Uri.parse('http://$host:$port/shelly'))
          .timeout(const Duration(milliseconds: 700));
      if (res.statusCode < 300 && res.body.toLowerCase().contains('shelly')) {
        return true;
      }
    } catch (_) {}
    try {
      final res = await client
          .get(Uri.parse('http://$host:$port/relay/0'))
          .timeout(const Duration(milliseconds: 700));
      return res.statusCode < 300 && res.body.contains('ison');
    } catch (_) {
      return false;
    }
  }

  Future<bool> _haAlive(http.Client client, String host, int port) async {
    try {
      final res = await client
          .get(Uri.parse('http://$host:$port/'))
          .timeout(const Duration(milliseconds: 700));
      return res.body.toLowerCase().contains('home assistant');
    } catch (_) {
      return false;
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

  /// 识别常见响应体
  static DeviceProtocol? detectProtocolFromBody(
    String body, {
    String server = '',
  }) {
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
