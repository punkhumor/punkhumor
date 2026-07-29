import { PEOPLE, CATEGORIES, allLeafIds, leafIdsUnder } from "./data.js";
import {
  filterDesignA,
  filterDesignB,
  initialDesignAState,
  initialDesignBState,
  buildSmartConstraints,
} from "./filters.js";

function assert(cond, msg) {
  if (!cond) throw new Error("FAIL: " + msg);
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
  const b = initialDesignBState(CATEGORIES);
  assert(filterDesignB(PEOPLE, b.selected, universe, CATEGORIES).length === PEOPLE.length, "B all");
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

// B: same category OR — visitor-guest + contractor
{
  const ids = filterDesignB(
    PEOPLE,
    new Set(["id-visitor-guest", "id-contractor"]),
    universe,
    CATEGORIES
  );
  assert(sameSet(ids, ["wang", "wu", "xu"]), "B same-cat OR (visitor+contractor)");
}

// B: same category OR — prod-1 + prod-2
{
  const ids = filterDesignB(
    PEOPLE,
    new Set(["dept-prod-1", "dept-prod-2"]),
    universe,
    CATEGORIES
  );
  assert(sameSet(ids, ["zhang", "zhao"]), "B dept OR");
}

// B: cross category AND — test-qa + engineer-soft
{
  const ids = filterDesignB(
    PEOPLE,
    new Set(["dept-test-qa", "pos-engineer-soft"]),
    universe,
    CATEGORIES
  );
  assert(sameSet(ids, ["chen", "wu"]), "B cross AND");
}

// B: full identity + prod-1 → identity(any) AND dept(prod-1)
{
  const idLeaves = leafIdsUnder(CATEGORIES.find((c) => c.id === "identity"));
  const sel = new Set([...idLeaves, "dept-prod-1"]);
  const ids = filterDesignB(PEOPLE, sel, universe, CATEGORIES);
  assert(sameSet(ids, ["zhang"]), "B smart full-group AND leaf");
}

// B: a1 + b1 + b2 → dept(test-qa) AND pos(eng-soft OR eng-hard)
{
  const sel = new Set([
    "dept-test-qa",
    "pos-engineer-soft",
    "pos-engineer-hard",
  ]);
  const ids = filterDesignB(PEOPLE, sel, universe, CATEGORIES);
  // chen: test-qa + soft ✓; wu: test-qa + soft ✓; zhou: test-auto ✗
  assert(sameSet(ids, ["chen", "wu"]), "B a1 AND (b1|b2)");
}

// A 匹配显示: same smart rules as B
{
  const sel = new Set(["id-visitor-guest", "id-contractor"]);
  const ids = filterDesignA(PEOPLE, sel, "filter", universe, CATEGORIES);
  assert(sameSet(ids, ["wang", "wu", "xu"]), "A filter same-cat OR");
}

console.log("All filter tests passed.");
