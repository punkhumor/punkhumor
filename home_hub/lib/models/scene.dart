import 'package:flutter/material.dart';

class HomeScene {
  const HomeScene({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.actions,
  });

  final String id;
  final String name;
  final String subtitle;
  final IconData icon;
  final List<SceneAction> actions;
}

class SceneAction {
  const SceneAction({
    required this.deviceId,
    this.powerOn,
    this.brightness,
    this.targetTemp,
    this.position,
    this.fanSpeed,
    this.mode,
  });

  final String deviceId;
  final bool? powerOn;
  final double? brightness;
  final double? targetTemp;
  final double? position;
  final int? fanSpeed;
  final String? mode;
}
