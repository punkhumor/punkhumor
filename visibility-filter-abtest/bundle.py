#!/usr/bin/env python3
"""Bundle modular sources into a single double-clickable HTML."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parent

def demodule(src: str) -> str:
    src = re.sub(r"^import\s+.*?from\s+['\"].*?['\"];\s*\n?", "", src, flags=re.M | re.S)
    return src.replace("export const ", "const ").replace("export function ", "function ")

css = (ROOT / "css/styles.css").read_text()
js = "\n\n".join(
    demodule((ROOT / p).read_text())
    for p in ("js/data.js", "js/filters.js", "js/tasks.js", "js/app.js")
)

body = """
    <div class="app-shell">
      <header class="topbar">
        <div>
          <p class="brand">显隐筛选 <span>A/B 测试</span></p>
        </div>
        <div class="topbar-meta">
          单个网页 · 双击即可打开<br />
          也可直接把链接/文件发给同事
        </div>
      </header>
      <nav class="steps" id="steps" aria-label="进度"></nav>
      <section class="panel panel-pad" id="view-intro">
        <div class="hero-copy">
          <h2>帮我选一种更顺手的筛选方式</h2>
          <p class="lead">
            2D 地图上有一批人员，每人可带「人员身份 / 部门 / 岗位 / 作业类型」属性。
            用左侧勾选控制谁显示、谁隐藏。约 3–5 分钟，最后投一票。
          </p>
        </div>
        <div class="compare-grid">
          <div class="compare-card">
            <h3 style="color: var(--design-a)">方案 A · 带开关</h3>
            <p>顶部开关：开启 = 同时满足（且）；关闭 = 命中任一就显示（或）。</p>
          </div>
          <div class="compare-card">
            <h3 style="color: var(--design-b)">方案 B · 无开关（PDF）</h3>
            <p>大类勾选 = 开启该维；类内为或，维间为且。未绑定该维不受影响。</p>
          </div>
        </div>
        <div class="tag-row">
          <span class="tag">打开即用</span>
          <span class="tag">2D 示意地图</span>
          <span class="tag">3 道对照题</span>
          <span class="tag">投票回传</span>
        </div>
        <div class="btn-row">
          <button class="btn btn-primary" type="button" id="btn-start">开始任务测试</button>
          <button class="btn btn-ghost" type="button" id="btn-skip-explore">跳过任务，直接自由对比</button>
        </div>
      </section>
      <section id="view-task" class="hidden"><div id="workspace-mount"></div></section>
      <section id="view-explore" class="hidden"><div id="explore-mount"></div></section>
      <section class="panel panel-pad hidden" id="view-vote">
        <h2 class="section-title">投一票</h2>
        <p class="lead">在线打开会发到设计者邮箱；本地文件打开会复制内容并调起邮件。</p>
        <form class="vote-form" id="vote-form">
          <div class="field">
            <label>你更想在正式产品里用哪一种？ *</label>
            <div class="choice-group">
              <label class="choice"><input type="radio" name="prefer" value="A" required /><span><strong>方案 A</strong> — 全局且/或开关</span></label>
              <label class="choice"><input type="radio" name="prefer" value="B" /><span><strong>方案 B</strong> — 分维度开启</span></label>
              <label class="choice"><input type="radio" name="prefer" value="unsure" /><span>不好说 / 都要改</span></label>
            </div>
          </div>
          <div class="field">
            <label>哪种逻辑更好理解？ *</label>
            <div class="choice-group">
              <label class="choice"><input type="radio" name="clearer" value="A" required /><span>方案 A 更清晰</span></label>
              <label class="choice"><input type="radio" name="clearer" value="B" /><span>方案 B 更清晰</span></label>
            </div>
          </div>
          <div class="field"><label for="name">你怎么称呼（可选）</label><input id="name" name="name" maxlength="40" /></div>
          <div class="field"><label for="note">一句话理由（可选）</label><textarea id="note" name="note" rows="3" maxlength="500"></textarea></div>
          <div class="btn-row"><button class="btn btn-primary" type="submit">提交投票</button></div>
        </form>
      </section>
      <section class="panel panel-pad hidden" id="view-done">
        <h2 class="section-title">谢谢参与</h2>
        <p class="lead">投票已记录。</p>
        <div class="btn-row">
          <button class="btn btn-secondary" type="button" id="btn-restart">再测一轮</button>
          <button class="btn btn-ghost" type="button" id="btn-owner-results">我是设计者 · 查看本机汇总</button>
        </div>
      </section>
      <section class="panel panel-pad hidden" id="view-results">
        <h2 class="section-title">本机投票汇总</h2>
        <div id="results-summary"></div>
        <div class="results-list" id="results-list"></div>
        <div class="btn-row" style="margin-top:20px">
          <button class="btn btn-secondary" type="button" id="btn-export-votes">导出 JSON</button>
          <button class="btn btn-ghost" type="button" id="btn-clear-votes">清除本机记录</button>
          <button class="btn btn-ghost" type="button" id="btn-back-done">返回</button>
        </div>
      </section>
    </div>
    <div class="toast" id="toast" role="status"></div>
"""

out = f"""<!doctype html>
<html lang=\"zh-CN\">
<head>
<meta charset=\"utf-8\" />
<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />
<title>物体显隐筛选 · 方案对比测试</title>
<style>
{css}
</style>
</head>
<body>
{body}
<script>
{js}
</script>
</body>
</html>
"""

for path in (
    ROOT / "index.html",
    ROOT / "打开即用-显隐筛选AB测试.html",
    ROOT.parent / "打开即用-显隐筛选AB测试.html",
):
    path.write_text(out)
    print("wrote", path)
