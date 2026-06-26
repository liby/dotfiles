# SQL

Load when changed code touches SQL models, migrations, warehouse tables, materialized views, constraints, indexes, joins, aggregates, grants, or schema tests.

**SQL can silently change meaning without throwing.** Review whether the query preserves entity grain, null semantics, type semantics, and permission boundaries.

- entity grain before joins, aggregates, `distinct`, window functions, unions, and incremental merge keys.
- `null`, empty string, numeric string, timestamp, timezone, and JSON field semantics before casts or comparisons.
- domain tests for enums, IDs, counts, timestamps, and fields that may be numeric today but text or structured later.
- grants, row filters, source freshness, and materialization changes that alter who can see data or when.
- old-object cleanup and rollout order for renamed views, models, schemas, materialized views, and lookup tables.

CRUD, replay, and backfill integrity, and fixing source types before downstream `coalesce`: [data-integrity](../concerns/data-integrity.md). Consumers of a renamed object: [contract](../concerns/contract.md). Warehouse grants and row filters: [security](../concerns/security.md). Layer ownership and incremental cursors: [elt](elt.md). Application query-layer ownership and ORM preference stay in [data-integrity](../concerns/data-integrity.md).
