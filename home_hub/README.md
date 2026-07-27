# 智家 Home Hub

米家风格智能家居控制 App。**1.1.0 起可真实下发控制**局域网设备。

## 为什么旧版“不可用”

1. Google Fonts 在线拉字体会在国内失败 → 界面空白/卡死  
2. 扫描开了上千并发连接 → 手机端易卡死  
3. HTTP 设备只有 UI 状态，没有真正发包  

## 1.1.0 真控制能力

| 协议 | 能力 |
|------|------|
| **手动 IP 添加** | 推荐入口，输入 IP + 协议即可接入 |
| Shelly | Gen1 `/relay/0` + Gen2 RPC |
| Tasmota | `/cm?cmnd=Power` / Dimmer |
| ESPHome | `/switch/...` `/light/...` REST |
| Yeelight | LAN TCP `55443` |
| 通用 HTTP | `/on` `/off` 等约定路径 |
| Home Assistant | 同步实体并下发（覆盖米家/涂鸦/Matter 等） |

## 使用步骤

1. 手机与电器同一 Wi-Fi  
2. 打开智家 → **添加** → **手动添加**  
3. 填 IP、选协议（Tasmota/Shelly/Yeelight…）→ 探测并添加  
4. 回首页拨动开关，应看到「已下发到 xxx」  
5. 若有 Home Assistant：在「我的」填地址+令牌 → 同步设备  

## 构建

```bash
export PATH="$HOME/flutter/bin:$PATH"
export ANDROID_HOME="$HOME/android-sdk"
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
cd home_hub
flutter pub get
flutter test
flutter build apk --release
```

APK：`build/app/outputs/flutter-apk/app-release.apk` → 复制到 `releases/home_hub-1.1.0.apk`
