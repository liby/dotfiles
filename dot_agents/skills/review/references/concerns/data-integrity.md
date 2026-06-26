# Data Integrity

Load when changed code reads or writes data at scale or changes its meaning: DB or API access from handlers, services, jobs, loops, or resolvers; ORM use; joins and aggregates; transactions; cursors; backfills; migrations; or derived fields.

**A data path that looks correct on one row can corrupt or stall at scale, and a write that throws no exception can still make later reads wrong.** Review how round trips grow with rows, and whether each write keeps grain, scope, and meaning intact.

## Round trips must not grow with the data

When DB or API operations grow with rows, events, users, tools, retries, or rendered records on a live backend path, prove the path is hot or unbounded and state the expected call count; prefer a join, eager load, `IN` or bulk lookup, source-side filter, or one enrichment query. `Promise.all` over individual queries is concurrency, not batching. Do not report N+1 for an in-memory loop or a documented fixed-small set. A performance finding must cite the reachable scaling path, the cardinality source, the operation, and the expected round-trip growth.

## Aggregates share the list's scope

When a count, summary tile, leaderboard, or grouped aggregate sits beside a filtered list, keep both on the same owner, filter, visibility, soft-delete, and timezone contract, and verify the SQL or ORM shape or a focused test pins both the representative rows and the summary values. A shared endpoint does not prove two CTEs or service calls use the same scope.

## Prefer the ORM; raw SQL only in the owner

Prefer the repository's ORM or query builder. Raw SQL is acceptable only inside the data owner when the builder cannot express the required shape, locking primitive, vendor function, CTE, or conflict predicate, and only parameterized; never interpolate untrusted values. Prefer schema-derived insert and update types, and verify ORM lifecycle and upsert semantics through docs, generated SQL, or a focused test rather than assuming hooks fire on a conflict update. Do not request an ORM rewrite of a parameterized advisory lock, database-specific concurrency predicate, aggregate, or CTE solely for ORM purity.

## Protect the invariant with the smallest transaction

Prefer the smallest owner-level transaction, CAS update, or idempotency guard before reaching for global locks or cross-module orchestration. Pass the transaction-scoped client through the lock or transaction callback and keep every protected read and write on it. When a flow both changes DB state and calls an external provider, make DB state express the target or in-progress state before the external effect, and make failure visible through status, retry, or reconciliation. A fail-open DB write is acceptable only when the repo explicitly treats that write as sidecar telemetry and the control plane must continue.

## Batching preserves per-record outcomes

Batch at the data owner when reads or writes can be grouped or source-filtered, but preserve the association between each input and its result, required ordering, per-record failure, idempotency key, retry behavior, and rate-limit handling. Do not turn partial failure into apparent all-record success. The same identity discipline governs replay: an event ID, dedupe key, lock, or CAS guard must stay correct across failure and retry and must not suppress a required later attempt.

## Changing what rows mean touches every path

For create, update, delete, move, replay, and backfill, check that later reads, analytics, billing, search, and replay stay correct. When widening a cursor or filter, inspect existing state, first-run behavior, and whether a reset or one-time backfill is required, and store the discriminators needed to interpret a derived field in the same record.

Source paging and pipeline cursors: [elt](../rules/elt.md). SQL grain, null, and cast semantics: [sql](../rules/sql.md). Replay and retry lifecycle: [async](../rules/async.md).
