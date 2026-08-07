---
name: snow
description: Run read-only Snowflake inspection and SELECT queries with the installed Snowflake CLI. Use whenever a task needs live Snowflake data. Not for dbt compilation that needs no live warehouse access.
allowed-tools:
  - Bash(snow:*)
---

# Snowflake Execution

Own Snowflake CLI execution and authentication for every live query. When a workspace Snowflake skill also applies, follow its relation, query, limit, and interpretation guidance, but translate its CLI and bootstrap examples to the direct runtime below.

Run only read-only SQL through the persistent `snow` executable and configured default connection. Do not run workspace `uvx`, connection synchronization, or wrapper commands; translate the query to `snow sql -q` instead. If the configured connection fails, report the non-sensitive failure rather than replacing it. Prefer server-side aggregation or an explicit `LIMIT`.

Use `snow sql -q 'SELECT 1 AS value' --format json --silent`.

Do not run a connection test, setup helper, or separate authentication command before querying. Let the query reuse cached SSO and perform Snowflake CLI's native authentication flow only when needed. Wait for the original query to finish instead of asking the user to recover authentication separately.
