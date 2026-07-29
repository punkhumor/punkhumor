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
  clearAllLeaves,
} from "./filters.js";

const OWNER_EMAIL = "punkhumorlyde@163.com";
const STORAGE_KEY = "visibility-filter-abtest-votes-v5";
const LEAF_UNIVERSE = allLeafIds();

const GOALS = [
  { title: "只显示张三", tip: "地图上只剩张三亮着。" },
  { title: "所有质检员", tip: "岗位勾选「质检员」。" },
  { title: "供应商来访", tip: "外来人员 → 供应商来访。" },
  { title: "整个外来人员", tip: "全选「外来人员」分组。" },
  { title: "生产一组工程师", tip: "生产一组 + 工程师相关。" },
  { title: "任意动火相关", tip: "动火作业或其子项。" },
  { title: "身份+生产一组", tip: "人员身份全选，再加生产一组。" },
  { title: "清空全关", tip: "点「重置全关」，应无人显示。" },
];

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

function cloneEngine(src) {
  return {
    mode: src.mode,
    selected: new Set(src.selected),
    expanded: { ...src.expanded },
  };
}

function engineKeyForLabel(label) {
  return state.map[label];
}

function resetEngine(key, toEmpty = false) {
  if (key === "toggle") {
    state.toggle = initialDesignAState(CATEGORIES);
    if (toEmpty) state.toggle.selected = clearAllLeaves(CATEGORIES);
  } else {
    state.facet = initialDesignBState(CATEGORIES);
    if (toEmpty) state.facet.selected = clearAllLeaves(CATEGORIES);
  }
}

function visibleFor(label, engineOverride) {
  const key = engineKeyForLabel(label);
  const eng = engineOverride || (key === "toggle" ? state.toggle : state.facet);
  if (key === "toggle") {
    return new Set(
      filterDesignA(PEOPLE, eng.selected, eng.mode, LEAF_UNIVERSE, CATEGORIES)
    );
  }
  return new Set(
    filterDesignB(PEOPLE, eng.selected, LEAF_UNIVERSE, CATEGORIES)
  );
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

/** Switch row: looks like it drives how list checks are interpreted */
function renderModeToggle(eng, scope) {
  const filterOn = eng.mode === "filter";
  return `<div class="mode-switch-bar">
    <button type="button" class="mode-side ${!filterOn ? "active" : ""}" data-scope="${scope}" data-act="t-mode-set" data-mode="multi">多选显示</button>
    <label class="switch mode-switch" title="切换列表匹配方式">
      <input type="checkbox" data-scope="${scope}" data-act="t-mode-check" ${filterOn ? "checked" : ""} />
      <span class="switch-track"></span>
    </label>
    <button type="button" class="mode-side ${filterOn ? "active" : ""}" data-scope="${scope}" data-act="t-mode-set" data-mode="filter">匹配显示</button>
  </div>`;
}

function renderTree(eng, scope, accent) {
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
                  <div class="tree-row child lv3" data-scope="${scope}" data-act="sel-leaf" data-id="${g.id}">
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
            hasKids ? "sel-group" : "sel-leaf"
          }" data-id="${child.id}">
            ${
              hasKids
                ? `<button class="twist" type="button" aria-expanded="${midExpanded}" data-scope="${scope}" data-act="expand" data-id="${child.id}">${twistIcon()}</button>`
                : `<span></span>`
            }
            <span class="checkbox ${cClass}" data-scope="${scope}" data-act="${
              hasKids ? "sel-group" : "sel-leaf"
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
      <div class="tree-row parent" style="--cat-color:${color}" data-scope="${scope}" data-act="sel-group" data-id="${cat.id}">
        <button class="twist" type="button" aria-expanded="${catExpanded}" data-scope="${scope}" data-act="expand" data-id="${cat.id}">${twistIcon()}</button>
        <button type="button" class="checkbox ${checkClass}" data-scope="${scope}" data-act="sel-group" data-id="${cat.id}">${checkIcon(
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

function renderRoster(visible) {
  return `<div class="roster">
    <div class="roster-head">人员对照 <span>${visible.size}/${PEOPLE.length}</span></div>
    <div class="roster-list">
      ${PEOPLE.map((p) => {
        const on = visible.has(p.id);
        const color = colorForPerson(p);
        const attrs =
          p.attrs.length === 0
            ? "未绑定"
            : p.attrs.map(labelForAttr).join(" · ");
        return `<div class="roster-row ${on ? "on" : "off"}">
          <i style="background:${color}"></i>
          <div>
            <strong>${p.name}</strong>
            <p>${attrs}</p>
          </div>
        </div>`;
      }).join("")}
    </div>
  </div>`;
}

function renderGoalsSide() {
  return `<div class="side-goals">
    <div class="roster-head">小目标</div>
    ${GOALS.map(
      (g, i) => `<div class="side-goal"><b>${i + 1}. ${g.title}</b><span>${g.tip}</span></div>`
    ).join("")}
  </div>`;
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
  const accent = isToggle ? "a" : "b";
  const compact = !!opts.compact;

  return `<div class="workspace panel ${compact ? "compact" : ""}" data-panel="${label}">
    <aside class="sidebar">
      <div class="sidebar-head">
        <div class="design-badge ${badgeClass}">方案 ${label}</div>
        <h3>筛选面板</h3>
      </div>
      <div class="sidebar-body">
        ${isToggle ? renderModeToggle(eng, scope) : ""}
        <div class="tree">${renderTree(eng, scope, accent)}</div>
      </div>
      <div class="sidebar-foot">
        <button class="btn btn-ghost btn-sm" type="button" data-scope="${scope}" data-act="reset-on">重置全选</button>
        <button class="btn btn-ghost btn-sm" type="button" data-scope="${scope}" data-act="reset-off">重置全关</button>
      </div>
    </aside>
    <section class="scene-wrap">
      <div class="scene">
        ${renderPeople(visible)}
        <div class="scene-legend">
          <div>亮=显示 · 暗=隐藏 · ${visible.size}/${PEOPLE.length}</div>
          <div class="legend-row">${legendHtml()}</div>
        </div>
      </div>
    </section>
    ${
      compact
        ? ""
        : `<aside class="side-rail">
      ${renderGoalsSide()}
      ${renderRoster(visible)}
    </aside>`
    }
  </div>`;
}

function ensureCompareEngines() {
  if (!state.compare.A) {
    const keyA = engineKeyForLabel("A");
    state.compare.A = cloneEngine(
      keyA === "toggle" ? state.toggle : state.facet
    );
  }
  if (!state.compare.B) {
    const keyB = engineKeyForLabel("B");
    state.compare.B = cloneEngine(
      keyB === "toggle" ? state.toggle : state.facet
    );
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
      const g = child.children?.find((x) => x.id === id);
      if (g) return g;
    }
  }
  return null;
}

function handleAct(act, scope, dataset) {
  const ctx = engineByScope(scope);
  if (!ctx) return false;
  const { key, eng } = ctx;

  if (act === "expand") {
    eng.expanded[dataset.id] = !eng.expanded[dataset.id];
    return true;
  }
  if (act === "sel-group") {
    const node = findNode(dataset.id);
    if (!node) return false;
    toggleLeaves(eng.selected, leafIdsUnder(node));
    return true;
  }
  if (act === "sel-leaf") {
    const id = dataset.id;
    if (eng.selected.has(id)) eng.selected.delete(id);
    else eng.selected.add(id);
    return true;
  }
  if (act === "t-mode-set") {
    if (key !== "toggle") return false;
    eng.mode = dataset.mode === "filter" ? "filter" : "multi";
    return true;
  }
  if (act === "t-mode-check") {
    if (key !== "toggle") return false;
    eng.mode = dataset.checked ? "filter" : "multi";
    return true;
  }
  if (act === "reset-on") {
    if (ctx.compare) {
      const next =
        key === "toggle"
          ? initialDesignAState(CATEGORIES)
          : initialDesignBState(CATEGORIES);
      next.mode = eng.mode;
      state.compare[ctx.label] = next;
    } else {
      const mode = eng.mode;
      resetEngine(key, false);
      if (key === "toggle") state.toggle.mode = mode;
    }
    return true;
  }
  if (act === "reset-off") {
    if (ctx.compare) {
      eng.selected = clearAllLeaves(CATEGORIES);
    } else {
      const mode = eng.mode;
      resetEngine(key, true);
      if (key === "toggle") state.toggle.mode = mode;
    }
    return true;
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
  const goals = GOALS.map(
    (g, i) => `<div class="goal-card">
      <div class="goal-idx">${i + 1}</div>
      <div>
        <strong>${g.title}</strong>
        <p>${g.tip}</p>
      </div>
    </div>`
  ).join("");

  return `<section class="panel panel-pad intro-fit">
    <div class="hero-copy">
      <h2>显隐筛选交互对比</h2>
      <p class="lead">
        用左侧勾选控制地图人员显隐。两套方案名称已随机对应，试用后到「投票」选一个即可。
      </p>
    </div>
    <div class="goal-list goal-grid">${goals}</div>
    <div class="tag-row">
      <span class="tag">默认全选</span>
      <span class="tag">可随时跳转</span>
      <span class="tag">每次随机先后</span>
    </div>
  </section>`;
}

function renderVote() {
  return `<section class="panel panel-pad vote-simple">
    <h2 class="section-title">投给谁？</h2>
    <p class="lead">选一个更顺手的方案。</p>
    <form class="vote-form" id="vote-form">
      <div class="choice-group vote-big">
        <label class="choice vote-choice">
          <input type="radio" name="prefer" value="A" required />
          <span>方案 A</span>
        </label>
        <label class="choice vote-choice">
          <input type="radio" name="prefer" value="B" />
          <span>方案 B</span>
        </label>
      </div>
      <div class="btn-row" style="margin-top:18px">
        <button class="btn btn-primary" type="submit">提交</button>
      </div>
    </form>
  </section>`;
}

function renderResults() {
  const votes = getVotes();
  const preferA = votes.filter((v) => v.prefer === "A").length;
  const preferB = votes.filter((v) => v.prefer === "B").length;
  const list = votes.length
    ? votes
        .slice()
        .reverse()
        .map(
          (v) => `<div class="result-card">
          <div><strong>投给方案 ${v.prefer}</strong> · ${new Date(
            v.at
          ).toLocaleString()}</div>
        </div>`
        )
        .join("")
    : `<p class="lead">还没有本机投票。</p>`;

  return `<section class="panel panel-pad">
    <h2 class="section-title">本机汇总</h2>
    <div class="compare-grid">
      <div class="compare-card"><h3>方案 A</h3><p><strong>${preferA}</strong> 票</p></div>
      <div class="compare-card"><h3>方案 B</h3><p><strong>${preferB}</strong> 票</p></div>
    </div>
    <div class="results-list" style="margin-top:16px">${list}</div>
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
      ${renderPanel("A", { scope: "cmp-A", engine: state.compare.A, compact: true })}
      ${renderPanel("B", { scope: "cmp-B", engine: state.compare.B, compact: true })}
    </div>`;
  } else if (state.view === "vote") main.innerHTML = renderVote();
  else if (state.view === "results") main.innerHTML = renderResults();
}

async function submitVote(form) {
  const fd = new FormData(form);
  const prefer = fd.get("prefer");
  if (!prefer) return;
  const vote = {
    prefer,
    map: state.map,
    first: session.first,
    at: Date.now(),
  };
  addVote(vote);

  const text = `【显隐筛选投票】投给方案 ${vote.prefer}
映射: A=${vote.map.A}, B=${vote.map.B}
时间: ${new Date(vote.at).toLocaleString()}`;

  let emailed = false;
  if (location.protocol !== "file:") {
    try {
      const res = await fetch(`https://formsubmit.co/ajax/${OWNER_EMAIL}`, {
        method: "POST",
        headers: { "Content-Type": "application/json", Accept: "application/json" },
        body: JSON.stringify({
          prefer: vote.prefer,
          map: JSON.stringify(vote.map),
          first: vote.first,
          at: new Date(vote.at).toISOString(),
          _subject: `[显隐筛选] 投给方案${vote.prefer}`,
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
      `[显隐筛选] 投给方案${vote.prefer}`
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
    if (act === "nav" || act === "t-mode-check") return;
    const scope = el.dataset.scope;
    if (!scope) return;
    if (handleAct(act, scope, el.dataset)) {
      e.preventDefault();
      paint();
    }
  });

  root.addEventListener("change", (e) => {
    const el = e.target.closest("[data-act='t-mode-check']");
    if (!el) return;
    handleAct("t-mode-check", el.dataset.scope, {
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
