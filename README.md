# 智家 · Home Hub

米家风格智能家居控制 App（Flutter）。**v1.1.1 真控制 + 扫描过滤垃圾主机**。

- 源码：[`home_hub/`](./home_hub/)
- 真实性证明：[`home_hub/PROOF.txt`](./home_hub/PROOF.txt)
- APK：**[`releases/home_hub-1.1.1.apk`](./releases/home_hub-1.1.1.apk)**（arm64，约 20MB）

## 为什么以前扫描出几百条

旧逻辑把「端口开着的主机」都当成设备（路由器/打印机/手机网页也会进列表）。  
**1.1.1 起只收录指纹识别成功的 Shelly / Tasmota / ESPHome / Yeelight / Home Assistant。**

## 快速使用

1. 安装 APK，手机与电器同一 Wi-Fi  
2. **优先：添加 → 手动添加** → 填 IP、选协议  
3. 或扫描局域网（现在不会再刷几百条垃圾）  
4. 拨开关看到「已下发」= 真实控制成功  
5. 米家/涂鸦等：先接 Home Assistant，再在「我的」同步
