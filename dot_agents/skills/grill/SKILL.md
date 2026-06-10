---
name: grill
description: Interview the user one question at a time to stress-test a plan or design until the open decisions are resolved, with a recommended answer per question. Use when the user says "grill me", "盘问我", "挑战我的方案", asks to stress-test or pressure-test a plan, or wants a design challenged before implementation. Not for reviewing code diffs (use review) or turning a settled task into a goal file (use set-goal).
argument-hint: "[plan file, notes, or empty for the plan in conversation]"
allowed-tools:
  - Bash(rg:*)
  - Bash(fd:*)
  - Read
---

Interview the user about their plan until the open decisions are resolved. The deliverable is the interview and a final decision record; do not start implementing.

## Process

1. Locate the plan: $ARGUMENTS, a named plan or goal file, or the current conversation. If none exists, ask for the plan in one sentence.
2. Map the decision tree before asking anything: the load-bearing decisions, their dependencies, and which are still open. Resolve upstream decisions before their dependents.
3. Ask one question at a time, in Chinese, and wait for the answer before the next. Each question names the decision it resolves and ends with your recommended answer and the reason.
4. **If a question can be answered by exploring the codebase, explore the codebase instead of asking.** Only the user can answer intent, external constraints, and trade-off preferences.
5. When an answer contradicts the code, a stated constraint, or an earlier answer, surface the contradiction immediately with the evidence and re-ask.
6. Probe fuzzy boundaries with invented concrete scenarios; one specific edge case beats an abstract "what about errors?".
7. Stop when every load-bearing decision has an answer or a named owner. Close with a decision record: one line per resolved decision (decision, choice, reason), open items with owners, and assumptions the interview changed. Offer to write the record into a plan file the user names; do not create files unprompted.

A plan with no real open decisions is a valid outcome: say so after the mapping pass and list the two or three riskiest assumptions worth a second look instead of manufacturing questions.
