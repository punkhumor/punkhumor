import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/device.dart';
import '../models/scene.dart';
import '../services/discovery_service.dart';
import '../services/home_assistant_client.dart';
import '../services/storage_service.dart';

class HomeController extends ChangeNotifier {
  HomeController({
    StorageService? storage,
    DiscoveryService? discovery,
  })  : _storage = storage ?? StorageService(),
        _discovery = discovery ?? DiscoveryService();

  final StorageService _storage;
  final DiscoveryService _discovery;

  final List<SmartDevice> _devices = [];
  String homeName = '我的家';
  String selectedRoom = '全部';
  String haUrl = '';
  String haToken = '';
  bool loading = true;
  bool discovering = false;
  String? statusMessage;
  HomeAssistantClient? _ha;

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

  List<HomeScene> get scenes => [
        HomeScene(
          id: 'leave',
          name: '离家模式',
          subtitle: '关闭灯光、插座与空调',
          icon: Icons.logout_rounded,
          actions: [
            for (final d in _devices.where((e) => e.isControllable))
              SceneAction(deviceId: d.id, powerOn: false),
          ],
        ),
        HomeScene(
          id: 'home',
          name: '归家模式',
          subtitle: '点亮客厅，空调舒适运行',
          icon: Icons.home_rounded,
          actions: [
            for (final d in _devices.where((e) => e.room == '客厅' && e.type == DeviceType.light))
              SceneAction(deviceId: d.id, powerOn: true, brightness: 80),
            for (final d in _devices.where((e) => e.type == DeviceType.airConditioner))
              SceneAction(
                deviceId: d.id,
                powerOn: true,
                targetTemp: 26,
                mode: 'cool',
              ),
          ],
        ),
        HomeScene(
          id: 'sleep',
          name: '睡眠模式',
          subtitle: '主卧柔光，窗帘半开',
          icon: Icons.bedtime_rounded,
          actions: [
            for (final d in _devices.where((e) => e.room == '主卧' && e.type == DeviceType.light))
              SceneAction(deviceId: d.id, powerOn: true, brightness: 20),
            for (final d in _devices.where((e) => e.type == DeviceType.curtain))
              SceneAction(deviceId: d.id, position: 30),
            for (final d in _devices.where((e) => e.room != '主卧' && e.type == DeviceType.light))
              SceneAction(deviceId: d.id, powerOn: false),
          ],
        ),
        HomeScene(
          id: 'movie',
          name: '观影模式',
          subtitle: '压暗灯光，拉开窗帘',
          icon: Icons.movie_rounded,
          actions: [
            for (final d in _devices.where((e) => e.type == DeviceType.light))
              SceneAction(deviceId: d.id, powerOn: true, brightness: 15),
            for (final d in _devices.where((e) => e.type == DeviceType.curtain))
              SceneAction(deviceId: d.id, position: 100),
          ],
        ),
      ];

  Future<void> bootstrap() async {
    loading = true;
    notifyListeners();
    homeName = await _storage.loadHomeName();
    final ha = await _storage.loadHaConfig();
    haUrl = ha.$1;
    haToken = ha.$2;
    if (haUrl.isNotEmpty && haToken.isNotEmpty) {
      _ha = HomeAssistantClient(baseUrl: haUrl, token: haToken);
    }
    final saved = await _storage.loadDevices();
    _devices
      ..clear()
      ..addAll(saved.isEmpty ? _discovery.seedHome() : saved);
    if (saved.isEmpty) {
      await _persist();
    }
    loading = false;
    notifyListeners();
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
    statusMessage = '网关配置已保存';
    notifyListeners();
  }

  Future<bool> testHa() async {
    if (_ha == null) return false;
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
      final found = await _discovery.discoverLocal();
      return found;
    } finally {
      discovering = false;
      notifyListeners();
    }
  }

  Future<void> addDevices(List<SmartDevice> incoming) async {
    for (final device in incoming) {
      final exists = _devices.any((d) => d.id == device.id);
      if (!exists) {
        _devices.add(device);
      }
    }
    await _persist();
    statusMessage = '已添加 ${incoming.length} 个设备';
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
    _devices[index] = device;
    notifyListeners();
    await _persist();
    if (push) {
      await _pushControl(device);
    }
  }

  Future<void> togglePower(SmartDevice device) async {
    if (!device.isControllable || !device.online) return;
    await updateDevice(device.copyWith(powerOn: !device.powerOn));
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
      _devices[index] = next;
      await _pushControl(next);
    }
    await _persist();
    statusMessage = '已执行「${scene.name}」';
    notifyListeners();
  }

  Future<void> _pushControl(SmartDevice device) async {
    try {
      switch (device.protocol) {
        case DeviceProtocol.homeAssistant:
          if (_ha != null) await _ha!.applyDevice(device);
        case DeviceProtocol.http:
          // HTTP 设备可按 endpoint 扩展；演示模式下仅本地状态。
          break;
        case DeviceProtocol.tuya:
        case DeviceProtocol.demo:
          break;
      }
    } catch (e) {
      statusMessage = '下发失败：$e';
      notifyListeners();
    }
  }

  Future<void> _persist() => _storage.saveDevices(_devices);

  void clearStatus() {
    statusMessage = null;
  }
}
