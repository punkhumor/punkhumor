import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'screens/shell_screen.dart';
import 'state/home_controller.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  ErrorWidget.builder = (details) {
    return Material(
      color: AppColors.cloud,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '界面异常：${details.exceptionAsString()}',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  };

  final controller = HomeController();
  // 先渲染 UI，避免启动阶段任何 IO 卡住白屏
  runApp(HomeHubApp(controller: controller));
  await controller.bootstrap();
}

class HomeHubApp extends StatelessWidget {
  const HomeHubApp({super.key, required this.controller});

  final HomeController controller;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: controller,
      child: MaterialApp(
        title: '智家',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const ShellScreen(),
      ),
    );
  }
}
