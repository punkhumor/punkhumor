import { PEOPLE, CATEGORIES, allLeafIds } from "./data.js";
import {
  filterDesignA,
  filterDesignB,
  initialDesignAState,
  initialDesignBState,
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

// A/B 全选 → 全员
{
  const a = initialDesignAState(CATEGORIES);
  const b = initialDesignBState(CATEGORIES);
  assert(
    sameSet(
      filterDesignA(PEOPLE, a.selected, "multi", universe),
      PEOPLE.map((p) => p.id)
    ),
    "A all"
  );
  assert(
    sameSet(filterDesignB(PEOPLE, b.selected, universe), PEOPLE.map((p) => p.id)),
    "B all"
  );
}

// 全不选 → 无人
assert(filterDesignA(PEOPLE, new Set(), "multi", universe).length === 0, "A none");
assert(filterDesignA(PEOPLE, new Set(), "filter", universe).length === 0, "A none filter");
assert(filterDesignB(PEOPLE, new Set(), universe).length === 0, "B none");

// A 多选 = OR
{
  const sel = new Set(["dept-prod-1", "pos-qa"]);
  const ids = filterDesignA(PEOPLE, sel, "multi", universe);
  assert(sameSet(ids, ["zhang", "jiu", "zheng", "he"]), "A multi OR");
}

// A 筛选 = 严格 AND（每个标签都要有）
{
  const sel = new Set(["dept-prod-1", "pos-engineer-soft"]);
  const ids = filterDesignA(PEOPLE, sel, "filter", universe);
  assert(sameSet(ids, ["zhang"]), "A filter AND");
}
{
  // a1+b1+b2 在严格 AND 下几乎无人（需同时有三个标签）
  const sel = new Set([
    "dept-test-qa",
    "pos-engineer-soft",
    "pos-engineer-hard",
  ]);
  const ids = filterDesignA(PEOPLE, sel, "filter", universe);
  assert(ids.length === 0, "A filter AND three tags");
}

// B：类内 OR、类间 AND
{
  const sel = new Set(["dept-prod-1", "dept-prod-2"]);
  const ids = filterDesignB(PEOPLE, sel, universe);
  assert(sameSet(ids, ["zhang", "zhao"]), "B within OR");
}
{
  const sel = new Set(["dept-prod-1", "pos-engineer-soft"]);
  const ids = filterDesignB(PEOPLE, sel, universe);
  assert(sameSet(ids, ["zhang"]), "B across AND");
}
{
  // a1 + b1 + b2 → a1 AND (b1 OR b2)
  const sel = new Set([
    "dept-test-qa",
    "pos-engineer-soft",
    "pos-engineer-hard",
  ]);
  const ids = filterDesignB(PEOPLE, sel, universe);
  assert(sameSet(ids, ["chen", "wu"]), "B a1 AND (b1|b2)");
}

console.log("All filter tests passed.");
