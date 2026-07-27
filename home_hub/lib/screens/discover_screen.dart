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

class _DiscoverScreenState extends State<DiscoverScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs =
      TabController(length: 2, vsync: this);

  List<SmartDevice> _found = [];
  final Set<String> _selected = {};
  bool _scanned = false;

  final _host = TextEditingController();
  final _port = TextEditingController(text: '80');
  final _name = TextEditingController();
  final _room = TextEditingController(text: '客厅');
  DeviceProtocol _protocol = DeviceProtocol.tasmota;
  DeviceType _type = DeviceType.plug;
  bool _probing = false;

  @override
  void dispose() {
    _tabs.dispose();
    _host.dispose();
    _port.dispose();
    _name.dispose();
    _room.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final controller = context.read<HomeController>();
    final found = await controller.discover();
    setState(() {
      _found = found.where((d) => d.protocol.isReal).toList();
      _selected
        ..clear()
        ..addAll(found.map((e) => e.id));
      _scanned = true;
    });
  }

  Future<void> _manualAdd() async {
    final host = _host.text.trim();
    if (host.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入设备 IP 或主机名')),
      );
      return;
    }
    setState(() => _probing = true);
    try {
      final device = await context.read<HomeController>().probeManual(
            host: host,
            port: int.tryParse(_port.text.trim()),
            protocol: _protocol,
            name: _name.text,
            room: _room.text,
            type: _type,
          );
      if (!mounted) return;
      if (device == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('探测失败：设备无响应，请确认同网段与端口')),
        );
        return;
      }
      await context.read<HomeController>().addDevices([device]);
      if (!mounted) return;
      Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _probing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final discovering = context.watch<HomeController>().discovering;

    return AtmosphereBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('添加设备'),
          bottom: TabBar(
            controller: _tabs,
            labelColor: AppColors.moss,
            unselectedLabelColor: AppColors.ink.withValues(alpha: 0.5),
            indicatorColor: AppColors.moss,
            tabs: const [
              Tab(text: '手动添加（推荐）'),
              Tab(text: '扫描局域网'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabs,
          children: [
            _manualTab(),
            _scanTab(discovering),
          ],
        ),
      ),
    );
  }

  Widget _manualTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Text(
          '输入电器局域网 IP，选择协议后即可真实开关。支持 Shelly / Tasmota / ESPHome / Yeelight / HTTP，以及后续在「我的」同步 Home Assistant。',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.ink.withValues(alpha: 0.62),
              ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _host,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: 'IP / 主机名',
            hintText: '例如 192.168.1.50',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _port,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: '端口',
            hintText: '80 / 8080 / 55443(Yeelight)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<DeviceProtocol>(
          // ignore: deprecated_member_use
          value: _protocol,
          decoration: const InputDecoration(
            labelText: '协议',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final p in [
              DeviceProtocol.tasmota,
              DeviceProtocol.shelly,
              DeviceProtocol.esphome,
              DeviceProtocol.yeelight,
              DeviceProtocol.http,
            ])
              DropdownMenuItem(value: p, child: Text(p.label)),
          ],
          onChanged: (v) {
            if (v == null) return;
            setState(() {
              _protocol = v;
              if (v == DeviceProtocol.yeelight) {
                _port.text = '55443';
                _type = DeviceType.light;
              } else if (_port.text == '55443') {
                _port.text = '80';
              }
            });
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<DeviceType>(
          // ignore: deprecated_member_use
          value: _type,
          decoration: const InputDecoration(
            labelText: '类型',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final t in [
              DeviceType.plug,
              DeviceType.light,
              DeviceType.switchPanel,
              DeviceType.fan,
              DeviceType.airConditioner,
              DeviceType.curtain,
            ])
              DropdownMenuItem(value: t, child: Text(t.label)),
          ],
          onChanged: (v) {
            if (v != null) setState(() => _type = v);
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _name,
          decoration: const InputDecoration(
            labelText: '名称（可选）',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _room,
          decoration: const InputDecoration(
            labelText: '房间',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _probing ? null : _manualAdd,
          icon: _probing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.link_rounded),
          label: Text(_probing ? '正在探测并接入…' : '探测并添加'),
        ),
      ],
    );
  }

  Widget _scanTab(bool discovering) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '只显示指纹识别成功的智能设备（Shelly / Tasmota / ESPHome / Yeelight / Home Assistant）。'
            '路由器、打印机、手机等开端口主机会被自动过滤，不会再刷出几百条。',
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
              label: Text(discovering ? '正在扫描…' : '开始扫描'),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: !_scanned && !discovering
                ? Center(
                    child: Text(
                      '手机需与电器同一 Wi-Fi；推荐优先用「手动添加」',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppColors.ink.withValues(alpha: 0.45),
                          ),
                    ),
                  )
                : _scanned && _found.isEmpty
                    ? Center(
                        child: Text(
                          '未发现可识别智能设备。\n请改用「手动添加」填入设备 IP。',
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color:
                                        AppColors.ink.withValues(alpha: 0.5),
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
                            '${device.protocol.label} · ${device.host ?? device.endpoint ?? ''}',
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
                        if (!mounted) return;
                        Navigator.pop(context);
                      },
                child: Text('添加 ${_selected.length} 个设备'),
              ),
            ),
        ],
      ),
    );
  }
}
