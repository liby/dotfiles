# Next.js

Load when changed code touches Next.js App Router, Pages Router, route handlers, server actions, middleware, proxy files, cookies, cache, revalidation, generated metadata, or the server and client component boundary.

**Next.js behavior is split across browser, server, framework routing, cache, and deployment runtime.** Review the boundary that owns the final response or session state, not an intermediate one.

- server and client component placement, especially server-only authority crossing into client-visible code.
- route handlers, middleware, and proxy files: HTTP methods, status bodies, and framework discovery paths before treating responses as interchangeable; do not delete a supported handler to get 404 fallthrough unless the external contract changed.
- discovery, JSON-RPC, MCP, webhook, and SDK-called endpoints return protocol-shaped success and error bodies, not only a browser-friendly status page.
- webhook and protocol routes authenticate by signature or a deterministic check at the route boundary, not by CORS, origin, or user-agent.
- proxy or middleware allowlists for public assets, icons, metadata, `robots.txt`, `sitemap.xml`, framework internals, and embed entry routes when access control changes request classes.
- server actions, cache entries, revalidation, and generated metadata whose result can outlive the request that created it.
- final user-visible state and source-owned session state, not only URL consumption or a screenshot of an intermediate state.

Webhook signatures, CORS and origin checks, cookie and session validation, and public-asset allowlists: [security](../concerns/security.md). Server-only authority reaching the client: [boundaries](../concerns/boundaries.md). Runtime evidence for browser or session claims: [SKILL](../../SKILL.md).
