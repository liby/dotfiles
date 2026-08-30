# Iterative Evaluator Goals

In the goal file, require:

- the named evaluator or skill that owns issue classification
- a live issue frontier with each accepted item carrying a trigger path, evidence, impact, and owner
- each mutation round to report how the frontier changed: resolved, newly discovered with new trigger evidence, regression from the last fix, repeated prior issue, speculative claim without new evidence, or manual/runtime/product gap
- progress evidence after each mutation: validation output, source evidence, runtime evidence, or explicit manual gap
- a stop-and-report condition when the loop repeats the same root cause, the next fix would undo a prior fix, new work is mostly caused by the last fix, or the evaluator keeps producing claims without new evidence

Do not require a hard round budget unless the user asks for one or the executor skill owns a runtime safety cap. Do not freeze the issue set at the first pass. New findings can enter when they add a new trigger path, source-of-truth evidence, or a real regression. If a named evaluator skill has a loop or fix policy, reference that skill as the owner instead of restating its full rules.
