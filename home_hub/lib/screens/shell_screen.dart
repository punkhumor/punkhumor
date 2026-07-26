import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/home_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/atmosphere_background.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'scenes_screen.dart';

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final message = context.watch<HomeController>().statusMessage;
    if (message != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final controller = context.read<HomeController>();
        if (controller.statusMessage == null) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(controller.statusMessage!)),
        );
        controller.clearStatus();
      });
    }

    final pages = const [
      HomeScreen(),
      ScenesScreen(),
      ProfileScreen(),
    ];

    return AtmosphereBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: KeyedSubtree(
              key: ValueKey(_index),
              child: pages[_index],
            ),
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded, color: AppColors.moss),
              label: '首页',
            ),
            NavigationDestination(
              icon: Icon(Icons.auto_awesome_outlined),
              selectedIcon:
                  Icon(Icons.auto_awesome_rounded, color: AppColors.moss),
              label: '场景',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded, color: AppColors.moss),
              label: '我的',
            ),
          ],
        ),
      ),
    );
  }
}
