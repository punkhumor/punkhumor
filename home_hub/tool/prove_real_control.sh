#!/usr/bin/env bash
# 现场证明脚本：起假 Tasmota + 假路由器，跑指纹与下发测试，写出证据文件
set -euo pipefail
export PATH="${HOME}/flutter/bin:${PATH}"
export ANDROID_HOME="${HOME}/android-sdk"
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-/opt/cursor/artifacts/proof-real-control.txt}"
mkdir -p "$(dirname "$OUT")"

{
  echo "=== 智家真实性证明 $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
  echo
  echo "1) 单元/集成测试（含：垃圾主机过滤 + Tasmota/Shelly 真实下发）"
  cd "$ROOT"
  flutter test test/proof_e2e_test.dart test/control_service_test.dart
  echo
  echo "2) 结论"
  echo "- 普通路由器 HTTP 页面：不会被识别为设备"
  echo "- Tasmota/Shelly：能指纹识别，且 Power 状态会被 HTTP 请求真实改写"
  echo "- 自动扫描若仍很多，请升级到 1.1.1（已去掉‘任意开端口即入库’）"
} | tee "$OUT"

echo "Wrote $OUT"
