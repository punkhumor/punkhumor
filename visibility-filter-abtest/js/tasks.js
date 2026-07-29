/** Guided tasks with design-specific expected visible ids (PDF-aligned). */

export const TASKS = [
  {
    id: "task-pdf-dept",
    title: "收窄部门",
    brief:
      "只保留「生产部」。方案 B：其他大类保持全选；方案 A：用或模式只勾选生产部。",
    hint: "注意：方案 B 下「未绑定部门」的人仍会显示。",
    expectedA: ["zhang", "zhao"],
    setupA: { mode: "or", selected: [] },
    expectedB: ["zhang", "zhao", "wang", "sun", "qian", "jiu"],
    setupHintB: "部门只留生产部，其余三大类保持全选（开启）。",
  },
  {
    id: "task-cross-and",
    title: "跨类同时满足",
    brief: "只要「测试部」且「工程师」。",
    hint: "方案 A 开「同时满足」；方案 B 两个维度都开启并收窄。",
    expectedA: ["chen", "zhou", "wu"],
    setupA: { mode: "and", selected: [] },
    expectedB: ["chen", "zhou", "wu", "qian", "sun", "wang"],
    setupHintB: "部门=测试部，岗位=工程师；身份与作业可全选或未开启。",
  },
  {
    id: "task-or-work",
    title: "同类多项（或）",
    brief: "显示「动火作业」或「高处作业」的人员。",
    hint: "同一大类内多选为或。",
    expectedA: ["zhang", "chen", "he", "zheng"],
    setupA: { mode: "or", selected: [] },
    // B: only workType enabled with fire+height; unbound on workType still show
    expectedB: [
      "zhang",
      "chen",
      "he",
      "zheng",
      "wang",
      "zhao",
      "sun",
      "qian",
      "jiu",
    ],
    setupHintB: "只开启作业类型，并勾选动火+高处；其余大类未开启。",
  },
];
