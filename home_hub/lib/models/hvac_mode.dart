/// 空调 HVAC 模式映射：UI 中文 ↔ 内部码 ↔ Home Assistant 标准枚举
///
/// Home Assistant climate 官方 hvac_mode：
/// off / heat / cool / heat_cool / auto / dry / fan_only
/// 见 https://www.home-assistant.io/integrations/climate/
class HvacMode {
  const HvacMode._(this.code, this.labelZh, this.haMode);

  /// App 内部稳定码（存盘、UI 选中态）
  final String code;

  /// 界面中文
  final String labelZh;

  /// 下发给 Home Assistant 的官方枚举（保证冷≠热）
  final String haMode;

  static const cool = HvacMode._('cool', '制冷', 'cool');
  static const heat = HvacMode._('heat', '制热', 'heat');
  static const dry = HvacMode._('dry', '除湿', 'dry');
  static const fan = HvacMode._('fan', '送风', 'fan_only');
  static const auto = HvacMode._('auto', '自动', 'auto');
  static const heatCool = HvacMode._('heat_cool', '冷暖自动', 'heat_cool');
  static const off = HvacMode._('off', '关闭', 'off');

  static const List<HvacMode> selectable = [
    cool,
    heat,
    dry,
    fan,
    auto,
  ];

  static const Map<String, HvacMode> _byCode = {
    'cool': cool,
    'heat': heat,
    'dry': dry,
    'fan': fan,
    'fan_only': fan, // 兼容从 HA 读回的值
    'auto': auto,
    'heat_cool': heatCool,
    'off': off,
  };

  /// 从 UI/存盘/HA 读回的字符串解析；未知值回退 auto，绝不静默把 cool 当成 heat
  static HvacMode parse(String? raw) {
    if (raw == null || raw.isEmpty) return auto;
    final key = raw.trim().toLowerCase();
    return _byCode[key] ?? auto;
  }

  static String labelOf(String? raw) => parse(raw).labelZh;

  static String toHa(String? raw) => parse(raw).haMode;

  static String fromHa(String? haRaw) => parse(haRaw).code;
}
