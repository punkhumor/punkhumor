import 'package:flutter/material.dart';

import '../models/device.dart';
import '../theme/app_theme.dart';

IconData iconForType(DeviceType type) {
  return switch (type) {
    DeviceType.light => Icons.lightbulb_outline_rounded,
    DeviceType.plug => Icons.power_rounded,
    DeviceType.airConditioner => Icons.ac_unit_rounded,
    DeviceType.curtain => Icons.curtains_rounded,
    DeviceType.airPurifier => Icons.air_rounded,
    DeviceType.fan => Icons.air_rounded,
    DeviceType.switchPanel => Icons.toggle_on_outlined,
    DeviceType.sensor => Icons.sensors_rounded,
    DeviceType.camera => Icons.videocam_outlined,
    DeviceType.speaker => Icons.speaker_outlined,
    DeviceType.unknown => Icons.devices_other_rounded,
  };
}

class DeviceGlyph extends StatelessWidget {
  const DeviceGlyph({
    super.key,
    required this.type,
    this.active = false,
    this.size = 28,
  });

  final DeviceType type;
  final bool active;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.moss : AppColors.ink.withValues(alpha: 0.45);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      width: size + 22,
      height: size + 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active
            ? AppColors.leaf.withValues(alpha: 0.16)
            : AppColors.mist.withValues(alpha: 0.7),
      ),
      child: Icon(iconForType(type), size: size, color: color),
    );
  }
}
