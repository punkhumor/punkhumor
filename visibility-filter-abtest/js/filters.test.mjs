import { PEOPLE, CATEGORIES } from "./data.js";
import { filterDesignA, filterDesignB, initialDesignBState } from "./filters.js";
import { TASKS } from "./tasks.js";

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

// Design A OR
{
  const ids = filterDesignA(PEOPLE, new Set(["dept-prod"]), "or");
  assert(sameSet(ids, ["zhang", "zhao"]), "A OR prod");
}

// Design A AND
{
  const ids = filterDesignA(
    PEOPLE,
    new Set(["dept-test", "pos-engineer"]),
    "and"
  );
  assert(sameSet(ids, ["chen", "zhou", "wu"]), "A AND test+engineer");
}

// Design B: only prod department (others all selected) — unbound pass
{
  const state = initialDesignBState(CATEGORIES);
  state.department.selected = new Set(["dept-prod"]);
  const ids = filterDesignB(PEOPLE, state);
  assert(sameSet(ids, TASKS[0].expectedB), "B dept=prod PDF");
}

// Design B: test dept + engineer; identity & work all selected
{
  const state = initialDesignBState(CATEGORIES);
  state.department.selected = new Set(["dept-test"]);
  state.position.selected = new Set(["pos-engineer"]);
  const ids = filterDesignB(PEOPLE, state);
  assert(sameSet(ids, TASKS[1].expectedB), "B test∩engineer");
}

// Design B: only workType fire|height enabled
{
  const state = initialDesignBState(CATEGORIES);
  for (const cat of CATEGORIES) {
    if (cat.id !== "workType") {
      state[cat.id].enabled = false;
      state[cat.id].selected.clear();
    }
  }
  state.workType.selected = new Set(["work-fire", "work-height"]);
  const ids = filterDesignB(PEOPLE, state);
  assert(sameSet(ids, TASKS[2].expectedB), "B fire|height");
}

// Design A task3
{
  const ids = filterDesignA(
    PEOPLE,
    new Set(["work-fire", "work-height"]),
    "or"
  );
  assert(sameSet(ids, TASKS[2].expectedA), "A fire|height");
}

console.log("All filter tests passed.");
