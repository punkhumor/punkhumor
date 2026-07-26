import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/device.dart';
import '../state/home_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/atmosphere_background.dart';
import '../widgets/device_icon.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  List<SmartDevice> _found = [];
  final Set<String> _selected = {};
  bool _scanned = false;

  Future<void> _scan() async {
    final controller = context.read<HomeController>();
    final found = await controller.discover();
    setState(() {
      _found = found;
      _selected
        ..clear()
        ..addAll(found.map((e) => e.id));
      _scanned = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final discovering = context.watch<HomeController>().discovering;

    return AtmosphereBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('添加设备')),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '扫描局域网中的可联网电器，或加载演示设备。完整品牌覆盖建议接入 Home Assistant。',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.ink.withValues(alpha: 0.62),
                    ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: discovering ? null : _scan,
                  icon: discovering
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.wifi_find_rounded),
                  label: Text(discovering ? '正在发现…' : '开始发现'),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: !_scanned && !discovering
                    ? Center(
                        child: Text(
                          '点击上方按钮扫描附近设备',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: AppColors.ink.withValues(alpha: 0.45),
                              ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _found.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final device = _found[index];
                          final checked = _selected.contains(device.id);
                          return Material(
                            color: Colors.white.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(18),
                            child: CheckboxListTile(
                              value: checked,
                              onChanged: (v) {
                                setState(() {
                                  if (v == true) {
                                    _selected.add(device.id);
                                  } else {
                                    _selected.remove(device.id);
                                  }
                                });
                              },
                              secondary: DeviceGlyph(
                                type: device.type,
                                active: true,
                                size: 22,
                              ),
                              title: Text(device.name),
                              subtitle: Text(
                                '${device.brand} · ${device.room}'
                                '${device.endpoint != null ? '\n${device.endpoint}' : ''}',
                              ),
                              controlAffinity: ListTileControlAffinity.trailing,
                            ),
                          );
                        },
                      ),
              ),
              if (_found.isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _selected.isEmpty
                        ? null
                        : () async {
                            final selected = _found
                                .where((d) => _selected.contains(d.id))
                                .toList();
                            await context
                                .read<HomeController>()
                                .addDevices(selected);
                            if (context.mounted) Navigator.pop(context);
                          },
                    child: Text('添加 ${_selected.length} 个设备'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
