# Python

Load when changed code touches Python ingestion, API clients, loaders, scripts, schema generation, dataframe transforms, or Python that writes files, warehouse tables, or external systems.

**Python data code often turns absence, partial API output, or loader inference into durable state.** Review the source contract before accepting a successful run as correct.

- exception handling that returns empty data, `None`, or a placeholder where the caller needs a visible failure.
- loader or dataframe type inference before writing a schema, CSV, parquet file, warehouse table, or downstream artifact.
- timezone, numeric string, decimal precision, nested object, enum, and missing-field handling with values outside the fixture.
- file or table output identity, overwrite versus append mode, cleanup behavior, and durable location.

Visible failure versus swallowed error: [failure-states](../concerns/failure-states.md). Type inference feeding downstream tables: [data-integrity](../concerns/data-integrity.md), [elt](elt.md), [sql](sql.md). Pagination, rate limits, and remote fan-out: [data-integrity](../concerns/data-integrity.md). Retry lifecycle: [async](async.md). Success markers after durable writes: [failure-states](../concerns/failure-states.md). Fixtures and proof claims: [tests](../concerns/tests.md).
