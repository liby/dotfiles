# Data Integrity

Load when changed code reads or writes data at scale or changes its meaning: DB or API access from handlers, services, jobs, loops, or resolvers; ORM use; joins and aggregates; transactions; cursors; backfills; migrations; or derived fields.

When DB or API operations grow with rows, events, users, tools, retries, or rendered records on a live backend path, prove the path is hot or unbounded and state the expected call count; prefer a join, eager load, `IN` or bulk lookup, source-side filter, or one enrichment query. `Promise.all` over individual queries is concurrency, not batching. Do not report N+1 for an in-memory loop or a documented fixed-small set. A performance finding must cite the reachable scaling path, the cardinality source, the operation, and the expected round-trip growth.

When a count, summary tile, leaderboard, or grouped aggregate sits beside a filtered list, keep both on the same owner, filter, visibility, soft-delete, and timezone contract, and verify the SQL or ORM shape or a focused test pins both the representative rows and the summary values. A shared endpoint does not prove two CTEs or service calls use the same scope.

For query and write semantics, verify parameterization and ORM or upsert lifecycle through documentation, generated SQL, or a focused test. Protect invariants with the narrowest owner-level transaction, CAS update, or idempotency guard; keep protected reads and writes on the transaction-scoped client. Record target or in-progress state before an external effect and expose failures through status, retry, or reconciliation.

Batch at the data owner when reads or writes can be grouped or source-filtered, but preserve the association between each input and its result, required ordering, per-record failure, idempotency key, retry behavior, and rate-limit handling. Do not turn partial failure into apparent all-record success. The same identity discipline governs replay: an event ID, dedupe key, lock, or CAS guard must stay correct across failure and retry and must not suppress a required later attempt.
