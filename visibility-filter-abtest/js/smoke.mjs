import { PEOPLE, CATEGORIES, allLeafIds, leafIdsUnder } from "./data.js";
import {
  filterDesignA,
  filterDesignB,
  initialDesignAState,
  buildSmartConstraints,
} from "./filters.js";

function assert(c, m) {
  if (!c) throw new Error(m);
}

const u = allLeafIds();
const a = initialDesignAState(CATEGORIES);
assert(
  filterDesignA(PEOPLE, a.selected, "multi", u, CATEGORIES).length === PEOPLE.length,
  "A"
);
const idLeaves = leafIdsUnder(CATEGORIES.find((c) => c.id === "identity"));
const sel = new Set([...idLeaves, "dept-prod-1"]);
assert(buildSmartConstraints(sel, CATEGORIES).length >= 2, "constraints");
assert(
  filterDesignB(PEOPLE, sel, u, CATEGORIES).includes("zhang"),
  "B"
);
console.log("smoke ok");
