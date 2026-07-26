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
  final controller = HomeController();
  await controller.bootstrap();
  runApp(HomeHubApp(controller: controller));
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
