import 'package:flutter_test/flutter_test.dart';
import 'package:home_hub/models/hvac_mode.dart';

void main() {
  test('制冷制热映射不会串，且对齐 HA 官方枚举', () {
    expect(HvacMode.toHa('cool'), 'cool');
    expect(HvacMode.toHa('heat'), 'heat');
    expect(HvacMode.toHa('cool'), isNot(equals(HvacMode.toHa('heat'))));

    expect(HvacMode.labelOf('cool'), '制冷');
    expect(HvacMode.labelOf('heat'), '制热');

    // UI 送风 → HA fan_only（官方名）
    expect(HvacMode.toHa('fan'), 'fan_only');
    // HA 读回 fan_only → UI 仍是送风
    expect(HvacMode.fromHa('fan_only'), 'fan');
    expect(HvacMode.labelOf('fan_only'), '送风');
  });

  test('未知模式不会误落到 heat 或 cool', () {
    expect(HvacMode.parse('garbage').code, 'auto');
    expect(HvacMode.toHa('garbage'), 'auto');
  });
}
