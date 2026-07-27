import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_hub/main.dart';
import 'package:home_hub/state/home_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('智家首页展示品牌与设备', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final controller = HomeController();
    await controller.bootstrap();

    await tester.pumpWidget(HomeHubApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('智家'), findsOneWidget);
    expect(find.textContaining('演示'), findsWidgets);

    controller.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
