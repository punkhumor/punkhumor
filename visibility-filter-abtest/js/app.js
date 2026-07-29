import {
  CATEGORIES,
  PEOPLE,
  CATEGORY_COLORS,
  labelForAttr,
  colorForPerson,
  allLeafIds,
  leafIdsUnder,
} from "./data.js";
import {
  filterDesignA,
  filterDesignB,
  initialDesignAState,
  initialDesignBState,
  nodeCheckState,
  parentCheckStateB,
} from "./filters.js";

const OWNER_EMAIL = "punkhumorlyde@163.com";
const STORAGE_KEY = "visibility-filter-abtest-votes-v3";
const LEAF_UNIVERSE = allLeafIds();

function freshSession() {
  const flip = Math.random() < 0.5;
  return {
    map: flip
      ? { A: "toggle", B: "facet" }
      : { A: "facet", B: "toggle" },
    first: Math.random() < 0.5 ? "A" : "B",
  };
}

const session = freshSession();

const state = {
  view: "intro",
  map: session.map,
  toggle: initialDesignAState(CATEGORIES),
  facet: initialDesignBState(CATEGORIES),
  compare: { A: null, B: null },
};

function cloneToggle(src) {
  return {
    mode: src.mode,
    selected: new Set(src.selected),
    expanded: { ...src.expanded },
  };
}

function cloneFacet(src) {
  const out = {
    _midExpanded: { ...(src._midExpanded || {}) },
  };
  for (const [id, s] of Object.entries(src)) {
    if (id === "_midExpanded") continue;
    out[id] = {
      enabled: s.enabled,
      selected: new Set(s.selected),
      expanded: s.expanded,
    };
  }
  return out;
}

function engineKeyForLabel(label) {
  return state.map[label];
}

function resetEngine(key) {
  if (key === "toggle") state.toggle = initialDesignAState(CATEGORIES);
  else state.facet = initialDesignBState(CATEGORIES);
}

function visibleFor(label, engineOverride) {
  const key = engineKeyForLabel(label);
  const eng = engineOverride || (key === "toggle" ? state.toggle : state.facet);
  if (key === "toggle") {
    return new Set(
      filterDesignA(PEOPLE, eng.selected, eng.mode, LEAF_UNIVERSE)
    );
  }
  return new Set(filterDesignB(PEOPLE, eng));
}

function showToast(message) {
  const toast = document.getElementById("toast");
  toast.textContent = message;
  toast.classList.add("show");
  clearTimeout(showToast._t);
  showToast._t = setTimeout(() => toast.classList.remove("show"), 2400);
}

function checkIcon(partial = false) {
  if (partial) {
    return `<svg viewBox="0 0 12 12" fill="none" aria-hidden="true"><path d="M2.5 6h7" stroke="#06241f" stroke-width="2" stroke-linecap="round"/></svg>`;
  }
  return `<svg viewBox="0 0 12 12" fill="none" aria-hidden="true"><path d="M2.2 6.2l2.5 2.5 5-5.2" stroke="#06241f" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>`;
}

function twistIcon() {
  return `<svg viewBox="0 0 12 12" fill="none" aria-hidden="true"><path d="M4 2.5L8 6 4 9.5" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/></svg>`;
}

function setLeaves(selected, leafIds, on) {
  for (const id of leafIds) {
    if (on) selected.add(id);
    else selected.delete(id);
  }
}

function toggleLeaves(selected, leafIds) {
  const allOn = leafIds.every((id) => selected.has(id));
  setLeaves(selected, leafIds, !allOn);
}

function renderModeToggle(eng, scope) {
  const filterOn = eng.mode === "filter";
  return `<div class="mode-inline">
    <span class="mode-opt ${!filterOn ? "on" : ""}">多选显示</span>
    <label class="switch compact">
      <input type="checkbox" data-scope="${scope}" data-act="t-mode" ${
        filterOn ? "checked" : ""
      } />
      <span class="switch-track"></span>
    </label>
    <span class="mode-opt ${filterOn ? "on" : ""}">筛选显示</span>
  </div>`;
}

function renderTreeToggle(eng, scope) {
  const accent = "a";
  return CATEGORIES.map((cat) => {
    const catExpanded = !!eng.expanded[cat.id];
    const pState = nodeCheckState(cat, eng.selected);
    const checkClass =
      pState === "all" ? `on ${accent}` : pState === "partial" ? `partial ${accent}` : "";
    const color = CATEGORY_COLORS[cat.id];

    const level2 = cat.children
      .map((child) => {
        const hasKids = !!child.children?.length;
        const midExpanded = !!eng.expanded[child.id];
        const cState = nodeCheckState(child, eng.selected);
        const cClass =
          cState === "all"
            ? `on ${accent}`
            : cState === "partial"
              ? `partial ${accent}`
              : "";

        const level3 = hasKids
          ? child.children
              .map((g) => {
                const on = eng.selected.has(g.id);
                return `<div class="tree-node">
                  <div class="tree-row child lv3" data-scope="${scope}" data-act="t-leaf" data-id="${g.id}">
                    <span></span>
                    <span class="checkbox ${on ? `on ${accent}` : ""}">${checkIcon()}</span>
                    <span class="tree-label">${g.label}</span>
                  </div>
                </div>`;
              })
              .join("")
          : "";

        return `<div class="tree-node">
          <div class="tree-row child lv2" data-scope="${scope}" data-act="${
            hasKids ? "t-mid" : "t-leaf"
          }" data-id="${child.id}">
            ${
              hasKids
                ? `<button class="twist" type="button" aria-expanded="${midExpanded}" data-scope="${scope}" data-act="t-expand" data-id="${child.id}">${twistIcon()}</button>`
                : `<span></span>`
            }
            <span class="checkbox ${cClass}" data-scope="${scope}" data-act="${
              hasKids ? "t-mid" : "t-leaf"
            }" data-id="${child.id}">${checkIcon(cState === "partial")}</span>
            <span class="tree-label">${child.label}</span>
          </div>
          ${
            hasKids
              ? `<div class="tree-children ${midExpanded ? "" : "hidden"}">${level3}</div>`
              : ""
          }
        </div>`;
      })
      .join("");

    return `<div class="tree-node">
      <div class="tree-row parent" style="--cat-color:${color}">
        <button class="twist" type="button" aria-expanded="${catExpanded}" data-scope="${scope}" data-act="t-expand" data-id="${cat.id}">${twistIcon()}</button>
        <button type="button" class="checkbox ${checkClass}" data-scope="${scope}" data-act="t-parent" data-id="${cat.id}">${checkIcon(
          pState === "partial"
        )}</button>
        <span class="tree-label"><span class="cat-dot" style="background:${color}"></span>${cat.label}</span>
      </div>
      <div class="tree-children ${catExpanded ? "" : "hidden"}">${level2}</div>
    </div>`;
  }).join("");
}

function renderTreeFacet(eng, scope) {
  const accent = "b";
  return CATEGORIES.map((cat) => {
    const catState = eng[cat.id];
    const catExpanded = !!catState.expanded;
    const pState = parentCheckStateB(cat, catState);
    const enabled = catState.enabled;
    const parentClass =
      pState === "off"
        ? ""
        : pState === "all"
          ? `on ${accent}`
          : pState === "partial"
            ? `partial ${accent}`
            : `on ${accent}`;
    const color = CATEGORY_COLORS[cat.id];

    const level2 = cat.children
      .map((child) => {
        const hasKids = !!child.children?.length;
        const midExpanded = !!eng._midExpanded?.[child.id];
        const cState = nodeCheckState(child, catState.selected);
        const cClass =
          cState === "all"
            ? `on ${accent}`
            : cState === "partial"
              ? `partial ${accent}`
              : "";

        const level3 = hasKids
          ? child.children
              .map((g) => {
                const on = catState.selected.has(g.id);
                return `<div class="tree-node">
                  <div class="tree-row child lv3" data-scope="${scope}" data-act="f-leaf" data-cat="${cat.id}" data-id="${g.id}">
                    <span></span>
                    <span class="checkbox ${on ? `on ${accent}` : ""}">${checkIcon()}</span>
                    <span class="tree-label" style="${enabled ? "" : "opacity:.5"}">${g.label}</span>
                  </div>
                </div>`;
              })
              .join("")
          : "";

        return `<div class="tree-node">
          <div class="tree-row child lv2" data-scope="${scope}" data-act="${
            hasKids ? "f-mid" : "f-leaf"
          }" data-cat="${cat.id}" data-id="${child.id}">
            ${
              hasKids
                ? `<button class="twist" type="button" aria-expanded="${midExpanded}" data-scope="${scope}" data-act="f-mid-expand" data-id="${child.id}">${twistIcon()}</button>`
                : `<span></span>`
            }
            <span class="checkbox ${cClass}" data-scope="${scope}" data-act="${
              hasKids ? "f-mid" : "f-leaf"
            }" data-cat="${cat.id}" data-id="${child.id}">${checkIcon(
              cState === "partial"
            )}</span>
            <span class="tree-label" style="${enabled ? "" : "opacity:.5"}">${child.label}</span>
          </div>
          ${
            hasKids
              ? `<div class="tree-children ${midExpanded ? "" : "hidden"}">${level3}</div>`
              : ""
          }
        </div>`;
      })
      .join("");

    return `<div class="tree-node">
      <div class="tree-row parent ${enabled ? "b-active" : ""}" style="--cat-color:${color}">
        <button class="twist" type="button" aria-expanded="${catExpanded}" data-scope="${scope}" data-act="f-expand" data-id="${cat.id}">${twistIcon()}</button>
        <button type="button" class="checkbox ${parentClass}" data-scope="${scope}" data-act="f-parent" data-id="${cat.id}">${checkIcon(
          pState === "partial"
        )}</button>
        <span class="tree-label"><span class="cat-dot" style="background:${color}"></span>${cat.label}</span>
      </div>
      <div class="tree-children ${catExpanded ? "" : "hidden"}">${level2}</div>
    </div>`;
  }).join("");
}

function renderPeople(visible) {
  return PEOPLE.map((person) => {
    const isVisible = visible.has(person.id);
    const color = colorForPerson(person);
    const attrs =
      person.attrs.length === 0
        ? "未绑定分类"
        : person.attrs.map(labelForAttr).join(" · ");
    return `<div class="person ${isVisible ? "visible-person" : "hidden-person"}" style="left:${person.x}%;top:${person.y}%">
      <div class="dot" style="background:linear-gradient(160deg, color-mix(in srgb, ${color} 80%, white), ${color})">${person.name.slice(0, 1)}</div>
      <div class="person-tip"><strong>${person.name}</strong><br>${attrs}</div>
    </div>`;
  }).join("");
}

function legendHtml() {
  return Object.entries(CATEGORY_COLORS)
    .map(([id, color]) => {
      const label = CATEGORIES.find((c) => c.id === id)?.label || id;
      return `<span class="legend-item"><i style="background:${color}"></i>${label}</span>`;
    })
    .join("");
}

function renderPanel(label, opts = {}) {
  const key = engineKeyForLabel(label);
  const eng =
    opts.engine || (key === "toggle" ? state.toggle : state.facet);
  const scope = opts.scope || `solo-${label}`;
  const visible = visibleFor(label, eng);
  const isToggle = key === "toggle";
  const badgeClass = label === "A" ? "a" : "b";

  return `<div class="workspace panel" data-panel="${label}">
    <aside class="sidebar">
      <div class="sidebar-head">
        <div class="design-badge ${badgeClass}">方案 ${label}</div>
        <h3>筛选面板</h3>
      </div>
      <div class="sidebar-body">
        ${isToggle ? renderModeToggle(eng, scope) : ""}
        <div class="tree">
          ${isToggle ? renderTreeToggle(eng, scope) : renderTreeFacet(eng, scope)}
        </div>
      </div>
    </aside>
    <section class="scene-wrap">
      <div class="task-bar">
        <div>
          <h4>方案 ${label}</h4>
          <p>勾选标签控制显隐。圆点颜色对应人员所属大类。</p>
        </div>
      </div>
      <div class="scene">
        ${renderPeople(visible)}
        <div class="scene-legend">
          <div>亮=显示 · 暗=隐藏 · ${visible.size}/${PEOPLE.length}</div>
          <div class="legend-row">${legendHtml()}</div>
        </div>
      </div>
      <div class="footer-actions">
        <div class="btn-row">
          <button class="btn btn-ghost" type="button" data-scope="${scope}" data-act="reset">重置为全选</button>
        </div>
      </div>
    </section>
  </div>`;
}

function ensureCompareEngines() {
  if (!state.compare.A) {
    const keyA = engineKeyForLabel("A");
    state.compare.A =
      keyA === "toggle" ? cloneToggle(state.toggle) : cloneFacet(state.facet);
  }
  if (!state.compare.B) {
    const keyB = engineKeyForLabel("B");
    state.compare.B =
      keyB === "toggle" ? cloneToggle(state.toggle) : cloneFacet(state.facet);
  }
}

function engineByScope(scope) {
  if (scope === "solo-A" || scope === "solo-B") {
    const label = scope.slice(-1);
    const key = engineKeyForLabel(label);
    return {
      key,
      eng: key === "toggle" ? state.toggle : state.facet,
      label,
      compare: false,
    };
  }
  if (scope === "cmp-A" || scope === "cmp-B") {
    ensureCompareEngines();
    const label = scope.slice(-1);
    const key = engineKeyForLabel(label);
    return { key, eng: state.compare[label], label, compare: true };
  }
  return null;
}

function findNode(id) {
  for (const cat of CATEGORIES) {
    if (cat.id === id) return cat;
    for (const child of cat.children) {
      if (child.id === id) return child;
      if (child.children?.some((g) => g.id === id)) {
        return child.children.find((g) => g.id === id);
      }
    }
  }
  return null;
}

function handleAct(act, scope, dataset, extra = {}) {
  const ctx = engineByScope(scope);
  if (!ctx) return false;
  const { key, eng } = ctx;

  if (key === "toggle") {
    if (act === "t-expand") {
      eng.expanded[dataset.id] = !eng.expanded[dataset.id];
      return true;
    }
    if (act === "t-parent" || act === "t-mid") {
      const node = findNode(dataset.id);
      if (!node) return false;
      toggleLeaves(eng.selected, leafIdsUnder(node));
      return true;
    }
    if (act === "t-leaf") {
      const id = dataset.id;
      if (eng.selected.has(id)) eng.selected.delete(id);
      else eng.selected.add(id);
      return true;
    }
    if (act === "t-mode") {
      eng.mode = extra.checked ? "filter" : "multi";
      return true;
    }
    if (act === "reset") {
      if (ctx.compare) {
        state.compare[ctx.label] = initialDesignAState(CATEGORIES);
      } else resetEngine("toggle");
      return true;
    }
  }

  if (key === "facet") {
    if (act === "f-expand") {
      eng[dataset.id].expanded = !eng[dataset.id].expanded;
      return true;
    }
    if (act === "f-mid-expand") {
      eng._midExpanded[dataset.id] = !eng._midExpanded[dataset.id];
      return true;
    }
    if (act === "f-parent") {
      const id = dataset.id;
      const catState = eng[id];
      const cat = CATEGORIES.find((c) => c.id === id);
      const leaves = leafIdsUnder(cat);
      if (!catState.enabled) {
        catState.enabled = true;
        catState.expanded = true;
        catState.selected = new Set(leaves);
      } else {
        const allOn = leaves.every((x) => catState.selected.has(x));
        if (allOn || catState.selected.size === 0) {
          catState.enabled = false;
          catState.selected.clear();
        } else {
          leaves.forEach((x) => catState.selected.add(x));
        }
      }
      return true;
    }
    if (act === "f-mid" || act === "f-leaf") {
      const catId = dataset.cat;
      const catState = eng[catId];
      if (!catState.enabled) {
        catState.enabled = true;
        catState.expanded = true;
      }
      const node = findNode(dataset.id);
      const leaves = leafIdsUnder(node);
      if (act === "f-leaf" && leaves.length === 1 && leaves[0] === dataset.id) {
        if (catState.selected.has(dataset.id)) catState.selected.delete(dataset.id);
        else catState.selected.add(dataset.id);
      } else {
        toggleLeaves(catState.selected, leaves);
      }
      if (catState.selected.size === 0) catState.enabled = false;
      return true;
    }
    if (act === "reset") {
      if (ctx.compare) state.compare[ctx.label] = initialDesignBState(CATEGORIES);
      else resetEngine("facet");
      return true;
    }
  }
  return false;
}

function getVotes() {
  try {
    return JSON.parse(localStorage.getItem(STORAGE_KEY) || "[]");
  } catch {
    return [];
  }
}

function addVote(vote) {
  const votes = getVotes();
  votes.push(vote);
  localStorage.setItem(STORAGE_KEY, JSON.stringify(votes));
}

function escapeHtml(str) {
  return String(str)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

function renderNav() {
  const ab =
    session.first === "A"
      ? [
          { id: "A", label: "方案 A" },
          { id: "B", label: "方案 B" },
        ]
      : [
          { id: "B", label: "方案 B" },
          { id: "A", label: "方案 A" },
        ];
  const items = [
    { id: "intro", label: "说明" },
    ...ab,
    { id: "compare", label: "并排对比" },
    { id: "vote", label: "投票" },
    { id: "results", label: "汇总" },
  ];
  document.getElementById("nav").innerHTML = items
    .map(
      (it) =>
        `<button type="button" class="nav-pill ${
          state.view === it.id ? "active" : ""
        }" data-act="nav" data-view="${it.id}">${it.label}</button>`
    )
    .join("");
}

function renderIntro() {
  return `<section class="panel panel-pad">
    <div class="hero-copy">
      <h2>显隐筛选交互对比</h2>
      <p class="lead">
        场景：一张 2D 示意地图上有若干人员。每人可带有「人员身份 / 部门 / 岗位 / 作业类型」等标签
        （同一人可属于多个大类；部分标签下还有更细的三级项）。你的操作目标是：按条件控制谁显示、谁隐藏。
      </p>
      <p class="lead">
        这里有两套交互方案（名称已随机对应）。请分别试用，也可并排对比，最后投一票。
        没有标准答案，按真实使用感受选择即可。约需几分钟。
      </p>
    </div>
    <div class="tag-row">
      <span class="tag">默认全选 · 全员显示</span>
      <span class="tag">大类颜色区分</span>
      <span class="tag">含三级标签</span>
      <span class="tag">每次打开随机先后</span>
    </div>
    <div class="btn-row">
      <button class="btn btn-primary" type="button" data-act="nav" data-view="${session.first}">先试方案 ${session.first}</button>
      <button class="btn btn-secondary" type="button" data-act="nav" data-view="compare">并排对比</button>
      <button class="btn btn-ghost" type="button" data-act="nav" data-view="vote">直接投票</button>
    </div>
  </section>`;
}

function renderVote() {
  return `<section class="panel panel-pad">
    <h2 class="section-title">投票</h2>
    <p class="lead">两种都试用后再选也可；可随时回到方案页继续体验。</p>
    <form class="vote-form" id="vote-form">
      <div class="field">
        <label>更想在产品里用哪一种？ *</label>
        <div class="choice-group">
          <label class="choice"><input type="radio" name="prefer" value="A" required /><span>方案 A</span></label>
          <label class="choice"><input type="radio" name="prefer" value="B" /><span>方案 B</span></label>
          <label class="choice"><input type="radio" name="prefer" value="unsure" /><span>不好说</span></label>
        </div>
      </div>
      <div class="field">
        <label>哪种更好理解？ *</label>
        <div class="choice-group">
          <label class="choice"><input type="radio" name="clearer" value="A" required /><span>方案 A</span></label>
          <label class="choice"><input type="radio" name="clearer" value="B" /><span>方案 B</span></label>
        </div>
      </div>
      <div class="field"><label for="name">称呼（可选）</label><input id="name" name="name" maxlength="40" /></div>
      <div class="field"><label for="note">理由（可选）</label><textarea id="note" name="note" rows="3" maxlength="500"></textarea></div>
      <div class="btn-row"><button class="btn btn-primary" type="submit">提交投票</button></div>
    </form>
  </section>`;
}

function renderResults() {
  const votes = getVotes();
  const preferA = votes.filter((v) => v.prefer === "A").length;
  const preferB = votes.filter((v) => v.prefer === "B").length;
  const preferUnsure = votes.filter((v) => v.prefer === "unsure").length;
  const clearA = votes.filter((v) => v.clearer === "A").length;
  const clearB = votes.filter((v) => v.clearer === "B").length;
  const list = votes.length
    ? votes
        .slice()
        .reverse()
        .map(
          (v) => `<div class="result-card">
          <div><strong>${
            v.prefer === "A" ? "倾向 A" : v.prefer === "B" ? "倾向 B" : "不确定"
          }</strong>
          · 更清晰：${v.clearer} · ${new Date(v.at).toLocaleString()}</div>
          <div style="color:var(--text-muted);margin-top:4px">${escapeHtml(
            v.name || "匿名"
          )}${v.note ? " · " + escapeHtml(v.note) : ""}</div>
        </div>`
        )
        .join("")
    : `<p class="lead">还没有本机投票。</p>`;

  return `<section class="panel panel-pad">
    <h2 class="section-title">本机汇总</h2>
    <div class="compare-grid">
      <div class="compare-card"><h3>更想用</h3><p>A <strong>${preferA}</strong>　B <strong>${preferB}</strong>　不确定 <strong>${preferUnsure}</strong></p></div>
      <div class="compare-card"><h3>更好理解</h3><p>A <strong>${clearA}</strong>　B <strong>${clearB}</strong></p></div>
    </div>
    <p class="lead" style="margin-top:16px">共 ${votes.length} 条（本浏览器）。在线投票会发到邮箱，并含 A/B 随机映射。</p>
    <div class="results-list">${list}</div>
    <div class="btn-row" style="margin-top:20px">
      <button class="btn btn-secondary" type="button" data-act="export">导出 JSON</button>
      <button class="btn btn-ghost" type="button" data-act="clear-votes">清除本机记录</button>
    </div>
  </section>`;
}

function paint() {
  renderNav();
  const main = document.getElementById("main");
  if (state.view === "intro") main.innerHTML = renderIntro();
  else if (state.view === "A") main.innerHTML = renderPanel("A", { scope: "solo-A" });
  else if (state.view === "B") main.innerHTML = renderPanel("B", { scope: "solo-B" });
  else if (state.view === "compare") {
    ensureCompareEngines();
    main.innerHTML = `<div class="compare-workspaces">
      ${renderPanel("A", { scope: "cmp-A", engine: state.compare.A })}
      ${renderPanel("B", { scope: "cmp-B", engine: state.compare.B })}
    </div>`;
  } else if (state.view === "vote") main.innerHTML = renderVote();
  else if (state.view === "results") main.innerHTML = renderResults();
}

async function submitVote(form) {
  const fd = new FormData(form);
  const vote = {
    prefer: fd.get("prefer"),
    clearer: fd.get("clearer"),
    name: (fd.get("name") || "").trim(),
    note: (fd.get("note") || "").trim(),
    map: state.map,
    first: session.first,
    at: Date.now(),
  };
  addVote(vote);

  const text = `【显隐筛选投票】
倾向: ${vote.prefer}
更清晰: ${vote.clearer}
称呼: ${vote.name || "匿名"}
备注: ${vote.note || "(无)"}
映射: A=${vote.map.A}, B=${vote.map.B}, 先见=${vote.first}
时间: ${new Date(vote.at).toLocaleString()}`;

  let emailed = false;
  if (location.protocol !== "file:") {
    try {
      const res = await fetch(`https://formsubmit.co/ajax/${OWNER_EMAIL}`, {
        method: "POST",
        headers: { "Content-Type": "application/json", Accept: "application/json" },
        body: JSON.stringify({
          ...vote,
          map: JSON.stringify(vote.map),
          _subject: `[显隐筛选] 倾向方案${vote.prefer}`,
          _template: "table",
        }),
      });
      if (!res.ok) throw new Error("fail");
      emailed = true;
      showToast("已提交");
    } catch {
      emailed = false;
    }
  }
  if (!emailed) {
    try {
      await navigator.clipboard.writeText(text);
    } catch {
      /* ignore */
    }
    const a = document.createElement("a");
    a.href = `mailto:${OWNER_EMAIL}?subject=${encodeURIComponent(
      `[显隐筛选] 倾向方案${vote.prefer}`
    )}&body=${encodeURIComponent(text)}`;
    a.click();
    showToast("已复制并打开邮件");
  }
  state.view = "results";
  paint();
}

function wire() {
  const root = document.getElementById("app");

  root.addEventListener("click", (e) => {
    const nav = e.target.closest("[data-act='nav']");
    if (nav) {
      state.view = nav.dataset.view;
      paint();
      return;
    }

    if (e.target.closest("[data-act='export']")) {
      const blob = new Blob([JSON.stringify(getVotes(), null, 2)], {
        type: "application/json",
      });
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = `filter-votes-${Date.now()}.json`;
      a.click();
      URL.revokeObjectURL(url);
      return;
    }

    if (e.target.closest("[data-act='clear-votes']")) {
      if (confirm("清除本机投票？")) {
        localStorage.removeItem(STORAGE_KEY);
        paint();
      }
      return;
    }

    const el = e.target.closest("[data-act]");
    if (!el) return;
    const act = el.dataset.act;
    if (act === "nav" || act === "t-mode") return;
    const scope = el.dataset.scope;
    if (!scope) return;
    // Prefer act/id from the element that owns the action (avoid twist stealing parent row)
    if (handleAct(act, scope, el.dataset)) {
      e.preventDefault();
      paint();
    }
  });

  root.addEventListener("change", (e) => {
    const el = e.target.closest("[data-act='t-mode']");
    if (!el) return;
    handleAct("t-mode", el.dataset.scope, el.dataset, {
      checked: e.target.checked,
    });
    paint();
  });

  root.addEventListener("submit", (e) => {
    if (e.target.id !== "vote-form") return;
    e.preventDefault();
    submitVote(e.target);
  });
}

wire();
paint();
