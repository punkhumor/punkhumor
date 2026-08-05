import {
  ATTR_META,
  allLeafIds,
  leafIdsUnder,
  CATEGORIES as DEFAULT_CATEGORIES,
} from "./data.js";

function asSet(selectedIds) {
  return selectedIds instanceof Set ? selectedIds : new Set(selectedIds);
}

function isAllSelected(selected, universe) {
  return (
    selected.size >= universe.length && universe.every((id) => selected.has(id))
  );
}

/**
 * Smart AND constraints for 匹配显示 / Design B:
 * - 某大类叶子全选 → 约束为「属于该大类」(有该类任一叶子即可)
 * - 某二级分组全选 → 约束为「属于该分组」
 * - 未全选的子类叶子 → 每个叶子单独作为必须命中的 tag（AND）
 * - 所有约束之间 AND
 */
export function buildSmartConstraints(
  selectedIds,
  categories = DEFAULT_CATEGORIES
) {
  const selected = asSet(selectedIds);
  const constraints = [];
  const cats = categories || DEFAULT_CATEGORIES;

  for (const cat of cats) {
    const catLeaves = leafIdsUnder(cat);
    const selInCat = catLeaves.filter((id) => selected.has(id));
    if (selInCat.length === 0) continue;

    if (selInCat.length === catLeaves.length) {
      constraints.push({ type: "any", ids: catLeaves, label: cat.label });
      continue;
    }

    // Within a category: always OR — collect all selected leaves into one "any" group
    constraints.push({ type: "any", ids: selInCat, label: cat.label + "(部分)" });
  }

  return constraints;
}

export function matchSmartConstraints(person, constraints) {
  return constraints.every((c) => {
    if (c.type === "any") return c.ids.some((id) => person.attrs.includes(id));
    if (c.type === "has") return person.attrs.includes(c.id);
    return false;
  });
}

/**
 * Build strict-AND constraints for 匹配显示 (Design A filter mode).
 * - Every leaf is individually required (AND), even within the same category
 * - EXCEPT: when a group node (2-level or top-level) is fully selected,
 *   it collapses to "belongs to that group" (any)
 */
export function buildStrictConstraints(
  selectedIds,
  categories = DEFAULT_CATEGORIES
) {
  const selected = asSet(selectedIds);
  const constraints = [];

  for (const cat of (categories || DEFAULT_CATEGORIES)) {
    const catLeaves = leafIdsUnder(cat);
    const selInCat = catLeaves.filter((id) => selected.has(id));
    if (selInCat.length === 0) continue;

    if (selInCat.length === catLeaves.length) {
      constraints.push({ type: "any", ids: catLeaves, label: cat.label });
      continue;
    }

    for (const child of cat.children) {
      const leaves = leafIdsUnder(child);
      const selMid = leaves.filter((id) => selected.has(id));
      if (selMid.length === 0) continue;

      if (child.children?.length && selMid.length === leaves.length) {
        constraints.push({ type: "any", ids: leaves, label: child.label });
      } else {
        for (const id of selMid) {
          constraints.push({ type: "has", id, label: ATTR_META[id]?.label || id });
        }
      }
    }
  }

  return constraints;
}

/**
 * Design A (带模式)
 * - multi  多选显示: OR — 带任一标签即显示
 * - filter 匹配显示: strict AND — 每个叶子都要有(分组全选合并为属于该组)
 */
export function filterDesignA(
  people,
  selectedIds,
  mode,
  leafUniverse,
  categories = DEFAULT_CATEGORIES
) {
  const universe = leafUniverse || allLeafIds();
  const selected = asSet(selectedIds);

  if (selected.size === 0) return [];
  if (isAllSelected(selected, universe)) return people.map((p) => p.id);

  if (mode === "multi") {
    return people
      .filter((p) => p.attrs.some((id) => selected.has(id)))
      .map((p) => p.id);
  }

  const constraints = buildStrictConstraints(selected, categories);
  if (constraints.length === 0) return [];
  return people
    .filter((p) => matchSmartConstraints(p, constraints))
    .map((p) => p.id);
}

/**
 * Design B：始终 smart AND（类内全选按类，未全选叶子 AND，类间 AND）
 */
export function filterDesignB(
  people,
  selectedIds,
  leafUniverse,
  categories = DEFAULT_CATEGORIES
) {
  const universe = leafUniverse || allLeafIds();
  const selected = asSet(selectedIds);

  if (selected.size === 0) return [];
  if (isAllSelected(selected, universe)) return people.map((p) => p.id);

  const constraints = buildSmartConstraints(selected, categories);
  if (constraints.length === 0) return [];
  return people
    .filter((p) => matchSmartConstraints(p, constraints))
    .map((p) => p.id);
}

export function initialDesignAState(categories = DEFAULT_CATEGORIES) {
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

export function initialDesignBState(categories = DEFAULT_CATEGORIES) {
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

export function clearAllLeaves() {
  return new Set();
}

export function selectAllLeaves(categories = DEFAULT_CATEGORIES) {
  return new Set(allLeafIds(categories));
}
