/** Shared taxonomy + mock scene entities — aligned with 三维显隐控制.pdf */

export const CATEGORIES = [
  {
    id: "identity",
    label: "人员身份",
    children: [
      { id: "id-internal", label: "内部员工" },
      { id: "id-contractor", label: "承包商" },
      { id: "id-visitor", label: "外来人员" },
    ],
  },
  {
    id: "department",
    label: "部门",
    children: [
      { id: "dept-prod", label: "生产部" },
      { id: "dept-admin", label: "行政部" },
      { id: "dept-test", label: "测试部" },
      { id: "dept-tech", label: "技术部" },
      { id: "dept-market", label: "市场部" },
    ],
  },
  {
    id: "position",
    label: "岗位",
    children: [
      { id: "pos-engineer", label: "工程师" },
      { id: "pos-qa", label: "质检员" },
      { id: "pos-pm", label: "项目经理" },
      { id: "pos-safety", label: "安全员" },
    ],
  },
  {
    id: "workType",
    label: "作业类型",
    children: [
      { id: "work-fire", label: "动火作业" },
      { id: "work-earth", label: "动土作业" },
      { id: "work-height", label: "高处作业" },
      { id: "work-electric", label: "临时用电作业" },
      { id: "work-space", label: "受限空间作业" },
    ],
  },
];

export const ATTR_META = Object.fromEntries(
  CATEGORIES.flatMap((cat) =>
    cat.children.map((child) => [
      child.id,
      { categoryId: cat.id, categoryLabel: cat.label, label: child.label },
    ])
  )
);

/**
 * attrs may omit a category entirely = 「未绑定」— Design B does not hide them
 * for that dimension (PDF: 未绑定人员不受影响).
 */
export const PEOPLE = [
  {
    id: "zhang",
    name: "张三",
    x: 18,
    y: 28,
    attrs: ["dept-prod", "pos-engineer", "id-internal", "work-fire"],
  },
  {
    id: "li",
    name: "李四",
    x: 42,
    y: 22,
    attrs: ["dept-admin", "pos-engineer", "id-internal", "work-earth"],
  },
  {
    id: "wang",
    name: "王五",
    x: 68,
    y: 30,
    attrs: ["pos-engineer", "id-visitor"],
  },
  {
    id: "zhao",
    name: "赵六",
    x: 25,
    y: 55,
    attrs: ["dept-prod"],
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
    attrs: ["pos-engineer"],
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
    attrs: ["dept-test", "pos-engineer", "id-internal", "work-fire"],
  },
  {
    id: "zhou",
    name: "周杰",
    x: 12,
    y: 80,
    attrs: ["dept-test", "pos-engineer", "id-internal", "work-earth"],
  },
  {
    id: "wu",
    name: "吴敏",
    x: 48,
    y: 38,
    attrs: ["dept-test", "pos-engineer", "id-contractor", "work-earth"],
  },
  {
    id: "zheng",
    name: "郑浩",
    x: 85,
    y: 25,
    attrs: ["dept-test", "pos-qa", "id-internal", "work-height"],
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
    attrs: ["dept-admin", "pos-qa", "id-visitor", "work-fire"],
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
