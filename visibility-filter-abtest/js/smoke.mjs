import { PEOPLE, CATEGORIES, allLeafIds } from "./data.js";
import {
  filterDesignA,
  filterDesignB,
  initialDesignAState,
  initialDesignBState,
} from "./filters.js";

function assert(c, m) {
  if (!c) throw new Error(m);
}

const u = allLeafIds();
const a = initialDesignAState(CATEGORIES);
const b = initialDesignBState(CATEGORIES);
assert(filterDesignA(PEOPLE, a.selected, "multi", u).length === PEOPLE.length, "A");
assert(filterDesignB(PEOPLE, b.selected, u).length === PEOPLE.length, "B");
assert(filterDesignA(PEOPLE, new Set(["dept-prod-1"]), "multi", u).includes("zhang"), "or");
assert(
  filterDesignA(PEOPLE, new Set(["dept-prod-1", "pos-engineer-soft"]), "filter", u).includes(
    "zhang"
  ),
  "and"
);
assert(
  filterDesignB(
    PEOPLE,
    new Set(["dept-test-qa", "pos-engineer-soft", "pos-engineer-hard"]),
    u
  ).includes("chen"),
  "B facet"
);
console.log("smoke ok");
