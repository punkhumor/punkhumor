import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/device.dart';

class StorageService {
  static const _devicesKey = 'devices_v1';
  static const _haUrlKey = 'ha_url';
  static const _haTokenKey = 'ha_token';
  static const _homeNameKey = 'home_name';

  Future<List<SmartDevice>> loadDevices() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_devicesKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => SmartDevice.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveDevices(List<SmartDevice> devices) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(devices.map((e) => e.toJson()).toList());
    await prefs.setString(_devicesKey, raw);
  }

  Future<String> loadHomeName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_homeNameKey) ?? '我的家';
  }

  Future<void> saveHomeName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_homeNameKey, name);
  }

  Future<(String, String)> loadHaConfig() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      prefs.getString(_haUrlKey) ?? '',
      prefs.getString(_haTokenKey) ?? '',
    );
  }

  Future<void> saveHaConfig(String url, String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_haUrlKey, url);
    await prefs.setString(_haTokenKey, token);
  }
}
