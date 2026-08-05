import { PEOPLE, CATEGORIES, allLeafIds, leafIdsUnder } from "./data.js";
import {
  filterDesignA,
  filterDesignB,
  initialDesignAState,
  initialDesignBState,
  buildSmartConstraints,
  buildStrictConstraints,
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
  assert(filterDesignA(PEOPLE, a.selected, "multi", universe, CATEGORIES).length === PEOPLE.length, "A all");
  assert(filterDesignA(PEOPLE, new Set(), "filter", universe, CATEGORIES).length === 0, "A none");
  assert(filterDesignB(PEOPLE, new Set(), universe, CATEGORIES).length === 0, "B none");
  const b = initialDesignBState(CATEGORIES);
  assert(filterDesignB(PEOPLE, b.selected, universe, CATEGORIES).length === PEOPLE.length, "B all");
}

// A 多选 OR
{
  const ids = filterDesignA(PEOPLE, new Set(["dept-prod-1", "pos-qa"]), "multi", universe, CATEGORIES);
  assert(sameSet(ids, ["zhang", "jiu", "zheng", "he"]), "A multi OR");
}

// A 匹配: 同大类 = AND → 技术部 + 市场部 → nobody
{
  const ids = filterDesignA(PEOPLE, new Set(["dept-tech", "dept-market"]), "filter", universe, CATEGORIES);
  assert(ids.length === 0, "A filter same-cat AND (tech+market=nobody)");
}

// A 匹配: 测试部(全选) + 市场部 → 属于测试部 AND 有市场部 → nobody
{
  const testNode = CATEGORIES.find(c => c.id === "department").children.find(c => c.id === "dept-test");
  const sel = new Set([...leafIdsUnder(testNode), "dept-market"]);
  const ids = filterDesignA(PEOPLE, sel, "filter", universe, CATEGORIES);
  assert(ids.length === 0, "A filter test-group AND market = nobody");
}

// A 匹配: 跨大类 AND → 生产一组 + 软件工程师 → zhang
{
  const ids = filterDesignA(PEOPLE, new Set(["dept-prod-1", "pos-engineer-soft"]), "filter", universe, CATEGORIES);
  assert(sameSet(ids, ["zhang"]), "A filter cross-cat AND");
}

// B: 同大类 = OR → 临时访客 + 承包商
{
  const ids = filterDesignB(PEOPLE, new Set(["id-visitor-guest", "id-contractor"]), universe, CATEGORIES);
  assert(sameSet(ids, ["wang", "wu", "xu"]), "B same-cat OR");
}

// B: 同大类 = OR → 技术部 + 市场部
{
  const ids = filterDesignB(PEOPLE, new Set(["dept-tech", "dept-market"]), universe, CATEGORIES);
  assert(sameSet(ids, ["huang", "xu"]), "B dept OR tech|market");
}

// B: 跨大类 = AND → test-qa + engineer-soft
{
  const ids = filterDesignB(PEOPLE, new Set(["dept-test-qa", "pos-engineer-soft"]), universe, CATEGORIES);
  assert(sameSet(ids, ["chen", "wu"]), "B cross AND");
}

// B: full identity + prod-1
{
  const idLeaves = leafIdsUnder(CATEGORIES.find(c => c.id === "identity"));
  const sel = new Set([...idLeaves, "dept-prod-1"]);
  const ids = filterDesignB(PEOPLE, sel, universe, CATEGORIES);
  assert(sameSet(ids, ["zhang"]), "B full-group AND leaf");
}

// B: a1 + b1 + b2 across cats
{
  const sel = new Set(["dept-test-qa", "pos-engineer-soft", "pos-engineer-hard"]);
  const ids = filterDesignB(PEOPLE, sel, universe, CATEGORIES);
  assert(sameSet(ids, ["chen", "wu"]), "B a1 AND (b1|b2)");
}

// A filter: visitor-guest + contractor → strict AND → nobody has both
{
  const ids = filterDesignA(PEOPLE, new Set(["id-visitor-guest", "id-contractor"]), "filter", universe, CATEGORIES);
  assert(ids.length === 0, "A filter strict AND visitor+contractor");
}

console.log("All filter tests passed.");
