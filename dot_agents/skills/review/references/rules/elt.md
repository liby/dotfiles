# ELT And Pipelines

Load when changed code touches extract, load, transform jobs, dbt source declarations, staging or mart models, reverse ETL, backfills, cleanup tables, warehouse grants, or upstream resource allowlists.

**ELT layers split ownership of raw facts, source-owned facts, derived business facts, and operational permissions; a layer should not own a fact it cannot validate.**

- source and layer ownership: fix source type inference at the extraction or schema owner before adding downstream `coalesce`, casts, or fallback logic; a downstream guard is acceptable only when that layer owns the business normalization, or source history is genuinely mixed and the boundary is documented.
- incremental and window semantics: match the cursor to real mutation semantics, keep per-resource cursor state isolated, verify endpoint-supported filters and limits, and prefer overlap plus dedupe over `+epsilon` window gaps; do not reuse a loader pattern when the endpoint's filter, ordering, or page-limit contract differs.
- sync object lifecycle: when a sync, warehouse object, source name, grant, or downstream route is renamed or moved, check companion jobs, duplicate templates, old views and tables, grants, tags, caches, first-run behavior, and rollout cleanup; a selected-run test does not prove full-build hooks, grants, or stale targets are safe.
- operation semantics: verify create, update, delete, move, replay, and backfill paths for the reverse-ETL target contract; tests should reject contract-forbidden values, not only empirically present fields.

Generic API paging, remote fan-out, per-record batching, and CRUD or replay integrity: [data-integrity](../concerns/data-integrity.md). SQL grain and cast semantics: [sql](sql.md). Warehouse grants: [security](../concerns/security.md). Retry, replay, and success-marker lifecycle: [async](async.md).
