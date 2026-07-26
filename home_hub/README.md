# 智家 Home Hub

米家风格的智能家居控制 App：浏览房间设备、快捷开关、场景联动，并通过 **Home Assistant** 网关统一访问/控制主流可联网电器。

## 功能

- 首页设备宫格：按房间筛选、一键开关
- 设备详情：灯亮度/色温、空调温度/模式、窗帘开合、风扇风速等
- 场景：离家 / 归家 / 睡眠 / 观影
- 局域网发现：扫描常见端口；无结果时提供演示设备
- Home Assistant：配置地址 + 长期令牌后同步实体并下发控制

## 构建 APK

```bash
export PATH="$HOME/flutter/bin:$PATH"
export ANDROID_HOME="$HOME/android-sdk"
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64

cd home_hub
flutter pub get
flutter build apk --release
```

产物：`build/app/outputs/flutter-apk/app-release.apk`

## 真实设备怎么接

1. 在家中部署 [Home Assistant](https://www.home-assistant.io/)
2. 用官方/社区集成接入米家、涂鸦、Matter、ESPHome 等
3. 在 App「我的」填写 HA 地址与长期访问令牌，点「同步设备」

> 说明：市面上品牌协议碎片化，直接兼容「所有」厂商私有云不现实；以 Home Assistant 为总线是当前最稳妥的统一控制路径。
