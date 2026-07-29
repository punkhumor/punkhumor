import { ATTR_META, allLeafIds, leafIdsUnder } from "./data.js";

function asSet(selectedIds) {
  return selectedIds instanceof Set ? selectedIds : new Set(selectedIds);
}

function isAllSelected(selected, universe) {
  return (
    selected.size >= universe.length && universe.every((id) => selected.has(id))
  );
}

/**
 * Design A
 * - multi  多选显示: OR — 带任一所选标签即显示
 * - filter 筛选显示: AND — 必须同时带上每一个所选标签
 * - 全选 → 全显示；全不选 → 全隐藏
 */
export function filterDesignA(people, selectedIds, mode, leafUniverse) {
  const universe = leafUniverse || allLeafIds();
  const selected = asSet(selectedIds);

  if (selected.size === 0) return [];
  if (isAllSelected(selected, universe)) return people.map((p) => p.id);

  if (mode === "multi") {
    return people
      .filter((p) => p.attrs.some((id) => selected.has(id)))
      .map((p) => p.id);
  }

  // 筛选显示：严格 AND
  const needed = [...selected];
  return people
    .filter((p) => needed.every((id) => p.attrs.includes(id)))
    .map((p) => p.id);
}

/**
 * Design B
 * - 同一大类内所选叶子：OR
 * - 有选中项的大类之间：AND
 * - 例：a1 + b1 + b2 → (有 a1) AND (有 b1 或 b2)
 * - 全选 → 全显示；全不选 → 全隐藏
 */
export function filterDesignB(people, selectedIds, leafUniverse) {
  const universe = leafUniverse || allLeafIds();
  const selected = asSet(selectedIds);

  if (selected.size === 0) return [];
  if (isAllSelected(selected, universe)) return people.map((p) => p.id);

  const byCat = new Map();
  for (const id of selected) {
    const catId = ATTR_META[id]?.categoryId;
    if (!catId) continue;
    if (!byCat.has(catId)) byCat.set(catId, []);
    byCat.get(catId).push(id);
  }

  const groups = [...byCat.values()];
  if (groups.length === 0) return [];

  return people
    .filter((person) =>
      groups.every((leafGroup) =>
        leafGroup.some((id) => person.attrs.includes(id))
      )
    )
    .map((p) => p.id);
}

export function initialDesignAState(categories) {
  const leaves = allLeafIds(categories);
  const expanded = {};
  for (const cat of categories) {
    expanded[cat.id] = cat.id === "department";
    for (const child of cat.children) {
      if (child.children?.length) expanded[child.id] = false;
    }
  }
  return {
    mode: "multi",
    selected: new Set(leaves),
    expanded,
  };
}

/** Design B uses the same selection/expand shape (no mode switch). */
export function initialDesignBState(categories) {
  const leaves = allLeafIds(categories);
  const expanded = {};
  for (const cat of categories) {
    expanded[cat.id] = cat.id === "department";
    for (const child of cat.children) {
      if (child.children?.length) expanded[child.id] = false;
    }
  }
  return {
    selected: new Set(leaves),
    expanded,
  };
}

export function nodeCheckState(node, selectedIds) {
  const leaves = leafIdsUnder(node);
  if (leaves.length === 0) return "none";
  const selected = asSet(selectedIds);
  const n = leaves.filter((id) => selected.has(id)).length;
  if (n === 0) return "none";
  if (n === leaves.length) return "all";
  return "partial";
}

export function parentCheckState(category, selectedIds) {
  return nodeCheckState(category, selectedIds);
}
