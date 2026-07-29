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
    for p in ("js/data.js", "js/filters.js", "js/app.js")
)

body = """
<div id="app" class="app-shell">
  <header class="topbar">
    <div>
      <p class="brand">显隐筛选 <span>对比测试</span></p>
    </div>
    <div class="topbar-meta">
      说明 → 试用 → 投票，可随时跳转<br />
      每次打开随机方案先后
    </div>
  </header>

  <nav class="steps" id="nav" aria-label="导航"></nav>
  <div id="main"></div>
</div>
<div class="toast" id="toast" role="status"></div>
"""

out = f"""<!doctype html>
<html lang=\"zh-CN\">
<head>
<meta charset=\"utf-8\" />
<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />
<title>物体显隐筛选 · 对比测试</title>
<meta name=\"description\" content=\"对比两种显隐筛选交互并投票。打开即用。\" />
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
