import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/home_controller.dart';
import '../theme/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _homeName;
  late final TextEditingController _haUrl;
  late final TextEditingController _haToken;

  @override
  void initState() {
    super.initState();
    final c = context.read<HomeController>();
    _homeName = TextEditingController(text: c.homeName);
    _haUrl = TextEditingController(text: c.haUrl);
    _haToken = TextEditingController(text: c.haToken);
  }

  @override
  void dispose() {
    _homeName.dispose();
    _haUrl.dispose();
    _haToken.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<HomeController>();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      children: [
        Text('我的', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 6),
        Text(
          '网关与家庭设置',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.ink.withValues(alpha: 0.55),
              ),
        ),
        const SizedBox(height: 20),
        _Section(
          title: '家庭',
          child: Column(
            children: [
              TextField(
                controller: _homeName,
                decoration: const InputDecoration(
                  labelText: '家庭名称',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => controller.renameHome(_homeName.text),
                  child: const Text('保存'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Section(
          title: 'Home Assistant 网关',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '把米家、涂鸦、Matter、ESPHome 等设备接入 Home Assistant 后，在此填写地址与长期访问令牌，即可统一访问与控制。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.ink.withValues(alpha: 0.6),
                    ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _haUrl,
                decoration: const InputDecoration(
                  labelText: '地址，例如 http://192.168.1.10:8123',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _haToken,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '长期访问令牌',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed: () async {
                      await controller.saveHaConfig(
                        _haUrl.text,
                        _haToken.text,
                      );
                    },
                    child: const Text('保存配置'),
                  ),
                  OutlinedButton(
                    onPressed: () => controller.testHa(),
                    child: const Text('测试连接'),
                  ),
                  OutlinedButton(
                    onPressed: () => controller.syncHomeAssistant(),
                    child: const Text('同步设备'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Section(
          title: '关于智家',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '版本 1.1.0',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                '智家可真实控制局域网 Shelly / Tasmota / ESPHome / Yeelight，也可通过 Home Assistant 统一接入米家、涂鸦、Matter 等。',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.ink.withValues(alpha: 0.65),
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                '设备 ${controller.devices.length} · 真实 ${controller.realCount}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.ink.withValues(alpha: 0.5),
                    ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: () => controller.refreshRealDevices(),
                    child: const Text('刷新真实设备'),
                  ),
                  OutlinedButton(
                    onPressed: () => controller.resetDemoDevices(),
                    child: const Text('重置演示设备'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
