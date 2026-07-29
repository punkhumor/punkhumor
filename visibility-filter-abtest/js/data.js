/** Taxonomy (up to 3 levels) + scene people. */

export const CATEGORY_COLORS = {
  identity: "#5b8def",
  department: "#2bb8a6",
  position: "#e8a54b",
  workType: "#c986e8",
};

export const CATEGORIES = [
  {
    id: "identity",
    label: "人员身份",
    children: [
      { id: "id-internal", label: "内部员工" },
      { id: "id-contractor", label: "承包商" },
      {
        id: "id-visitor",
        label: "外来人员",
        children: [
          { id: "id-visitor-guest", label: "临时访客" },
          { id: "id-visitor-vendor", label: "供应商来访" },
        ],
      },
    ],
  },
  {
    id: "department",
    label: "部门",
    children: [
      {
        id: "dept-prod",
        label: "生产部",
        children: [
          { id: "dept-prod-1", label: "生产一组" },
          { id: "dept-prod-2", label: "生产二组" },
        ],
      },
      { id: "dept-admin", label: "行政部" },
      {
        id: "dept-test",
        label: "测试部",
        children: [
          { id: "dept-test-qa", label: "质量测试" },
          { id: "dept-test-auto", label: "自动化测试" },
        ],
      },
      { id: "dept-tech", label: "技术部" },
      { id: "dept-market", label: "市场部" },
    ],
  },
  {
    id: "position",
    label: "岗位",
    children: [
      {
        id: "pos-engineer",
        label: "工程师",
        children: [
          { id: "pos-engineer-soft", label: "软件工程师" },
          { id: "pos-engineer-hard", label: "硬件工程师" },
        ],
      },
      { id: "pos-qa", label: "质检员" },
      { id: "pos-pm", label: "项目经理" },
      { id: "pos-safety", label: "安全员" },
    ],
  },
  {
    id: "workType",
    label: "作业类型",
    children: [
      {
        id: "work-fire",
        label: "动火作业",
        children: [
          { id: "work-fire-weld", label: "焊接" },
          { id: "work-fire-cut", label: "切割" },
        ],
      },
      { id: "work-earth", label: "动土作业" },
      { id: "work-height", label: "高处作业" },
      { id: "work-electric", label: "临时用电作业" },
      { id: "work-space", label: "受限空间作业" },
    ],
  },
];

/** Leaf nodes under a node (node itself if it has no children). */
export function leafNodes(node) {
  if (!node.children?.length) return [node];
  return node.children.flatMap(leafNodes);
}

export function leafIdsUnder(node) {
  return leafNodes(node).map((n) => n.id);
}

export function allLeafIds(categories = CATEGORIES) {
  return categories.flatMap((cat) => leafIdsUnder(cat));
}

/** Every selectable id → meta (leaves + intermediate groups for labeling). */
export const ATTR_META = {};
for (const cat of CATEGORIES) {
  ATTR_META[cat.id] = {
    categoryId: cat.id,
    categoryLabel: cat.label,
    label: cat.label,
    level: 1,
  };
  for (const child of cat.children) {
    ATTR_META[child.id] = {
      categoryId: cat.id,
      categoryLabel: cat.label,
      label: child.label,
      level: 2,
    };
    if (child.children?.length) {
      for (const g of child.children) {
        ATTR_META[g.id] = {
          categoryId: cat.id,
          categoryLabel: cat.label,
          label: g.label,
          level: 3,
          parentId: child.id,
        };
      }
    }
  }
}

/**
 * People attrs are leaf ids only.
 * Missing a category = unbound for Design B.
 */
export const PEOPLE = [
  {
    id: "zhang",
    name: "张三",
    x: 18,
    y: 28,
    attrs: ["dept-prod-1", "pos-engineer-soft", "id-internal", "work-fire-weld"],
  },
  {
    id: "li",
    name: "李四",
    x: 42,
    y: 22,
    attrs: ["dept-admin", "pos-engineer-hard", "id-internal", "work-earth"],
  },
  {
    id: "wang",
    name: "王五",
    x: 68,
    y: 30,
    attrs: ["pos-engineer-soft", "id-visitor-guest"],
  },
  {
    id: "zhao",
    name: "赵六",
    x: 25,
    y: 55,
    attrs: ["dept-prod-2"],
  },
  {
    id: "sun",
    name: "孙七",
    x: 55,
    y: 48,
    attrs: [],
  },
  {
    id: "qian",
    name: "钱八",
    x: 78,
    y: 58,
    attrs: ["pos-engineer-hard"],
  },
  {
    id: "jiu",
    name: "九九",
    x: 35,
    y: 72,
    attrs: ["pos-qa"],
  },
  {
    id: "chen",
    name: "陈晨",
    x: 62,
    y: 75,
    attrs: ["dept-test-qa", "pos-engineer-soft", "id-internal", "work-fire-cut"],
  },
  {
    id: "zhou",
    name: "周杰",
    x: 12,
    y: 80,
    attrs: ["dept-test-auto", "pos-engineer-hard", "id-internal", "work-earth"],
  },
  {
    id: "wu",
    name: "吴敏",
    x: 48,
    y: 38,
    attrs: ["dept-test-qa", "pos-engineer-soft", "id-contractor", "work-earth"],
  },
  {
    id: "zheng",
    name: "郑浩",
    x: 85,
    y: 25,
    attrs: ["dept-test-auto", "pos-qa", "id-internal", "work-height"],
  },
  {
    id: "huang",
    name: "黄蕾",
    x: 72,
    y: 42,
    attrs: ["dept-tech", "pos-pm", "id-internal", "work-electric"],
  },
  {
    id: "xu",
    name: "徐鹏",
    x: 30,
    y: 40,
    attrs: ["dept-market", "pos-safety", "id-contractor", "work-space"],
  },
  {
    id: "he",
    name: "何静",
    x: 88,
    y: 70,
    attrs: ["dept-admin", "pos-qa", "id-visitor-vendor", "work-fire-weld"],
  },
];

export function labelForAttr(id) {
  return ATTR_META[id]?.label ?? id;
}

export function categoryOfAttr(id) {
  return ATTR_META[id]?.categoryId ?? null;
}

export function attrsInCategory(person, categoryId) {
  return person.attrs.filter((id) => ATTR_META[id]?.categoryId === categoryId);
}

/** Marker color: prefer department, then identity, then position, then work. */
export function colorForPerson(person) {
  const order = ["department", "identity", "position", "workType"];
  for (const catId of order) {
    if (attrsInCategory(person, catId).length) return CATEGORY_COLORS[catId];
  }
  return "#8b9aab";
}
