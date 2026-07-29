import { ATTR_META, attrsInCategory } from "./data.js";

/**
 * Design A — global mode toggle.
 * ON  (and): person must possess every selected leaf attribute.
 * OFF (or):  person shows if they possess any selected leaf attribute.
 * Empty selection → show everyone.
 */
export function filterDesignA(people, selectedIds, mode) {
  const selected = [...selectedIds];
  if (selected.length === 0) return people.map((p) => p.id);

  if (mode === "and") {
    return people
      .filter((p) => selected.every((id) => p.attrs.includes(id)))
      .map((p) => p.id);
  }

  return people
    .filter((p) => selected.some((id) => p.attrs.includes(id)))
    .map((p) => p.id);
}

/**
 * Design B — PDF faceted filter (三维显隐控制):
 * - Between the 4 categories: AND
 * - Within a category: OR
 * - Category not enabled (未开启) → no constraint
 * - Person unbound on an enabled category → not affected by that category
 * - Person bound on a category → must match at least one selected child
 * - Enabled + no children selected → only unbound people pass that facet
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
        if (bound.length === 0) return true; // 未绑定不受影响
        const checked = state.selected;
        if (checked.size === 0) return false;
        return bound.some((id) => checked.has(id));
      })
    )
    .map((p) => p.id);
}

/** Default PDF state: all dimensions enabled, all children selected. */
export function initialDesignBState(categories) {
  const state = {};
  for (const cat of categories) {
    state[cat.id] = {
      enabled: true,
      selected: new Set(cat.children.map((c) => c.id)),
      expanded: cat.id === "department",
    };
  }
  return state;
}

export function parentCheckState(category, selectedIds) {
  const childIds = category.children.map((c) => c.id);
  const n = childIds.filter((id) => selectedIds.has(id)).length;
  if (n === 0) return "none";
  if (n === childIds.length) return "all";
  return "partial";
}

export function parentCheckStateB(category, catState) {
  if (!catState.enabled) return "off";
  return parentCheckState(category, catState.selected);
}
