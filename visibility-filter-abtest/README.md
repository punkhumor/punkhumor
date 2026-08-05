# 物体显隐筛选 · 对比测试

单个 HTML，双击或发链接即可。地图为 2D 示意（亮=显示，暗=隐藏）。

## 打开

- 文件：`打开即用-显隐筛选AB测试.html`（仓库根目录）
- **在线（推荐）**：https://cdn.jsdelivr.net/gh/punkhumor/punkhumor@cursor/visibility-filter-abtest-d882/visibility-filter-abtest/index.html
- 备用：https://raw.githack.com/punkhumor/punkhumor/913f1ea/visibility-filter-abtest/index.html

> 请用上面的在线链接分享。临时托管（litterbox 等）会过期 404；`punkhumor.github.io` 需先在仓库开启 GitHub Pages。`file://` 本地打开无法同步全网投票。

## 用法

顶部可随时切换：**方案 A / 方案 B / 并排对比 / 投票 / 汇总**（非线性）。

每次打开会随机：
1. 哪种交互被叫做「方案 A / B」
2. 默认先进入 A 还是 B

投票会写入共享汇总（所有人打开「汇总」都能看到），并记下映射关系。汇总页可点「刷新全网」。

改收件邮箱：编辑 HTML / `js/app.js` 中的 `OWNER_EMAIL`，再运行 `python3 bundle.py`。
