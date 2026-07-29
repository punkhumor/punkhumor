import {
  ATTR_META,
  attrsInCategory,
  allLeafIds,
  leafIdsUnder,
} from "./data.js";

/**
 * Design A (toggle scheme)
 * ---------------------------
 * mode "multi"  多选显示: selected leaves are OR — match any → show.
 * mode "filter" 筛选显示:
 *   - within one top category: OR among its selected leaves
 *   - across top categories that have ≥1 selected leaf: AND
 *   Example: a1 + b1 + b2 → (has a1) AND (has b1 OR b2)
 *
 * 全选 → show everyone
 * 全不选 → show nobody
 */
export function filterDesignA(people, selectedIds, mode, leafUniverse) {
  const universe = leafUniverse || allLeafIds();
  const selected = selectedIds instanceof Set ? selectedIds : new Set(selectedIds);

  if (selected.size === 0) return [];

  const allOn =
    selected.size >= universe.length && universe.every((id) => selected.has(id));
  if (allOn) return people.map((p) => p.id);

  if (mode === "multi") {
    return people
      .filter((p) => p.attrs.some((id) => selected.has(id)))
      .map((p) => p.id);
  }

  // filter mode — group selected leaves by top category
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

/**
 * Design B (facet scheme): enable dimensions; within OR; across AND;
 * unbound on a dimension passes that dimension.
 */
export function filterDesignB(people, categoryState) {
  const activeFacets = Object.entries(categoryState).filter(
    ([, state]) => state.enabled
  );

  if (activeFacets.length === 0) return people.map((p) => p.id);

  return people
    .filter((person) =>
      activeFacets.every(([categoryId, state]) => {
        const bound = attrsInCategory(person, categoryId);
        if (bound.length === 0) return true;
        if (state.selected.size === 0) return false;
        return bound.some((id) => state.selected.has(id));
      })
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
    mode: "filter", // 筛选显示
    selected: new Set(leaves),
    expanded,
  };
}

export function initialDesignBState(categories) {
  const state = {};
  for (const cat of categories) {
    const leaves = leafIdsUnder(cat);
    state[cat.id] = {
      enabled: true,
      selected: new Set(leaves),
      expanded: cat.id === "department",
    };
    for (const child of cat.children) {
      if (child.children?.length) {
        state[`${cat.id}::${child.id}`] = { expanded: false };
      }
    }
  }
  // keep mid expand on category state object via expandedMids map instead
  state._midExpanded = {};
  for (const cat of categories) {
    for (const child of cat.children) {
      if (child.children?.length) state._midExpanded[child.id] = false;
    }
  }
  return state;
}

/** Check state for a node given selected leaf set. */
export function nodeCheckState(node, selectedIds) {
  const leaves = leafIdsUnder(node);
  if (leaves.length === 0) return "none";
  const n = leaves.filter((id) => selectedIds.has(id)).length;
  if (n === 0) return "none";
  if (n === leaves.length) return "all";
  return "partial";
}

export function parentCheckState(category, selectedIds) {
  return nodeCheckState(category, selectedIds);
}

export function parentCheckStateB(category, catState) {
  if (!catState.enabled) return "off";
  return nodeCheckState(category, catState.selected);
}
