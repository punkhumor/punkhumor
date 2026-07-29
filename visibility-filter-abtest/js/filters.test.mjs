import { PEOPLE, CATEGORIES, allLeafIds, leafIdsUnder } from "./data.js";
import {
  filterDesignA,
  filterDesignB,
  initialDesignAState,
  initialDesignBState,
  buildSmartConstraints,
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

// all / none
{
  const a = initialDesignAState(CATEGORIES);
  assert(
    filterDesignA(PEOPLE, a.selected, "multi", universe, CATEGORIES).length ===
      PEOPLE.length,
    "A all"
  );
  assert(filterDesignA(PEOPLE, new Set(), "filter", universe, CATEGORIES).length === 0, "A none");
  assert(filterDesignB(PEOPLE, new Set(), universe, CATEGORIES).length === 0, "B none");
}

// A multi OR
{
  const ids = filterDesignA(
    PEOPLE,
    new Set(["dept-prod-1", "pos-qa"]),
    "multi",
    universe,
    CATEGORIES
  );
  assert(sameSet(ids, ["zhang", "jiu", "zheng", "he"]), "A multi");
}

// A/B smart: full identity + 生产一组
{
  const identityLeaves = leafIdsUnder(CATEGORIES.find((c) => c.id === "identity"));
  const sel = new Set([...identityLeaves, "dept-prod-1"]);
  const constraints = buildSmartConstraints(sel, CATEGORIES);
  assert(
    constraints.some((c) => c.type === "any" && c.label === "人员身份"),
    "full identity => category any"
  );
  assert(
    constraints.some((c) => c.type === "has" && c.id === "dept-prod-1"),
    "prod-1 has"
  );
  const idsA = filterDesignA(PEOPLE, sel, "filter", universe, CATEGORIES);
  const idsB = filterDesignB(PEOPLE, sel, universe, CATEGORIES);
  // zhang has identity + prod-1; he has identity but admin; wang has identity no dept-prod-1
  assert(sameSet(idsA, ["zhang"]), "A smart");
  assert(sameSet(idsB, ["zhang"]), "B smart");
}

// full 外来人员 mid-group
{
  const visitor = CATEGORIES.find((c) => c.id === "identity").children.find(
    (c) => c.id === "id-visitor"
  );
  const sel = new Set(leafIdsUnder(visitor));
  const ids = filterDesignB(PEOPLE, sel, universe, CATEGORIES);
  assert(sameSet(ids, ["wang", "he"]), "full visitor group");
}

// partial leaves AND within smart (two specific leaves)
{
  const sel = new Set(["dept-prod-1", "pos-engineer-soft"]);
  const ids = filterDesignB(PEOPLE, sel, universe, CATEGORIES);
  assert(sameSet(ids, ["zhang"]), "partial AND leaves");
}

console.log("All filter tests passed.");
