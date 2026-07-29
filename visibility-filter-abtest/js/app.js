import { CATEGORIES, PEOPLE, labelForAttr } from "./data.js";
import { TASKS } from "./tasks.js";
import {
  filterDesignA,
  filterDesignB,
  initialDesignBState,
  parentCheckState,
  parentCheckStateB,
} from "./filters.js";

const OWNER_EMAIL = "punkhumorlyde@163.com";
const STORAGE_KEY = "visibility-filter-abtest-votes-v1";
const SESSION_KEY = "visibility-filter-abtest-session-v1";

const STEPS = [
  { id: "intro", label: "说明" },
  { id: "task", label: "任务测试" },
  { id: "explore", label: "自由对比" },
  { id: "vote", label: "投票" },
  { id: "done", label: "完成" },
];

const state = {
  step: "intro",
  taskIndex: 0,
  designOrder: Math.random() < 0.5 ? ["A", "B"] : ["B", "A"],
  designIndex: 0,
  activeDesign: "A",
  designA: {
    mode: "or",
    selected: new Set(),
    expanded: Object.fromEntries(CATEGORIES.map((c) => [c.id, c.id === "department"])),
  },
  designB: initialDesignBState(CATEGORIES),
  taskAttempts: {},
  voteSubmitted: false,
};

const el = {
  steps: document.getElementById("steps"),
  views: {
    intro: document.getElementById("view-intro"),
    task: document.getElementById("view-task"),
    explore: document.getElementById("view-explore"),
    vote: document.getElementById("view-vote"),
    done: document.getElementById("view-done"),
    results: document.getElementById("view-results"),
  },
  workspaceMount: document.getElementById("workspace-mount"),
  exploreMount: document.getElementById("explore-mount"),
  toast: document.getElementById("toast"),
};

function showToast(message) {
  el.toast.textContent = message;
  el.toast.classList.add("show");
  clearTimeout(showToast._t);
  showToast._t = setTimeout(() => el.toast.classList.remove("show"), 2600);
}

function saveSession() {
  localStorage.setItem(
    SESSION_KEY,
    JSON.stringify({
      step: state.step,
      taskIndex: state.taskIndex,
      designOrder: state.designOrder,
      designIndex: state.designIndex,
      taskAttempts: state.taskAttempts,
      voteSubmitted: state.voteSubmitted,
    })
  );
}

function loadSession() {
  try {
    const raw = localStorage.getItem(SESSION_KEY);
    if (!raw) return;
    const data = JSON.parse(raw);
    Object.assign(state, {
      step: data.step || "intro",
      taskIndex: data.taskIndex || 0,
      designOrder: data.designOrder || state.designOrder,
      designIndex: data.designIndex || 0,
      taskAttempts: data.taskAttempts || {},
      voteSubmitted: !!data.voteSubmitted,
    });
  } catch {
    /* ignore */
  }
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

function setsEqual(a, b) {
  if (a.size !== b.size) return false;
  for (const v of a) if (!b.has(v)) return false;
  return true;
}

function visibleIds() {
  if (state.activeDesign === "A") {
    return new Set(filterDesignA(PEOPLE, state.designA.selected, state.designA.mode));
  }
  return new Set(filterDesignB(PEOPLE, state.designB));
}

function expectedForCurrent() {
  const task = TASKS[state.taskIndex];
  const key = state.activeDesign === "A" ? "expectedA" : "expectedB";
  return new Set(task[key]);
}

function resetFiltersForDesign(design) {
  state.designA.selected = new Set();
  state.designA.mode = "or";
  state.designA.expanded = Object.fromEntries(
    CATEGORIES.map((c) => [c.id, c.id === "department"])
  );
  state.designB = initialDesignBState(CATEGORIES);
  if (design === "A" && TASKS[state.taskIndex]?.setupA?.mode) {
    state.designA.mode = TASKS[state.taskIndex].setupA.mode;
  }
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

function renderTreeA() {
  return CATEGORIES.map((cat) => {
    const expanded = !!state.designA.expanded[cat.id];
    const pState = parentCheckState(cat, state.designA.selected);
    const checkClass =
      pState === "all" ? "on a" : pState === "partial" ? "partial a" : "";
    const children = cat.children
      .map((child) => {
        const on = state.designA.selected.has(child.id);
        return `
          <div class="tree-node">
            <div class="tree-row child" data-action="toggle-a-leaf" data-id="${child.id}">
              <span></span>
              <button class="checkbox ${on ? "on a" : ""}" type="button" aria-pressed="${on}">${checkIcon()}</button>
              <span class="tree-label">${child.label}</span>
            </div>
          </div>`;
      })
      .join("");

    return `
      <div class="tree-node">
        <div class="tree-row parent ${pState !== "none" ? "active" : ""}">
          <button class="twist" type="button" aria-expanded="${expanded}" data-action="toggle-a-expand" data-id="${cat.id}">${twistIcon()}</button>
          <button class="checkbox ${checkClass}" type="button" data-action="toggle-a-parent" data-id="${cat.id}">${checkIcon(pState === "partial")}</button>
          <span class="tree-label">${cat.label}</span>
        </div>
        <div class="tree-children ${expanded ? "" : "hidden"}">${children}</div>
      </div>`;
  }).join("");
}

function renderTreeB() {
  return CATEGORIES.map((cat) => {
    const catState = state.designB[cat.id];
    const expanded = !!catState.expanded;
    const pState = parentCheckStateB(cat, catState);
    const enabled = catState.enabled;
    const parentClass =
      pState === "off"
        ? ""
        : pState === "all"
          ? "on b"
          : pState === "partial"
            ? "partial b"
            : "on b";

    const children = cat.children
      .map((child) => {
        const on = catState.selected.has(child.id);
        return `
          <div class="tree-node">
            <div class="tree-row child" data-action="toggle-b-leaf" data-cat="${cat.id}" data-id="${child.id}">
              <span></span>
              <button class="checkbox ${on ? "on b" : ""}" type="button" aria-pressed="${on}">${checkIcon()}</button>
              <span class="tree-label" style="${enabled ? "" : "opacity:.5"}">${child.label}</span>
            </div>
          </div>`;
      })
      .join("");

    const status =
      pState === "off"
        ? ` <span class="dim-tag">未开启</span>`
        : ` <span class="dim-tag on">开启</span>`;

    return `
      <div class="tree-node">
        <div class="tree-row parent ${enabled ? "b-active" : ""}">
          <button class="twist" type="button" aria-expanded="${expanded}" data-action="toggle-b-expand" data-id="${cat.id}">${twistIcon()}</button>
          <button class="checkbox ${parentClass}" type="button" data-action="toggle-b-parent" data-id="${cat.id}" title="${enabled ? "开启" : "未开启"}">${checkIcon(pState === "partial")}</button>
          <span class="tree-label">${cat.label}${status}</span>
        </div>
        <div class="tree-children ${expanded ? "" : "hidden"}">${children}</div>
      </div>`;
  }).join("");
}

function renderScene(opts = {}) {
  const visible = visibleIds();
  const task = opts.task;
  const matched = task && setsEqual(visible, expectedForCurrent());

  const statusHtml = task
    ? `<div class="task-status ${matched ? "match" : "miss"}">${
        matched ? "筛选结果正确" : "尚未匹配目标"
      }</div>`
    : "";

  const peopleHtml = PEOPLE.map((person) => {
    const isVisible = visible.has(person.id);
    const attrs =
      person.attrs.length === 0
        ? "未绑定任何分类"
        : person.attrs.map(labelForAttr).join(" · ");
    return `
      <div class="person ${isVisible ? "visible-person" : "hidden-person"}" style="left:${person.x}%;top:${person.y}%">
        <div class="dot">${person.name.slice(0, 1)}</div>
        <div class="person-tip"><strong>${person.name}</strong><br>${attrs}</div>
      </div>`;
  }).join("");

  const design = state.activeDesign;
  const isA = design === "A";

  const modeSwitch = isA
    ? `
      <div class="mode-switch">
        <div class="mode-switch-row">
          <div class="mode-label">${
            state.designA.mode === "and"
              ? "开关开启 · 同时满足（且）"
              : "开关关闭 · 满足任一（或）"
          }</div>
          <label class="switch" title="切换筛选逻辑">
            <input type="checkbox" data-action="toggle-mode" ${
              state.designA.mode === "and" ? "checked" : ""
            } />
            <span class="switch-track"></span>
          </label>
        </div>
        <p class="mode-desc">${
          state.designA.mode === "and"
            ? "开启：点选多个属性后，只显示同时带有这些属性的物体。"
            : "关闭：物体只要带有任意一个已选属性就会显示。"
        }</p>
      </div>`
    : `
      <div class="mode-switch">
        <p class="mode-desc" style="margin:0">
          大类勾选 = <strong style="color:var(--text)">开启</strong>该维度（PDF 分面筛选）。
          维度内多选为「或」，已开启维度之间为「且」。
          <strong style="color:var(--text)">未绑定</strong>该维的人不受该维影响。
          ${task?.setupHintB ? `<br><span style="color:var(--warn)">本题提示：${task.setupHintB}</span>` : ""}
        </p>
      </div>`;

  return `
    <div class="workspace panel">
      <aside class="sidebar">
        <div class="sidebar-head">
          <div class="design-badge ${isA ? "a" : "b"}">方案 ${design}</div>
          <h3>${isA ? "全局开关 + 勾选树" : "分维度开启（无开关）"}</h3>
          <p>${
            isA
              ? "顶部开关决定整体是「且」还是「或」。"
              : "对齐 PDF：身份 / 部门 / 岗位 / 作业类型分类筛选。"
          }</p>
          ${modeSwitch}
        </div>
        <div class="tree" data-tree="${design}">
          ${isA ? renderTreeA() : renderTreeB()}
        </div>
      </aside>
      <section class="scene-wrap">
        ${
          task
            ? `<div class="task-bar">
                <div>
                  <h4>任务 ${opts.taskNumber}/${TASKS.length} · ${task.title} · 方案 ${design}</h4>
                  <p>${task.brief} <span style="color:var(--text-muted)">${task.hint}</span></p>
                </div>
                ${statusHtml}
              </div>`
            : `<div class="task-bar">
                <div>
                  <h4>自由探索</h4>
                  <p>切换方案，对比显隐差异。悬停圆点可查看属性（含未绑定）。</p>
                </div>
              </div>`
        }
        <div class="scene">
          ${peopleHtml}
          <div class="scene-legend">地图场景 · 亮=显示 · 暗=隐藏 · 共 ${PEOPLE.length} 人</div>
        </div>
        <div class="stats-bar">
          <div>当前显示 <strong>${visible.size}</strong> / ${PEOPLE.length}</div>
          <div>方案 <strong>${design}</strong></div>
          ${
            isA
              ? `<div>逻辑 <strong>${
                  state.designA.mode === "and" ? "且" : "或"
                }</strong></div>`
              : `<div>已开启 <strong>${
                  Object.values(state.designB).filter((s) => s.enabled).length
                }</strong> / 4 维</div>`
          }
        </div>
        <div class="footer-actions">
          <div class="btn-row">
            ${
              opts.allowSwitch
                ? `<button class="btn btn-secondary" type="button" data-action="switch-design">切换到方案 ${
                    design === "A" ? "B" : "A"
                  }</button>`
                : ""
            }
            <button class="btn btn-ghost" type="button" data-action="reset-filters">重置筛选</button>
          </div>
          <div class="btn-row">${opts.footerActions || ""}</div>
        </div>
      </section>
    </div>`;
}

function currentTaskDesign() {
  return state.designOrder[state.designIndex];
}

function recordTaskAttempt() {
  const task = TASKS[state.taskIndex];
  const design = state.activeDesign;
  const visible = visibleIds();
  const ok = setsEqual(visible, expectedForCurrent());
  state.taskAttempts[`${task.id}:${design}`] = {
    taskId: task.id,
    design,
    ok,
    visibleCount: visible.size,
    at: Date.now(),
  };
  saveSession();
  return ok;
}

function bindWorkspace(root) {
  root.addEventListener("click", (event) => {
    const target = event.target.closest("[data-action]");
    if (!target) return;
    const action = target.dataset.action;

    if (action === "toggle-a-expand") {
      const id = target.dataset.id;
      state.designA.expanded[id] = !state.designA.expanded[id];
      paint();
      return;
    }

    if (action === "toggle-a-parent") {
      const cat = CATEGORIES.find((c) => c.id === target.dataset.id);
      const pState = parentCheckState(cat, state.designA.selected);
      if (pState === "all") {
        cat.children.forEach((c) => state.designA.selected.delete(c.id));
      } else {
        cat.children.forEach((c) => state.designA.selected.add(c.id));
      }
      paint();
      return;
    }

    if (action === "toggle-a-leaf") {
      const id =
        target.dataset.id ||
        target.closest("[data-id]")?.dataset.id;
      const leaf = target.closest("[data-action='toggle-a-leaf']");
      const leafId = leaf?.dataset.id || id;
      if (!leafId) return;
      if (state.designA.selected.has(leafId)) state.designA.selected.delete(leafId);
      else state.designA.selected.add(leafId);
      paint();
      return;
    }

    if (action === "toggle-b-expand") {
      const id = target.dataset.id;
      state.designB[id].expanded = !state.designB[id].expanded;
      paint();
      return;
    }

    if (action === "toggle-b-parent") {
      const id = target.dataset.id;
      const catState = state.designB[id];
      const cat = CATEGORIES.find((c) => c.id === id);
      if (!catState.enabled) {
        catState.enabled = true;
        catState.expanded = true;
        catState.selected = new Set(cat.children.map((c) => c.id));
      } else {
        const allOn = cat.children.every((c) => catState.selected.has(c.id));
        if (allOn || catState.selected.size === 0) {
          // turn off dimension (未开启)
          catState.enabled = false;
          catState.selected.clear();
        } else {
          cat.children.forEach((c) => catState.selected.add(c.id));
        }
      }
      paint();
      return;
    }

    if (action === "toggle-b-leaf") {
      const row = target.closest("[data-action='toggle-b-leaf']");
      const catId = row.dataset.cat;
      const id = row.dataset.id;
      const catState = state.designB[catId];
      if (!catState.enabled) {
        catState.enabled = true;
        catState.expanded = true;
      }
      if (catState.selected.has(id)) catState.selected.delete(id);
      else catState.selected.add(id);
      if (catState.selected.size === 0) {
        catState.enabled = false;
      }
      paint();
      return;
    }

    if (action === "reset-filters") {
      resetFiltersForDesign(state.activeDesign);
      paint();
      return;
    }

    if (action === "switch-design") {
      state.activeDesign = state.activeDesign === "A" ? "B" : "A";
      paint();
      return;
    }

    if (action === "check-task") {
      const ok = recordTaskAttempt();
      showToast(ok ? "正确，可以继续" : "还不对，再调整筛选");
      paint();
      return;
    }

    if (action === "next-design-or-task") {
      const ok = recordTaskAttempt();
      if (!ok) {
        showToast("请先筛出正确结果再继续");
        paint();
        return;
      }
      if (state.designIndex < state.designOrder.length - 1) {
        state.designIndex += 1;
        state.activeDesign = currentTaskDesign();
        resetFiltersForDesign(state.activeDesign);
      } else if (state.taskIndex < TASKS.length - 1) {
        state.taskIndex += 1;
        state.designIndex = 0;
        state.activeDesign = currentTaskDesign();
        resetFiltersForDesign(state.activeDesign);
      } else {
        state.step = "explore";
        state.activeDesign = "A";
        resetFiltersForDesign("A");
      }
      saveSession();
      paint();
      return;
    }

    if (action === "goto-vote") {
      state.step = "vote";
      saveSession();
      paint();
    }
  });

  root.addEventListener("change", (event) => {
    if (event.target.matches('[data-action="toggle-mode"]')) {
      state.designA.mode = event.target.checked ? "and" : "or";
      paint();
    }
  });
}

function renderSteps() {
  const order = ["intro", "task", "explore", "vote", "done"];
  const idx = order.indexOf(state.step === "results" ? "done" : state.step);
  el.steps.innerHTML = STEPS.map((step, i) => {
    const cls =
      step.id === state.step || (state.step === "results" && step.id === "done")
        ? "active"
        : i < idx
          ? "done"
          : "";
    return `<span class="step-pill ${cls}">${i + 1}. ${step.label}</span>`;
  }).join("");
}

function escapeHtml(str) {
  return String(str)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

function renderResults() {
  const votes = getVotes();
  const preferA = votes.filter((v) => v.prefer === "A").length;
  const preferB = votes.filter((v) => v.prefer === "B").length;
  const preferUnsure = votes.filter((v) => v.prefer === "unsure").length;
  const clearA = votes.filter((v) => v.clearer === "A").length;
  const clearB = votes.filter((v) => v.clearer === "B").length;

  document.getElementById("results-summary").innerHTML = `
    <div class="compare-grid">
      <div class="compare-card">
        <h3>更想用</h3>
        <p>A：<strong>${preferA}</strong>　B：<strong>${preferB}</strong>　不确定：<strong>${preferUnsure}</strong></p>
      </div>
      <div class="compare-card">
        <h3>更好理解</h3>
        <p>A：<strong>${clearA}</strong>　B：<strong>${clearB}</strong></p>
      </div>
    </div>
    <p class="lead" style="margin-top:16px">本机 <strong>${votes.length}</strong> 条。他人投票会发到你的邮箱；本页只汇总在此浏览器提交的票。</p>`;

  document.getElementById("results-list").innerHTML = votes.length
    ? votes
        .slice()
        .reverse()
        .map(
          (v) => `
      <div class="result-card">
        <div><strong>${
          v.prefer === "A" ? "倾向 A" : v.prefer === "B" ? "倾向 B" : "不确定"
        }</strong>
        · 更清晰：${v.clearer}
        · ${new Date(v.at).toLocaleString()}</div>
        <div style="color:var(--text-muted);margin-top:4px">${escapeHtml(
          v.name || "匿名"
        )}${v.note ? " · " + escapeHtml(v.note) : ""}</div>
      </div>`
        )
        .join("")
    : `<p class="lead">还没有本地投票记录。</p>`;
}

function paint() {
  Object.values(el.views).forEach((v) => v.classList.add("hidden"));
  const view = el.views[state.step] || el.views.intro;
  view.classList.remove("hidden");
  renderSteps();

  if (state.step === "task") {
    state.activeDesign = currentTaskDesign();
    const task = TASKS[state.taskIndex];
    const isLastDesign = state.designIndex >= state.designOrder.length - 1;
    const isLastTask = state.taskIndex >= TASKS.length - 1;
    const nextLabel = !isLastDesign
      ? `完成并用方案 ${state.designOrder[state.designIndex + 1]} 再试`
      : !isLastTask
        ? "下一题"
        : "进入自由对比";

    el.workspaceMount.innerHTML = renderScene({
      task,
      taskNumber: state.taskIndex + 1,
      footerActions: `
        <button class="btn btn-secondary" type="button" data-action="check-task">检查结果</button>
        <button class="btn btn-primary" type="button" data-action="next-design-or-task">${nextLabel}</button>`,
    });
    bindWorkspace(el.workspaceMount);
  }

  if (state.step === "explore") {
    el.exploreMount.innerHTML = renderScene({
      allowSwitch: true,
      footerActions: `<button class="btn btn-primary" type="button" data-action="goto-vote">去投票</button>`,
    });
    bindWorkspace(el.exploreMount);
  }

  if (state.step === "results") renderResults();
  saveSession();
}

async function submitVote(formData) {
  const vote = {
    prefer: formData.get("prefer"),
    clearer: formData.get("clearer"),
    name: (formData.get("name") || "").trim(),
    note: (formData.get("note") || "").trim(),
    designOrder: state.designOrder.join("→"),
    taskAttempts: state.taskAttempts,
    at: Date.now(),
    userAgent: navigator.userAgent.slice(0, 160),
  };

  addVote(vote);
  state.voteSubmitted = true;
  saveSession();

  const body = {
    prefer: vote.prefer,
    clearer: vote.clearer,
    name: vote.name || "匿名",
    note: vote.note || "(无)",
    designOrder: vote.designOrder,
    taskAttempts: JSON.stringify(vote.taskAttempts, null, 2),
    at: new Date(vote.at).toISOString(),
    _subject: `[显隐筛选A/B] 倾向方案${vote.prefer}`,
    _template: "table",
  };

  try {
    const res = await fetch(`https://formsubmit.co/ajax/${OWNER_EMAIL}`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json",
      },
      body: JSON.stringify(body),
    });
    if (!res.ok) throw new Error("fail");
    showToast("投票已提交");
  } catch {
    const text = `显隐筛选投票\n倾向: ${vote.prefer}\n更清晰: ${vote.clearer}\n姓名: ${vote.name || "匿名"}\n备注: ${vote.note || "(无)"}\n时间: ${new Date(vote.at).toLocaleString()}`;
    try {
      await navigator.clipboard.writeText(text);
      showToast("邮件暂不可用，投票文案已复制，可发给设计者");
    } catch {
      showToast("已保存在本机，请把投票内容发给设计者");
    }
  }

  state.step = "done";
  paint();
}

function wireGlobal() {
  document.getElementById("btn-start").addEventListener("click", () => {
    state.step = "task";
    state.taskIndex = 0;
    state.designIndex = 0;
    state.activeDesign = currentTaskDesign();
    resetFiltersForDesign(state.activeDesign);
    saveSession();
    paint();
  });

  document.getElementById("btn-skip-explore").addEventListener("click", () => {
    state.step = "explore";
    state.activeDesign = "A";
    resetFiltersForDesign("A");
    saveSession();
    paint();
  });

  document.getElementById("vote-form").addEventListener("submit", (e) => {
    e.preventDefault();
    const fd = new FormData(e.target);
    if (!fd.get("prefer") || !fd.get("clearer")) {
      showToast("请完成必选项");
      return;
    }
    submitVote(fd);
  });

  document.getElementById("btn-owner-results").addEventListener("click", () => {
    state.step = "results";
    paint();
  });

  document.getElementById("btn-back-done").addEventListener("click", () => {
    state.step = "done";
    paint();
  });

  document.getElementById("btn-export-votes").addEventListener("click", () => {
    const blob = new Blob([JSON.stringify(getVotes(), null, 2)], {
      type: "application/json",
    });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = `filter-abtest-votes-${Date.now()}.json`;
    a.click();
    URL.revokeObjectURL(url);
  });

  document.getElementById("btn-clear-votes").addEventListener("click", () => {
    if (confirm("清除本机全部投票记录？")) {
      localStorage.removeItem(STORAGE_KEY);
      renderResults();
      showToast("已清除");
    }
  });

  document.getElementById("btn-restart").addEventListener("click", () => {
    localStorage.removeItem(SESSION_KEY);
    state.step = "intro";
    state.taskIndex = 0;
    state.designIndex = 0;
    state.designOrder = Math.random() < 0.5 ? ["A", "B"] : ["B", "A"];
    state.taskAttempts = {};
    state.voteSubmitted = false;
    resetFiltersForDesign("A");
    paint();
  });
}

loadSession();
if (state.step === "task") state.activeDesign = currentTaskDesign();
wireGlobal();
paint();
