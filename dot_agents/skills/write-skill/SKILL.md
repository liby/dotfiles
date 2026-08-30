---
name: write-skill
description: Create, test, improve, or audit agent skills and reusable agent instructions. Use for evidence-driven refinement from feedback or failed runs, skill routing, workflow or wording optimization, validation, splitting or merging skills, and instruction-owner audits. Not for application-code review, generic documentation or comment cleanup, running an existing skill without changing it, or deleting a skill without redesign or replacement.
allowed-tools:
  - Bash
  - Agent
  - Read
  - Edit
  - Write
  - WebFetch
  - WebSearch
---

# Write Skill

Write skills that change agent behavior. Use established domain terms when they preserve the intended trigger and boundary. Keep routing, workflow, tool use, validation, examples, and rationale only when they change the next action or choice. Cut explanatory restatements, intermediate history, repeated best practice, and competent-agent defaults.

## Process

1. Classify the request, and produce the smallest artifact it needs (a one-off standard, phrasing, or lesson belongs in your reply as prose, not a new `SKILL.md`):
   - New or rewrite: edit the skill.
   - Trigger audit: report findings first; do not edit until asked.
   - Split or merge: change structure only when it improves routing or loaded context.
   - Distilled lesson: add a rule only if it clears Rule Hygiene.

   When a step sequence keeps finishing early, sharpen that step's done-condition first (local and cheap); split into a separate skill only when the condition cannot be sharpened further and the rush is actually observed in real runs. Splitting pays off only across a real context boundary (a `context: fork` skill, a subagent dispatch, or a user `/name` invocation hand-off): an inline model-invoked skill call leaves the later steps in the same window and clears nothing. When a rename, split, merge, or replacement removes a skill, `rg` sibling skills' `description`, `when_to_use`, and body routing lines and update every pointer. A direct deletion with no redesign or replacement belongs to the repository's normal file-removal workflow.
2. Resolve the owning source from current environment or repository instructions before editing an installed skill. Edit the source instead of its deployed copy. When no owner is declared, change only an explicitly named path and do not adopt it into another registry as a side effect.
3. Read `SKILL.md` fully before judging; read linked files only when they affect the change. Re-read right before any full-file rewrite, and Read before Edit/Write when resuming after compaction, because an edit since your last read (including the user's own manual trim) is silently lost; prefer targeted edits over rewriting the whole file. When the edit tool rejects a stale or unread file ("File has not been read yet" in Claude Code), read the file once and retry; never repeat the identical edit call.
4. Diagnose across the instruction graph, not just the named file. When observed behavior violates an existing rule, verify that the runtime loaded it, identify its narrowest owner and any higher-priority or conflicting instruction, then fix that load, ownership, priority, or conflict before rewriting the rule. Otherwise check whether one root cause explains the same symptom elsewhere and fix it once.
5. When user corrections, failed runs, reviews, evals, or transcript evidence are used to diagnose or improve an existing instruction, load and follow the [evidence-driven improvement loop](references/improvement-loop.md) before judging or proposing a change. Separately, when a candidate change touches model-invocable routing, conditional reference loading, claimed output quality, or material global `AGENTS.md`/`CLAUDE.md` behavior, load the [evaluation protocol](references/evaluation.md) before judging or proposing the candidate.
6. For non-trivial new skills, inspect 2-4 comparable local or public skills. Use actual `SKILL.md` files or current runtime docs, not README claims.
7. Preserve working trigger behavior unless the task is to change it.
8. Ask one question only when the requested behavior still has multiple valid interpretations after reading the relevant files.
9. Before finishing, run a subtraction pass: merge what you duplicated, delete what went stale, relocate what drifted from its section, disclose rare detail into a reference. Rewrite existing wording only when the change is a clear win, shorter without losing information; leave a dense sentence alone when every clause carries weight. The edit should leave the skill net flat or shorter unless it added genuinely new behavior.

## Routing

The `description` is the routing surface for model-invocable skills. Write it before the body. Name the capability or outcome the skill owns, then the stable user intent, artifact, product, or context that should select it. `Use when` is a useful sentence form, not a required template. For manual-only skills, write a short human-facing menu line instead; see Frontmatter.

- Start from observed prompts, tool history, repository vocabulary, and realistic adjacent tasks. Do not invent quoted user phrases.
- Treat literal phrases, aliases, and cross-language or register variants as candidates, not a checklist. Keep one only when history or a fixed routing evaluation shows that it recovers a real miss or preserves a meaningful boundary.
- Do not patch a failed query by copying its exact wording into the description. Generalize the intent or artifact category, then validate it on held-out prompts.
- Explicit `/name` or `$name` invocation does not need to be repeated in the description to work. Explicit-use history describes user behavior; it does not prove that implicit routing can be disabled.
- Add `Not for...` only when a realistic nearby task would otherwise select the wrong skill. Name the competing task or alternate route.
- For paired or tiered surfaces, name the boundary in the description: lightweight search/read connector vs advanced API connector, read-only browse vs write/manage, local CLI vs remote host, public source vs private workspace.
- Do not exclude a broader user request that can legitimately include this skill as a step, such as using a commit step inside a requested push. Put write, push, delete, or credential safety limits in the body workflow instead.
- Keep it under 1024 characters. If that feels hard, split the skill or narrow scope.
- Bad: `Helps with documents.`
- Good: `Extract tables from PDFs and export them as CSV. Use when a user needs tabular data from a PDF. Not for editing PDF page layout.`

## Frontmatter

Target this local Claude Code and Codex setup in one `SKILL.md`. Keep portable discovery fields (`name`, `description`) clear because both runtimes use them to route. Add `when_to_use` only when extra routing context is worth a field some clients may ignore. Treat the other fields as Claude Code-specific execution metadata; behavior required in both runtimes belongs in the body. Use the [Agent Skills frontmatter spec](https://agentskills.io/specification#frontmatter) for the portable `SKILL.md` baseline and the [Claude Code frontmatter reference](https://code.claude.com/docs/en/skills#frontmatter-reference) for Claude-specific fields, types, and defaults.

- Prefer a short, easy-to-type `name`/directory slug; drop category nouns the description already carries (a platform word in the name duplicates the description and invites renames).
- Use `disable-model-invocation: true` only when Claude Code should never auto-load the workflow. Side effects, cost, or timing make a skill a candidate for manual invocation, not proof: first verify its actual human and model invocation paths, including sibling loads, because Claude treats a skill-from-skill load as model invocation. Write its `description` as a one-line human-facing `/` menu summary because Claude removes it from model context.
- For Codex manual-only routing, set `policy.allow_implicit_invocation: false` in the skill's `agents/openai.yaml`. Treat the Claude Code and Codex policies independently and verify both intended invocation paths.
- Use `user-invocable: false` only to hide a skill from Claude Code's `/` menu; it does not block model invocation.
- Use `context: fork` for explicit long-running tasks, independent review, or research. Do not put passive reference knowledge in a fork-only skill.
- Only add `argument-hint`, `arguments`, `agent`, `paths`, `shell`, `model`, `effort`, or `hooks` when they change invocation or execution. Keep shared skill behavior independent of host-specific argument interpolation; use invocation arguments or the user's accompanying request instead of embedding a runtime placeholder in body text.
- Treat `allowed-tools` as Claude Code prompt-free preapproval, not a deny-list, authorization rule, or cross-runtime capability contract. Match it to the normal contract when prompt-free execution is required: use exact entries only when the command set is exhaustive and stable, otherwise use `Bash(<program>:*)` or bare `Bash`, and validate that missing coverage cannot stop the workflow. Keep authorization requirements in the user request and skill body. Use `disallowed-tools` to remove tools from the model while the skill is active; reserve permission deny rules for blocking a tool globally.

## Loading And Structure

Place an instruction at the cheapest layer that reliably reaches the first action it must constrain:

- Always-loaded `AGENTS.md` or `CLAUDE.md`: behavior every relevant task needs before routing or file inspection.
- A runtime-supported path rule: behavior required only when a matching path is touched.
- `SKILL.md`: the common path and gates every activation of that capability needs.
- One-level `references/`: a rare or bulky branch with an observable load condition stated in the parent before the branch's first action.
- A validated script, hook, permission, or test: fragile, repeated, or deterministic enforcement that cannot depend on model recall.

Splitting helps only when common runs avoid the moved material and target runs reliably follow the pointer. A file imported into the startup context is organization, not progressive disclosure. If every activation must read a reference, keep it inline; if the pointer cannot state when to load it, narrowing or deleting the material is safer than hiding it.

Link bundled files relative to `SKILL.md`; both runtimes can resolve that path, unlike a host-specific skill-directory variable or hardcoded install directory. Derive temporary output paths from the runtime because fixed temp paths fail across sandboxed hosts. Use a one-hop format contract only when its schema must survive across sessions or writers; give it a write trigger and lifecycle, and require loading it before writing the artifact.

Runtimes keep metadata broadly visible but may truncate, reattach, or omit body content under context limits. Keep routing in the description and critical safety or recovery rules near the top of the body.

## Writing Rules

- When one rule maps several conditions to different actions, use a condition -> action list. Leave a dense single-condition sentence intact when every clause changes behavior.
- Prefer values the runtime or code can derive over counts, paths, or amounts hardcoded into prose. A literal like "the four flags" or an absolute path is a maintenance hazard the moment the underlying value changes; point at the source of truth or how to read it.
- Keep examples only when they prove output shape, trigger boundaries, a failure mode, or a quality boundary (acceptable vs unacceptable output at the same correctness level). A worked example must obey the skill's own rules: when it conflicts with a stated rule, models copy the example, so fix whichever one is wrong. A labeled negative example is exempt from the one rule it demonstrates breaking.
- Give every conditionally applicable template or output slot a legitimate empty form, such as "same as the minimal proposal; no structural change indicated"; a slot that must always be filled invites invented content. A slot whose absence must stop the workflow, such as a missing approval or an unresolved destructive target, keeps no empty form.
- In every skill edit, mask project names, personal names, hosts, private paths, clients, internal URLs, credential variable names, token variables, repo paths, and customer data; use them only in a skill explicitly scoped to that private environment.

## Rule Hygiene

Before adding a rule, search the runtime-visible global instructions and relevant sibling skills for the same trigger. Merge with the narrowest owner when the trigger, action, or boundary overlaps, replace wrong wording, and add only a failure mode no owner covers.

Keep a rule only when omitting it can cause a concrete wrong action or result in a realistic target case.

Keep reusable skills independently usable. Check commands, defaults, and side effects for policy leakage, not just wording:

- Keep a tool or runtime fact when it changes the command, input, output, or recovery path this skill owns.
- Keep only the narrow integration seam needed by this skill. Put caller policy, source ownership, registry maintenance, adoption, deployment lifecycle, and repository policy in the environment or repository that owns them.
- Describe a prerequisite from another capability as an outcome. A sibling skill may provide it when available, but successful completion must not depend on that sibling being installed unless the dependency is an explicit part of this skill's contract.

Put the rule at the earliest action it must constrain. An implementation convention owned only by a review-time skill cannot prevent the initial mistake; route it through an always-loaded repository instruction or deterministic enforcement instead.

Put the gate for a sensitive or irreversible step adjacent to the instruction that performs it, including in linked references and scripts; a warning in another section does not constrain the agent walking the execution sequence.

For evaluator, verifier, rubric, PASS/FAIL, or completion-gate rules, require trigger, evidence, an acceptance or manual-observation condition, failure action or stop, and owner: project skill, target repo, user confirmation, or CLI/runtime.

For feedback-derived changes, use the evidence-driven improvement loop rather than copying a correction into this section. Treat an approach the user confirmed as a constraint; do not weaken it while fixing something else.

Keep trace stores, durable session logs, sandbox state, and automatic progress ledgers out of shared skill text unless every target runtime supports the mechanism or the skill explicitly branches by runtime.

## Verification

1. Use the owning skill repository's existing validator, package script, test, lint, or marketplace command first; do not hand-roll checks it already owns.
2. For a change covered by the evaluation gate in Process, run that protocol before accepting the candidate.
3. Run changed scripts with fixed inputs and verify their output, exit codes, and failure path.
4. Scan the diff for private identifiers and hardcoded values the runtime can derive.
