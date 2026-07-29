import { PEOPLE, CATEGORIES, allLeafIds, leafIdsUnder } from "./data.js";
import {
  filterDesignA,
  filterDesignB,
  initialDesignBState,
  initialDesignAState,
} from "./filters.js";

function assert(cond, msg) {
  if (!cond) throw new Error(msg);
}

function sameSet(a, b) {
  const A = new Set(a);
  const B = new Set(b);
  if (A.size !== B.size) return false;
  for (const x of A) if (!B.has(x)) return false;
  return true;
}

const universe = allLeafIds();

// Default all selected → everyone
{
  const st = initialDesignAState(CATEGORIES);
  const ids = filterDesignA(PEOPLE, st.selected, "filter", universe);
  assert(sameSet(ids, PEOPLE.map((p) => p.id)), "A all-on shows all");
}

// None selected → nobody
{
  const ids = filterDesignA(PEOPLE, new Set(), "filter", universe);
  assert(ids.length === 0, "A none hides all");
  assert(filterDesignA(PEOPLE, new Set(), "multi", universe).length === 0, "A multi none");
}

// Within category OR (筛选): prod-1 OR prod-2
{
  const sel = new Set(["dept-prod-1", "dept-prod-2"]);
  const ids = filterDesignA(PEOPLE, sel, "filter", universe);
  assert(sameSet(ids, ["zhang", "zhao"]), "A filter within-cat OR");
}

// Across categories AND: prod-1 AND engineer-soft
{
  const sel = new Set(["dept-prod-1", "pos-engineer-soft"]);
  const ids = filterDesignA(PEOPLE, sel, "filter", universe);
  assert(sameSet(ids, ["zhang"]), "A filter across AND");
}

// a1 + b1 + b2 → a1 AND (b1 OR b2)
{
  const sel = new Set([
    "dept-test-qa",
    "pos-engineer-soft",
    "pos-engineer-hard",
  ]);
  const ids = filterDesignA(PEOPLE, sel, "filter", universe);
  // chen: test-qa + soft; wu: test-qa + soft; zhou: test-auto — no
  assert(sameSet(ids, ["chen", "wu"]), "A filter a1 AND (b1|b2)");
}

// 多选显示: flat OR
{
  const sel = new Set(["dept-prod-1", "pos-qa"]);
  const ids = filterDesignA(PEOPLE, sel, "multi", universe);
  assert(
    sameSet(ids, ["zhang", "jiu", "zheng", "he"]),
    "A multi OR"
  );
}

// Design B still: unbound pass when filtering dept
{
  const state = initialDesignBState(CATEGORIES);
  state.department.selected = new Set(["dept-prod-1", "dept-prod-2"]);
  const ids = filterDesignB(PEOPLE, state);
  assert(ids.includes("zhang") && ids.includes("sun") && ids.includes("wang"), "B unbound");
  assert(!ids.includes("li"), "B hides admin");
}

// leaf helpers
assert(leafIdsUnder(CATEGORIES[1]).includes("dept-prod-1"), "leaves under dept");

console.log("All filter tests passed.");
