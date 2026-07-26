import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/device.dart';
import '../state/home_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/atmosphere_background.dart';
import '../widgets/device_icon.dart';

class DeviceDetailScreen extends StatefulWidget {
  const DeviceDetailScreen({super.key, required this.deviceId});

  final String deviceId;

  @override
  State<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final controller = context.watch<HomeController>();
    final device = controller.devices
        .cast<SmartDevice?>()
        .firstWhere((d) => d?.id == widget.deviceId, orElse: () => null);

    if (device == null) {
      return const Scaffold(
        body: Center(child: Text('设备不存在')),
      );
    }

    return AtmosphereBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(device.name),
          actions: [
            IconButton(
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('移除设备'),
                    content: Text('确定从智家移除「${device.name}」？'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('取消'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('移除'),
                      ),
                    ],
                  ),
                );
                if (ok == true && context.mounted) {
                  await controller.removeDevice(device.id);
                  if (context.mounted) Navigator.pop(context);
                }
              },
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Center(
              child: DeviceGlyph(
                type: device.type,
                active: device.powerOn && device.online,
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              device.statusText,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(
              '${device.protocol.label} · ${device.brand} · ${device.room}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.ink.withValues(alpha: 0.5),
                  ),
            ),
            if (device.endpoint != null || device.host != null) ...[
              const SizedBox(height: 4),
              Text(
                device.endpoint ?? '${device.host}:${device.port ?? ''}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.ink.withValues(alpha: 0.4),
                    ),
              ),
            ],
            if (device.lastError != null) ...[
              const SizedBox(height: 8),
              Text(
                device.lastError!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.danger,
                    ),
              ),
            ],
            const SizedBox(height: 16),
            if (device.protocol.isReal)
              Center(
                child: OutlinedButton.icon(
                  onPressed: () => controller.refreshDevice(device.id),
                  icon: const Icon(Icons.sync_rounded),
                  label: const Text('从设备读取状态'),
                ),
              ),
            const SizedBox(height: 24),
            if (device.isControllable) ...[
              _Panel(
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('电源'),
                  subtitle: Text(device.powerOn ? '已开启' : '已关闭'),
                  value: device.powerOn,
                  activeThumbColor: Colors.white,
                  activeTrackColor: AppColors.moss,
                  onChanged: device.online
                      ? (v) => controller.updateDevice(device.copyWith(powerOn: v))
                      : null,
                ),
              ),
              const SizedBox(height: 12),
            ],
            ..._controls(context, controller, device),
          ],
        ),
      ),
    );
  }

  List<Widget> _controls(
    BuildContext context,
    HomeController controller,
    SmartDevice device,
  ) {
    switch (device.type) {
      case DeviceType.light:
        return [
          _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('亮度'),
                Slider(
                  value: device.brightness,
                  min: 1,
                  max: 100,
                  onChanged: device.online && device.powerOn
                      ? (v) => controller.updateDevice(
                            device.copyWith(brightness: v),
                            push: false,
                          )
                      : null,
                  onChangeEnd: (v) => controller.updateDevice(
                    device.copyWith(brightness: v, powerOn: true),
                  ),
                ),
                const SizedBox(height: 8),
                const Text('色温 (K)'),
                Slider(
                  value: device.colorTemp,
                  min: 2200,
                  max: 6500,
                  onChanged: device.online && device.powerOn
                      ? (v) => controller.updateDevice(
                            device.copyWith(colorTemp: v),
                            push: false,
                          )
                      : null,
                  onChangeEnd: (v) =>
                      controller.updateDevice(device.copyWith(colorTemp: v)),
                ),
              ],
            ),
          ),
        ];
      case DeviceType.airConditioner:
        return [
          _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('目标温度 ${device.targetTemp.round()}°C'),
                Slider(
                  value: device.targetTemp,
                  min: 16,
                  max: 30,
                  divisions: 14,
                  onChanged: device.online && device.powerOn
                      ? (v) => controller.updateDevice(
                            device.copyWith(targetTemp: v),
                            push: false,
                          )
                      : null,
                  onChangeEnd: (v) =>
                      controller.updateDevice(device.copyWith(targetTemp: v)),
                ),
                const SizedBox(height: 8),
                const Text('模式'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final mode in ['cool', 'heat', 'dry', 'fan', 'auto'])
                      ChoiceChip(
                        label: Text(_modeLabel(mode)),
                        selected: device.mode == mode,
                        onSelected: device.online
                            ? (_) => controller.updateDevice(
                                  device.copyWith(mode: mode, powerOn: true),
                                )
                            : null,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ];
      case DeviceType.curtain:
        return [
          _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('开合 ${device.position.round()}%'),
                Slider(
                  value: device.position,
                  min: 0,
                  max: 100,
                  onChanged: device.online
                      ? (v) => controller.updateDevice(
                            device.copyWith(position: v),
                            push: false,
                          )
                      : null,
                  onChangeEnd: (v) =>
                      controller.updateDevice(device.copyWith(position: v)),
                ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => controller.updateDevice(
                          device.copyWith(position: 0),
                        ),
                        child: const Text('全关'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => controller.updateDevice(
                          device.copyWith(position: 100),
                        ),
                        child: const Text('全开'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ];
      case DeviceType.fan:
      case DeviceType.airPurifier:
        return [
          _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('风速档位 ${device.fanSpeed}'),
                Slider(
                  value: device.fanSpeed.toDouble(),
                  min: 1,
                  max: 5,
                  divisions: 4,
                  onChanged: device.online && device.powerOn
                      ? (v) => controller.updateDevice(
                            device.copyWith(fanSpeed: v.round()),
                            push: false,
                          )
                      : null,
                  onChangeEnd: (v) => controller.updateDevice(
                    device.copyWith(fanSpeed: v.round()),
                  ),
                ),
              ],
            ),
          ),
        ];
      case DeviceType.sensor:
        return [
          _Panel(
            child: Column(
              children: [
                _Metric(label: '温度', value: '${device.temperature.toStringAsFixed(1)}°C'),
                const Divider(height: 24),
                _Metric(label: '湿度', value: '${device.humidity.round()}%'),
              ],
            ),
          ),
        ];
      default:
        return [
          _Panel(
            child: Text(
              device.endpoint == null
                  ? '此设备支持开关控制。接入 Home Assistant 后可获得完整能力。'
                  : '端点：${device.endpoint}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.ink.withValues(alpha: 0.65),
                  ),
            ),
          ),
        ];
    }
  }

  String _modeLabel(String mode) => switch (mode) {
        'cool' => '制冷',
        'heat' => '制热',
        'dry' => '除湿',
        'fan' => '送风',
        _ => '自动',
      };
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line.withValues(alpha: 0.8)),
      ),
      child: child,
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        const Spacer(),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.moss,
              ),
        ),
      ],
    );
  }
}
