# Security And Configuration

Load when changed code touches env vars, service identities, feature flags, deployment config, logging or analytics sinks, or network policy; request auth, route matchers, CORS, origin, cookies, sessions, or iframe and embed state; or sandboxed and model-controlled execution.

**Classify every value, then prove a lower-trust input cannot become higher-trust authority.** Configuration and request metadata are authority boundaries: wrong config or an unvalidated request can look like valid behavior once it crosses an environment or permission boundary.

## Classify and validate each value

Classify added, renamed, exposed, or moved values as public, server-only, secret, environment-specific, or permission-bearing, and trace each from definition to runtime consumer. A public value must not become permission-bearing without a deterministic check. Validate runtime settings at request or load time before allocating external resources, models, sandboxes, or network access, and check every mechanism a consumer reads, not just one variable or one wrapper.

## Authorize at the boundary that owns the decision

When auth, route matching, CORS, origin, user-agent, account, workspace, or permission logic changes, check at least one positive and one negative path at the boundary that owns the decision. CORS, origin, user-agent, and Fetch Metadata checks are routing signals, not authorization, unless paired with a deterministic check. Treat cookies, session fields, and iframe or embed state as display or routing inputs until a server boundary validates the current identity, and test expired, missing, mismatched, and cross-frame sessions when embedded behavior changes.

## Keep environments and trust levels from merging

Verify that test, staging, production, tenant, and region facts cannot merge when telemetry, logs, analytics, caches, warehouses, or shared sinks feed operational decisions. Prefer functional roles and explicit capabilities over name-based permission bundles for service accounts, tokens, grants, and policies. Classify every value sent to sandboxed or model-controlled code and verify the lower-trust runtime cannot read higher-trust authority.

Outbound payload filtering and credential lifecycle: [boundaries](boundaries.md). Sandbox-launch specifics: [agent](../rules/agent.md). Warehouse grants and row filters: [sql](../rules/sql.md), [elt](../rules/elt.md).
