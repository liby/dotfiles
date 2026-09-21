---
name: context7
description: Look up current library, framework, SDK, CLI, or cloud API documentation with the Context7 CLI. Use for API syntax, configuration, version migration, library-specific debugging, and setup questions that name a specific library, even when you think you know the answer, because training data may lag releases. Not for general programming, refactoring, debugging business logic, or code review.
allowed-tools:
  - Bash(envchain context7:*)
---

Look up library documentation with the `ctx7` CLI, run through `envchain context7` so `CONTEXT7_API_KEY` reaches only that child process; an optional `CONTEXT7_BASE_URL` overrides the endpoint. Prefer this over web search for a named library's documentation.

- Resolve the library ID: `envchain context7 sh -c 'CTX7_TELEMETRY_DISABLED=1 exec ctx7 --base-url "${CONTEXT7_BASE_URL:-https://context7.com}" "$@"' _ library <name> "<what to look up>"`
- Query its documentation: `envchain context7 sh -c 'CTX7_TELEMETRY_DISABLED=1 exec ctx7 --base-url "${CONTEXT7_BASE_URL:-https://context7.com}" "$@"' _ docs <library-id> "<what to look up>"`

Run only those two subcommands; never run `ctx7 login`, `logout`, `setup`, `remove`, or `upgrade`, and never print or pass the API key as an argument.

Resolve first unless the request already carries a full `/org/project` ID. Pick the result whose name and description match the request, preferring higher source reputation, snippet count, and benchmark score; use a `/org/project/version` ID when the request names a version, and retry with the library's punctuated name when the first results look wrong. If nothing credible matches, say so rather than querying the wrong library.

Query one concept per `docs` call; combined queries return shallow results for each. Allow at most three `ctx7` commands per question, counting a redirect retry. A redirected library prints `New ID:`; rerun `docs` once with that ID. A no-results or empty-docs warning exits 0 and means Context7 has nothing — say so and fall back to web search if needed, never passing off training data as the lookup. On a quota or auth error, ask the user to run `envchain --set context7 CONTEXT7_API_KEY`.

Do not put secrets, credentials, personal data, or proprietary code in a query argument; it is sent to Context7.
