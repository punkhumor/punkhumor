import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/home_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/device_tile.dart';
import 'device_detail_screen.dart';
import 'discover_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<HomeController>();
    final devices = controller.filteredDevices;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) => Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 16 * (1 - value)),
                      child: child,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '智家',
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              height: 1.05,
                              color: AppColors.ink,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        controller.homeName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: AppColors.moss,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '统一访问与控制家中可联网电器',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.ink.withValues(alpha: 0.58),
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    _StatChip(
                      label: '在线',
                      value: '${controller.onlineCount}',
                    ),
                    const SizedBox(width: 10),
                    _StatChip(
                      label: '运行中',
                      value: '${controller.onCount}',
                    ),
                    const Spacer(),
                    FilledButton.tonalIcon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const DiscoverScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('添加'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: controller.rooms.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final room = controller.rooms[index];
                      final selected = room == controller.selectedRoom;
                      return ChoiceChip(
                        label: Text(room),
                        selected: selected,
                        onSelected: (_) => controller.selectRoom(room),
                        selectedColor: AppColors.moss,
                        labelStyle: TextStyle(
                          color: selected
                              ? Colors.white
                              : AppColors.ink.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w600,
                        ),
                        backgroundColor: Colors.white.withValues(alpha: 0.75),
                        side: BorderSide(
                          color: selected
                              ? AppColors.moss
                              : AppColors.line,
                        ),
                        showCheckmark: false,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        if (controller.loading)
          const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          )
        else if (devices.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.devices_other_rounded,
                    size: 48,
                    color: AppColors.ink.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 12),
                  const Text('这个房间还没有设备'),
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.92,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final device = devices[index];
                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: Duration(milliseconds: 420 + index * 40),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) => Opacity(
                      opacity: value,
                      child: Transform.scale(
                        scale: 0.96 + 0.04 * value,
                        child: child,
                      ),
                    ),
                    child: DeviceTile(
                      device: device,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                DeviceDetailScreen(deviceId: device.id),
                          ),
                        );
                      },
                      onToggle: () => controller.togglePower(device),
                    ),
                  );
                },
                childCount: devices.length,
              ),
            ),
          ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.moss,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.ink.withValues(alpha: 0.55),
                ),
          ),
        ],
      ),
    );
  }
}
