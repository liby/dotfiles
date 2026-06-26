---
name: polymarket
description: >-
  Shared read-only Polymarket API and data-interpretation reference. Use whenever
  a task may read, fetch, debug, or interpret Polymarket public data: Polymarket,
  Gamma API, Data API, CLOB, orderbook/order book, prices-history, activity,
  trades, positions, closed-positions, condition ID, token ID, clobTokenIds,
  market resolution, settlement/redeem evidence, wallet history, leaderboard/PnL,
  or local Polymarket CLI/API commands. Load before any downstream skill that
  reads Polymarket data, so these API footguns are resolved once here. Not for
  executing live orders,
  cancellations, redeems, merges, splits, wallet funding, credential extraction,
  or private-key operations.
allowed-tools:
  - Bash(curl:*)
  - Bash(jq:*)
  - Bash(polymarket:*)
---

# Polymarket Read-Only Source Layer

Load this skill before interpreting `polymarket.com` public API, CLOB, Gamma, Data API, wallet, leaderboard, order book, or settlement data. It captures Polymarket data footguns that official docs do not surface and that only show up under live testing, so any downstream task reads the data correctly, whatever it does with it.

## Safety

- Keep this workflow read-only. Do not place orders, cancel orders, redeem, merge, split, approve, deposit, withdraw, export keys, or move funds.
- Fetch only with unauthenticated GET. Never attach an `Authorization` header, cookie, api key, or signed body to a request, and never POST/PUT/DELETE to order, trade, relayer, or bridge endpoints. Use only read subcommands (query, get, list) of any local `polymarket` CLI, never order, cancel, redeem, merge, split, or fund subcommands.
- Do not read `.env`, private keys, cookies, local storage, shell history, process lists, token-bearing logs, signed order payloads, CLOB auth headers, or wallet secrets.
- Treat authenticated trading, bridge, relayer, and `polymarket.us` docs as different surfaces from `polymarket.com` public-data work. Use them only as documentation sources when the user explicitly asks about those products, and do not mix their endpoints into public CLOB/Gamma/Data analysis.
- When reporting API failures, keep status, endpoint, token/condition IDs when needed, fetch time, and the exchange message. Redact headers, signatures, signed bodies, tokens, and full HTML bodies.
- Use repo-local AGENTS.md and project skills for production boundaries. This skill supplies shared Polymarket data behavior, not permission to trade.

## Process

1. Classify the task: market discovery, wallet/trader history, order book/price, fill realism, settlement/resolution, leaderboard/PnL, or CLI/API usage.
2. Start from current source-owned data. Prefer official Polymarket docs for endpoint shape, local checked-in source for repo-specific wrappers, and live read-only probes for behavior that can drift.
3. Identify the API family before querying: Gamma for events, markets, tags, search, and public profiles; Data API for activity, trades, positions, closed positions, values, holders, and leaderboard-style user data; CLOB for order books, prices, midpoints, spreads, and `prices-history`. Public trade history is Data API `/trades`; `clob.polymarket.com/trades` is authenticated (L2) and out of scope for this read-only layer.
4. Bound the read before fetching. Use endpoint filters, exact wallet/market IDs, time windows, `limit`, and cursor parameters so irrelevant data does not leave the API.
5. Save any non-trivial JSON response to a descriptive `/tmp/poly_<purpose>.json` file, then inspect the response envelope before iterating. If the shape is not the expected success schema, report it instead of forcing the success parser.
6. Normalize market identity with `conditionId` and token IDs. Use slug, title, or UI text only for discovery, then carry `conditionId`, outcome, token ID, timestamp, and source together.
7. Output compact evidence: source link or command, UTC fetch time, endpoint, relevant fields, and failed sources. Prefer TSV rows or a small field projection over raw JSON.

## Source Checks

- Official docs: use `https://docs.polymarket.com/api-reference/introduction` to confirm API families and base URLs before adding or changing endpoint claims.
- Market data docs: use `https://docs.polymarket.com/market-data/overview` for Gamma/Data/CLOB responsibilities, market identifiers, and discovery flow.
- CLOB read auth: use `https://docs.polymarket.com/api-reference/authentication` to distinguish public read endpoints from authenticated trading endpoints.
- CLOB price history: use `https://docs.polymarket.com/api-reference/markets/get-prices-history` and `https://docs.polymarket.com/api-reference/markets/get-batch-prices-history` before relying on `prices-history` parameters, response shape, or batch limits.
- Profile/history docs: use `https://docs.polymarket.com/api-reference/core/get-user-activity`, `https://docs.polymarket.com/api-reference/core/get-current-positions-for-a-user`, `https://docs.polymarket.com/api-reference/core/get-closed-positions-for-a-user`, `https://docs.polymarket.com/api-reference/core/get-trades-for-a-user-or-markets`, and `https://docs.polymarket.com/api-reference/core/get-trader-leaderboard-rankings` before assuming limits or fields.
- Official agent material: use `https://github.com/Polymarket/agent-skills` and its `market-data.md` for broad integration context, but keep this local skill narrower and read-only.

## Public Read Patterns

Use these as starting points, then verify parameters in docs or with a small probe close to the analysis time:

```bash
# Gamma metadata and discovery
curl -sS 'https://gamma-api.polymarket.com/events?slug=<slug>' | jq '. | length'
curl -sS 'https://gamma-api.polymarket.com/markets?active=true&closed=false&limit=50'

# Data API wallet and trade history
curl -sS 'https://data-api.polymarket.com/activity?user=<wallet>&limit=500&offset=0'
curl -sS 'https://data-api.polymarket.com/activity?user=<wallet>&limit=500&end=<oldest_timestamp>'
curl -sS 'https://data-api.polymarket.com/positions?user=<wallet>&limit=500&offset=0'
curl -sS 'https://data-api.polymarket.com/closed-positions?user=<wallet>&limit=50&offset=0'
curl -sS 'https://data-api.polymarket.com/trades?market=<conditionId>&user=<wallet>&limit=500'

# CLOB books, prices, and history
curl -sS 'https://clob.polymarket.com/book?token_id=<token_id>'
curl -sS 'https://clob.polymarket.com/price?token_id=<token_id>&side=BUY'
curl -sS 'https://clob.polymarket.com/prices-history?market=<token_id>&interval=1d'
```

If a local `polymarket` CLI exists, discover read-only commands with `polymarket --help` and prefer `--output json | jq -r ... @tsv` for large responses.

## Output Size Control

- For Gamma, Data API, and CLOB calls that can return more than a few rows, redirect raw JSON to `/tmp/poly_<purpose>.json` and parse it from that file. Reuse the file for alternate projections instead of refetching.
- Use `jq -r '... | @tsv'` with a header row for scans, wallet activity, positions, trades, and order-book levels. Extract only fields needed for the decision.
- Check common error shapes before iterating: `error`, `errors`, `message`, `code`, empty arrays, HTML bodies, and Cloudflare responses. If the shape is not the expected success schema, inspect with `jq '.'` from the saved file and report the mismatch.
- Push reduction into the request, not into local post-filtering: exact wallet/market/token IDs, event slug, time bounds, `limit`, `sort`, and cursor parameters. Do not fetch broad history and summarize locally unless coverage itself is the task.
- For order books, project only the levels required for the claim, such as best bid/ask, top N by price, or cumulative size by side. Do not paste the full book.

## Interpretation Rules

- Treat pagination limits, endpoint availability, batch sizes, book ordering, and UI/API display behavior as current-behavior checks. Cite official docs or include a small read-only probe with UTC fetch time before relying on them.
- Resolve wallet identity before querying user data. Positions, activity, holders, and leaderboard are keyed by the proxy (funder) wallet, returned as `proxyWallet`, not the signing EOA the user sees in a wallet app or on Polygonscan. If `user=<address>` returns an empty array, suspect an EOA-vs-proxy mismatch before concluding the address has no history.
- For `activity`, prove coverage with oldest/newest timestamps when the conclusion depends on history depth. Use cursor-style parameters only after docs or a probe confirms the endpoint accepts them. Data API and `prices-history` timestamps are UNIX seconds (10 digits); pass seconds to `end=`, not language-default milliseconds.
- For `closed-positions`, compare against open positions, total value, activity/trade cashflow, unresolved losers, and redeemable states before scoring a wallet or leaderboard result.
- For `activity.price`, verify the field semantics from current docs or by recomputing from size/value fields before inferring submitted limit price or quoting behavior.
- For one wallet and one market, use an exact-market trade/activity source before concluding entry vs exit, BUY vs SELL, or pre-end vs post-end behavior.
- For Gamma JSON-string fields such as `outcomes`, `outcomePrices`, and `clobTokenIds`, parse them as structured JSON before indexing.
- For executable price, fill realism, or latency claims, use the CLOB book, price endpoints, Data API trades, or `prices-history`. Do not infer executable prices from Gamma metadata alone.
- For CLOB books, compute best bid and best ask from the returned price levels unless current source documentation and a probe prove the response ordering is safe for the endpoint and client in use.
- For CLOB batch calls and any per-item response, inspect each item. Do not treat HTTP 200 as success for every requested token or market.
- For neg-risk markets, inspect the event/market structure and relevant books together. A single token book can understate executable liquidity when cross-condition matching is available.
- For settlement, prefer resolution metadata, Data API activity, and chain evidence over UI wording or post-end book availability. UI REDEEM cash-in can look deposit-like and books can disappear after market end. `active`, `closed`, and `archived` are independent booleans (a market can be `active:true` and `closed:true`), and closed does not imply resolved or redeemable, so confirm payout with `umaResolutionStatuses`, `resolvedBy`, and outcome prices, which can lag or stay empty after close.
- For leaderboard data (Polymarket trader rankings), treat a high rank as a scoring-window signal, not a wallet's full realized PnL or settled track record.
