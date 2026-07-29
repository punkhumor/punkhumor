# 物体显隐筛选 · 对比测试

单个 HTML，双击或发链接即可。地图为 2D 示意（亮=显示，暗=隐藏）。

## 打开

- 文件：`打开即用-显隐筛选AB测试.html`（仓库根目录）
- 在线：https://htmlpreview.github.io/?https://raw.githubusercontent.com/punkhumor/punkhumor/cursor/visibility-filter-abtest-d882/visibility-filter-abtest/index.html

## 用法

顶部可随时切换：**方案 A / 方案 B / 并排对比 / 投票 / 汇总**（非线性）。

每次打开会随机：
1. 哪种交互被叫做「方案 A / B」
2. 默认先进入 A 还是 B

投票会记下映射关系，方便你对照真实是哪套交互。

改收件邮箱：编辑 HTML / `js/app.js` 中的 `OWNER_EMAIL`，再运行 `python3 bundle.py`。
