---
name: snow
description: Run read-only Snowflake inspection and SELECT queries with the installed Snowflake CLI. Use whenever a task needs live Snowflake data. Not for dbt compilation that needs no live warehouse access.
allowed-tools:
  - Bash(snow:*)
  - mcp__chrome-devtools__*
---

Run only read-only SQL through the persistent `snow` executable and configured default connection. When a workspace Snowflake skill also applies, follow its relation, query, limit, and interpretation guidance, but replace its Snowflake CLI launch commands with the command below and skip connection synchronization. If the configured connection fails, report the non-sensitive failure rather than replacing it. Prefer server-side aggregation or an explicit `LIMIT`.

Use `snow sql -q '<requested read-only SQL>' --format json --silent`.

Do not run a connection test, setup helper, or separate authentication command before querying. Let the query perform Snowflake CLI's native authentication flow when it needs one, and wait for that query instead of asking the user to recover authentication separately. Run a task's first query alone and start parallel queries only after it succeeds, because concurrent queries each begin their own browser sign-in when no valid one is cached. The connector waits for the sign-in without a time limit, so if a query is still waiting two minutes after its sign-in page opened, whether the connector or you opened it, terminate it and report that the browser sign-in did not complete; the identity provider may need the user to sign in.

If a query prints its SSO URL and remains waiting without `A browser window should have opened`, check the same query's subsequent output and browser state: the URL is printed before the opener returns. Once browser launch is confirmed to have failed, or the execution context is known to block application launches, keep that query running and handle its URL:

- Confirm it is waiting for the loopback callback. The connector listens when `SNOWFLAKE_AUTH_FORCE_SERVER=true` is set; `We were unable to open a browser window` instead means it is waiting for a pasted redirect URL on stdin. Browser navigation cannot satisfy that input, so terminate the query and report the boundary.
- Open the exact, complete URL from the original query output in a new tab of the connected signed-in browser, in the background when the browser interface supports it, without activating the tab or window. If the page asks for sign-in or MFA, terminate the query and report that boundary. After navigation, the original query's result is authoritative even if the page stays on `Redirecting to Snowflake client` or reports a callback-page error.
- Keep the URL out of commentary, final responses, files, and other shell processes. If output is truncated or incomplete, recover the full original URL through a supported interface for the same running query; never reconstruct it or substitute another query's URL. If recovery is unavailable, terminate the query and report that boundary.
- If browser control is unavailable or navigation fails, terminate the query and report that browser sign-in could not be completed. Completing sign-in through `snow` where a browser can open, such as in the user's terminal, can refresh the cached sign-in for later queries.
- Once the query has ended, close the tab you opened for it; on failure or cancellation, terminate the waiting query first. Leave every other tab alone.
