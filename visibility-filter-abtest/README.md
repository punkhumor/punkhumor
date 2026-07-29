# 物体显隐筛选 · A/B 对比测试

轻量原型：同一张「人员地图」，对比两种显隐筛选交互，做完 3 道题后投票。投票发到你的邮箱。

参考需求：`docs/三维显隐控制.pdf`

## 两种方案

| | 方案 A | 方案 B（PDF） |
|---|---|---|
| 开关 | 有：开 = 同时满足（且），关 = 满足任一（或） | 无 |
| 层级 | 人员身份 / 部门 / 岗位 / 作业类型 | 同左 |
| 逻辑 | 全局一种关系 | 维间且、维内或；大类勾选=开启；**未绑定不受影响**；默认全选 |

## 本地预览

```bash
cd visibility-filter-abtest
python3 -m http.server 5173
# 打开 http://localhost:5173
```

## 发给别人测

把本目录部署到任意静态托管（GitHub Pages / Cloudflare Pages / Netlify），把链接发出去即可。

投票路径：

1. 测试者提交 → [FormSubmit](https://formsubmit.co) 发到 `punkhumorlyde@163.com`
2. **第一次**会收到确认邮件，点一次激活后即可自动收票
3. 你自己打开同一链接，结束后可进「本机汇总」并导出 JSON

若邮件失败，页面会尝试把投票文案复制到剪贴板。

改收件邮箱：编辑 `js/app.js` 里的 `OWNER_EMAIL`。

## 目录

```
index.html
css/styles.css
js/data.js          # 分类与人员（含未绑定样例）
js/filters.js       # A/B 筛选逻辑
js/tasks.js         # 对比任务与期望结果
js/app.js           # 流程 / 投票
docs/三维显隐控制.pdf
```

```bash
node js/filters.test.mjs   # 逻辑自检
```
