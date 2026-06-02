# Core Principles

Load only sections whose trigger matches the diff.

## Evidence And Source Of Truth

Load for changed types, schemas, API wrappers, event payloads, numeric policy, units, time conversion, external mappings, generated types, config defaults, and compatibility paths.

Check the owner before judging behavior: upstream contract, generated schema, wrapper behavior, runtime convention, or documented rationale. Prefer existing wrappers, generated types, and source-owned values over local re-derivation.

For numeric policy, state unit and direction in one sentence. If a threshold changes, flag stale comments or docs that now mislead.

## Unobserved Guards And Complexity

Load for optional chaining, `null` or `undefined` widening, fallback values, broad normalization, caches, feature flags, compatibility layers, dependencies, helper extraction, and config switches.

Ask what observed input, caller, load shape, or contract requires the extra path. If absence is impossible, make the type strict or throw at the boundary. If dirty data is real, name the source and test that source.

Flag redundant `try`/`catch`, optional `undefined` widening, placeholder values, magic waits, and abstractions that only rename one caller.

## Observable Failure

Load for `catch`, `.catch`, ignored exit status, unchecked SDK result, `Promise.allSettled`, retry config, timeout, placeholder return, `done`, `healthy`, `configured`, `cached`, `skip`, and final markers.

Separate expected absence, business rejection, retryable failure, waiting state, and logic error. Let errors propagate until the boundary that can recover or notify.

For value-level statuses such as `state`, `status`, and `outcome`, check explicit success allowlists. Final markers must be written only after every required durable write and side effect completes.

## Ownership Boundary

Load when code bypasses a shared wrapper, gateway, repository, auth layer, protocol client, route handler, cost calculator, source-system owner, or shared primitive.

Compare peer modules before accepting a direct path. When a shared primitive changes failure semantics or optional input handling, grep every caller. Capture authority-sensitive context at the boundary where it becomes authoritative, or re-read it with documented semantics.

To identify the owner, trace create, update, delete, and terminal handlers for the resource, then compare the diff with peer wrappers.

## Names, Intent, And Semantic Fit

Load for new exported identifiers, schema fields, event names, storage keys, booleans, query-shaped functions, special-case branches, handler deletions, user-facing messages, and automation output.

Ask what the value means at this layer and whose perspective owns that meaning. A field should name downstream meaning, not the implementation step that produced it.

Flag:

- `is`, `has`, `check`, `validate`, or `get` names that hide mutation, notification, scheduling, or side effects
- identifiers that encode mutable numeric thresholds, fixture constants, or temporary implementation facts
- generated or user-facing output without a clear audience, trigger, next action, required context, and minimum actionable fields

## State, Order, And Lifecycle

Load for booleans, terminal states, match or switch arms, rollback, retry or wait, schedule, timeout, ordering changes, compare-and-set, streams, locks, and multi-step workflows.

Draw the lifecycle from creation through terminal state. List every terminal arm and the state each arm must restore or clear.

For waits, confirm the event cannot fire before waiting begins, or use a direct trigger or replayable signal. For streams and locks, trace both winner and loser paths to a client-visible terminal response.

## Symmetry And Completeness

Load for helpers, parsers, escaping logic, enums, schema splits, field renames, registry rows, capability matrices, generated files, refactors, deletions, deprecations, and any concept, value, or policy newly applied to one surface that peer surfaces should share.

Symmetry (symbol-local): grep same-class call sites and old inline implementations. For schema or enum changes, inspect writers, readers, replay or deserialization fallback, serialization defaults, and generated outputs. For removals, search known consumers outside the touched file when practical. For refactors, list old side effects such as retry, load balancing, rate limiting, metrics, and logging, then confirm which remain.

Completeness (concept-level): when a change applies a cross-cutting concept (the user's identity or locale/timezone, a permission, a currency, a feature flag, a logging or audit policy) to one surface, the missing surface is usually one the diff never touched and that shares no symbol with the change, so the symmetry sweep cannot reach it. Enumerate the surfaces that should embody the concept by searching for the concept itself rather than the changed symbol, and include parallel subsystems and code-execution environments (sandboxes, workers, cron runners) whose behavior depends on it but whose source never names it. Report a surface that should embody the concept but does not as a completeness gap to confirm against intent, not a proven bug.

## Data Integrity And Silent Corruption

Load for cursor sync, backfill, replay, import/export, materialized views, derived audit fields, soft deletion, uniqueness, partial success, additive lookup tables, overlapping ranges, and data model moves.

Check create, update, delete, move, replay, and backfill paths. Successful writes can still make later reads, analytics, billing, search, or replay wrong without an exception.

For cursor or filter widening, inspect existing state, first-run behavior, and whether a reset or one-time backfill is required. Store discriminators needed to interpret derived fields in the same record. For overlapping rules or sources, determine first-match vs additive behavior and test exclusive, overlapping, and boundary regions.

## Security, Identity, And Configuration

Load for auth, route matchers, roles, permissions, credentials, public config, env vars, service identities, sandboxes, telemetry keys, network policy, and environment splits.

Classify values as public, server-only, secret, environment-specific, or permission-bearing. Trace allow and deny paths, including negative cases. Prefer functional roles over user-name or service-name permission bundles.

Ensure model-controlled or sandboxed code cannot read credentials, privileged remotes, or secret-bearing process output.

## Verification And Tests

Load for bug fixes, test changes, deleted tests, validation claims, reviewer consensus, runtime-only claims, generated review worktrees, remote review, and nonstandard entrypoints.

Read validation config before trusting typecheck, lint, or tests. Require tests to fail for the repaired invariant, not only cover a fixture. Flag fixture-specific hardcoding when it satisfies the example without implementing the invariant.

Treat delegate or reviewer consensus as an investigation priority until the main session verifies the cited path. Compare remote changed-file stats or resolved snapshots against the local diff before reporting.

For browser, UI, hydration, cross-tab, connector, or external-service claims, verify the final user-visible state and the source-owned state that can overwrite it. URL consumption, command success, local optimistic cache, or a screenshot of an intermediate state is not completion proof when a later query, persisted cache, device, or backend session can change the result. If the current environment cannot expose that state, mark manual verification and state the exact observation required instead of passing the claim.

## Mechanical Sweep

Load for every changed, deleted, or moved line.

Check wrong condition, off-by-one, missing `await`, wrong variable, truthy check where `0` is valid, null dereference before guard, stale loop variable, unescaped user pattern, deleted validation, and moved code whose new caller lacks old preconditions.
