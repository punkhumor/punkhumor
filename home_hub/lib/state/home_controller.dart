import 'dart:async';

import 'package:flutter/material.dart';

import '../models/device.dart';
import '../models/scene.dart';
import '../services/device_control_service.dart';
import '../services/discovery_service.dart';
import '../services/home_assistant_client.dart';
import '../services/storage_service.dart';

class HomeController extends ChangeNotifier {
  HomeController({
    StorageService? storage,
    DiscoveryService? discovery,
    DeviceControlService? control,
  })  : _storage = storage ?? StorageService(),
        _discovery = discovery ?? DiscoveryService(),
        _control = control ?? DeviceControlService();

  final StorageService _storage;
  final DiscoveryService _discovery;
  final DeviceControlService _control;

  final List<SmartDevice> _devices = [];
  String homeName = '我的家';
  String selectedRoom = '全部';
  String haUrl = '';
  String haToken = '';
  bool loading = true;
  bool discovering = false;
  bool controlling = false;
  String? statusMessage;
  HomeAssistantClient? _ha;
  Timer? _refreshTimer;

  List<SmartDevice> get devices => List.unmodifiable(_devices);

  List<String> get rooms {
    final set = <String>{'全部'};
    for (final d in _devices) {
      set.add(d.room);
    }
    return set.toList();
  }

  List<SmartDevice> get filteredDevices {
    if (selectedRoom == '全部') return devices;
    return _devices.where((d) => d.room == selectedRoom).toList();
  }

  int get onlineCount => _devices.where((d) => d.online).length;
  int get onCount => _devices.where((d) => d.powerOn && d.online).length;
  int get realCount =>
      _devices.where((d) => d.protocol.isReal).length;

  List<HomeScene> get scenes => [
        HomeScene(
          id: 'leave',
          name: '离家模式',
          subtitle: '关闭可控制设备',
          icon: Icons.logout_rounded,
          actions: [
            for (final d in _devices.where((e) => e.isControllable))
              SceneAction(deviceId: d.id, powerOn: false),
          ],
        ),
        HomeScene(
          id: 'home',
          name: '归家模式',
          subtitle: '打开客厅灯光',
          icon: Icons.home_rounded,
          actions: [
            for (final d in _devices.where(
              (e) => e.room == '客厅' && e.type == DeviceType.light,
            ))
              SceneAction(deviceId: d.id, powerOn: true, brightness: 80),
          ],
        ),
        HomeScene(
          id: 'sleep',
          name: '睡眠模式',
          subtitle: '灯光调暗',
          icon: Icons.bedtime_rounded,
          actions: [
            for (final d in _devices.where((e) => e.type == DeviceType.light))
              SceneAction(deviceId: d.id, powerOn: true, brightness: 15),
          ],
        ),
        HomeScene(
          id: 'all_off',
          name: '全部关闭',
          subtitle: '真实下发到已接入设备',
          icon: Icons.power_settings_new_rounded,
          actions: [
            for (final d in _devices.where((e) => e.isControllable))
              SceneAction(deviceId: d.id, powerOn: false),
          ],
        ),
      ];

  Future<void> bootstrap() async {
    loading = true;
    notifyListeners();
    try {
      homeName = await _storage.loadHomeName();
      final ha = await _storage.loadHaConfig();
      haUrl = ha.$1;
      haToken = ha.$2;
      if (haUrl.isNotEmpty && haToken.isNotEmpty) {
        _ha = HomeAssistantClient(baseUrl: haUrl, token: haToken);
        _control.haClient = _ha;
      }
      final saved = await _storage.loadDevices();
      _devices
        ..clear()
        ..addAll(saved.isEmpty ? _discovery.seedHome() : saved);
      if (saved.isEmpty) {
        await _persist();
      }
      _startRefreshLoop();
    } catch (e) {
      _devices
        ..clear()
        ..addAll(_discovery.seedHome());
      statusMessage = '启动恢复：$e';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void _startRefreshLoop() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      refreshRealDevices(silent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void selectRoom(String room) {
    selectedRoom = room;
    notifyListeners();
  }

  Future<void> renameHome(String name) async {
    homeName = name.trim().isEmpty ? '我的家' : name.trim();
    await _storage.saveHomeName(homeName);
    notifyListeners();
  }

  Future<void> saveHaConfig(String url, String token) async {
    haUrl = url.trim();
    haToken = token.trim();
    await _storage.saveHaConfig(haUrl, haToken);
    _ha = (haUrl.isNotEmpty && haToken.isNotEmpty)
        ? HomeAssistantClient(baseUrl: haUrl, token: haToken)
        : null;
    _control.haClient = _ha;
    statusMessage = '网关配置已保存';
    notifyListeners();
  }

  Future<bool> testHa() async {
    if (_ha == null) {
      statusMessage = '请先填写 Home Assistant 地址和令牌';
      notifyListeners();
      return false;
    }
    final ok = await _ha!.ping();
    statusMessage = ok ? 'Home Assistant 连接成功' : '无法连接 Home Assistant';
    notifyListeners();
    return ok;
  }

  Future<void> syncHomeAssistant() async {
    if (_ha == null) {
      statusMessage = '请先在「我的」里配置 Home Assistant';
      notifyListeners();
      return;
    }
    loading = true;
    notifyListeners();
    try {
      final remote = await _ha!.fetchEntities();
      _devices.removeWhere((d) => d.protocol == DeviceProtocol.homeAssistant);
      _devices.addAll(remote);
      await _persist();
      statusMessage = '已同步 ${remote.length} 个 Home Assistant 实体';
    } catch (e) {
      statusMessage = '同步失败：$e';
    }
    loading = false;
    notifyListeners();
  }

  Future<List<SmartDevice>> discover() async {
    discovering = true;
    notifyListeners();
    try {
      return await _discovery.discoverLocal();
    } finally {
      discovering = false;
      notifyListeners();
    }
  }

  Future<SmartDevice?> probeManual({
    required String host,
    int? port,
    DeviceProtocol? protocol,
    String? name,
    String? room,
    DeviceType? type,
  }) async {
    final cleaned = host.trim().replaceFirst(RegExp(r'^https?://'), '');
    final hostOnly = cleaned.split('/').first.split(':').first;
    final parsedPort = port ??
        (cleaned.contains(':')
            ? int.tryParse(cleaned.split(':').last.split('/').first)
            : null);

    var device = await _discovery.probeAddress(
      host: hostOnly,
      port: parsedPort,
      forceProtocol: protocol,
    );

    if (device == null && protocol != null) {
      final p = parsedPort ??
          (protocol == DeviceProtocol.yeelight ? 55443 : 80);
      device = SmartDevice(
        id: '${protocol.name}:$hostOnly:$p',
        name: name?.trim().isNotEmpty == true ? name!.trim() : hostOnly,
        room: room?.trim().isNotEmpty == true ? room!.trim() : '未分配',
        type: type ?? DeviceType.plug,
        protocol: protocol,
        brand: protocol.label,
        host: hostOnly,
        port: p,
        endpoint: protocol == DeviceProtocol.yeelight
            ? 'tcp://$hostOnly:$p'
            : 'http://$hostOnly:$p',
        lastSeen: DateTime.now(),
      );
    }

    if (device != null) {
      if (name != null && name.trim().isNotEmpty) {
        device = device.copyWith(name: name.trim());
      }
      if (room != null && room.trim().isNotEmpty) {
        device = device.copyWith(room: room.trim());
      }
      if (type != null) {
        device = device.copyWith(type: type);
      }
      final refreshed = await _control.refresh(device);
      return refreshed;
    }
    return null;
  }

  Future<void> addDevices(List<SmartDevice> incoming) async {
    var added = 0;
    for (final device in incoming) {
      final index = _devices.indexWhere((d) => d.id == device.id);
      if (index >= 0) {
        _devices[index] = device;
      } else {
        _devices.add(device);
        added++;
      }
    }
    await _persist();
    statusMessage = added > 0 ? '已添加 $added 个设备' : '设备已更新';
    notifyListeners();
  }

  Future<void> removeDevice(String id) async {
    _devices.removeWhere((d) => d.id == id);
    await _persist();
    notifyListeners();
  }

  Future<void> updateDevice(SmartDevice device, {bool push = true}) async {
    final index = _devices.indexWhere((d) => d.id == device.id);
    if (index < 0) return;

    // 乐观更新 UI
    _devices[index] = device;
    notifyListeners();
    await _persist();

    if (!push) return;

    controlling = true;
    notifyListeners();
    final result = await _control.apply(device);
    controlling = false;

    final latestIndex = _devices.indexWhere((d) => d.id == device.id);
    if (latestIndex >= 0 && result.device != null) {
      _devices[latestIndex] = result.device!;
    }

    if (!result.ok) {
      statusMessage = '下发失败：${result.message}';
      if (latestIndex >= 0) {
        _devices[latestIndex] = _devices[latestIndex].copyWith(
          online: false,
          lastError: result.message,
        );
      }
    } else if (device.protocol.isReal) {
      statusMessage = '已下发到 ${device.protocol.label}';
    }

    await _persist();
    notifyListeners();
  }

  Future<void> togglePower(SmartDevice device) async {
    if (!device.isControllable) return;
    await updateDevice(device.copyWith(powerOn: !device.powerOn));
  }

  Future<void> refreshDevice(String id) async {
    final index = _devices.indexWhere((d) => d.id == id);
    if (index < 0) return;
    final refreshed = await _control.refresh(_devices[index]);
    _devices[index] = refreshed;
    await _persist();
    statusMessage = refreshed.online ? '状态已更新' : '设备离线：${refreshed.lastError}';
    notifyListeners();
  }

  Future<void> refreshRealDevices({bool silent = false}) async {
    final targets = _devices.where((d) => d.protocol.isReal).toList();
    if (targets.isEmpty) return;
    for (final device in targets) {
      final refreshed = await _control.refresh(device);
      final index = _devices.indexWhere((d) => d.id == device.id);
      if (index >= 0) {
        _devices[index] = refreshed;
      }
    }
    await _persist();
    if (!silent) {
      statusMessage = '已刷新 ${targets.length} 个真实设备';
    }
    notifyListeners();
  }

  Future<void> runScene(HomeScene scene) async {
    for (final action in scene.actions) {
      final index = _devices.indexWhere((d) => d.id == action.deviceId);
      if (index < 0) continue;
      final current = _devices[index];
      final next = current.copyWith(
        powerOn: action.powerOn ?? current.powerOn,
        brightness: action.brightness ?? current.brightness,
        targetTemp: action.targetTemp ?? current.targetTemp,
        position: action.position ?? current.position,
        fanSpeed: action.fanSpeed ?? current.fanSpeed,
        mode: action.mode ?? current.mode,
      );
      await updateDevice(next);
    }
    statusMessage = '已执行「${scene.name}」';
    notifyListeners();
  }

  Future<void> resetDemoDevices() async {
    _devices
      ..removeWhere((d) => d.protocol == DeviceProtocol.demo)
      ..addAll(_discovery.seedHome());
    await _persist();
    statusMessage = '已重置演示设备';
    notifyListeners();
  }

  Future<void> _persist() => _storage.saveDevices(_devices);

  void clearStatus() {
    statusMessage = null;
  }
}
