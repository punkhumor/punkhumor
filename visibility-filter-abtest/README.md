# 物体显隐筛选 · A/B 对比测试

**直接用浏览器打开就能测**——不需要安装、不需要起服务器。

## 最快用法

1. 下载仓库里的 **`打开即用-显隐筛选AB测试.html`**（根目录或本目录都有）
2. 双击用 Chrome / Edge / Safari 打开
3. 或把该文件发给同事（微信/邮件/网盘），对方同样双击即可

在线链接（推送后可用，任选其一）：

- https://raw.githack.com/punkhumor/punkhumor/cursor/visibility-filter-abtest-d882/打开即用-显隐筛选AB测试.html
- https://cdn.jsdelivr.net/gh/punkhumor/punkhumor@cursor/visibility-filter-abtest-d882/打开即用-显隐筛选AB测试.html

> 地图是 **2D 示意**：亮点=显示，变暗=隐藏，够表达筛选意思。

## 两种方案

| | 方案 A | 方案 B（PDF） |
|---|---|---|
| 开关 | 开=同时满足（且），关=满足任一（或） | 无 |
| 逻辑 | 全局一种关系 | 维间且、维内或；大类勾选=开启；未绑定不受影响 |

## 投票怎么收到

- **用在线链接打开**：投票经 FormSubmit 发到 `punkhumorlyde@163.com`（第一次要在邮箱点确认）
- **本地双击打开**：自动复制投票文案并调起邮件客户端

本机还可在结束页查看汇总 / 导出 JSON。改邮箱：编辑 HTML 里的 `OWNER_EMAIL`，或改 `js/app.js` 后重新打包。

## 开发用拆分文件（可选）

```
js/  css/          # 源码拆分，便于改逻辑
node js/filters.test.mjs
# 重新打成单文件：
python3 bundle.py   # 见下方；或看仓库脚本
```

参考需求：`docs/三维显隐控制.pdf`
