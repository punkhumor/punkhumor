#!/usr/bin/env node
/** Smoke-test filter engines + click handler semantics without a browser. */
import { PEOPLE, CATEGORIES } from "./data.js";
import {
  filterDesignA,
  filterDesignB,
  initialDesignBState,
  parentCheckState,
} from "./filters.js";

function assert(c, m) {
  if (!c) throw new Error(m);
}

const selected = new Set();
assert(parentCheckState(CATEGORIES[1], selected) === "none", "none");
CATEGORIES[1].children.forEach((c) => selected.add(c.id));
assert(parentCheckState(CATEGORIES[1], selected) === "all", "all");
selected.delete(CATEGORIES[1].children[0].id);
assert(parentCheckState(CATEGORIES[1], selected) === "partial", "partial");

// toggle leaf add/remove
const s = new Set();
s.add("dept-prod");
assert(filterDesignA(PEOPLE, s, "or").includes("zhang"), "or shows zhang");
s.add("pos-engineer");
assert(filterDesignA(PEOPLE, s, "and").includes("zhang"), "and zhang");
assert(!filterDesignA(PEOPLE, s, "and").includes("zhao"), "and hides zhao");

const facet = initialDesignBState(CATEGORIES);
facet.department.selected = new Set(["dept-prod"]);
const ids = filterDesignB(PEOPLE, facet);
assert(ids.includes("zhang") && ids.includes("sun"), "facet unbound");

console.log("smoke ok");
