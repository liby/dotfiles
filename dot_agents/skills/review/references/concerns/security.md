# Security And Configuration

Load when changed code touches env vars, service identities, feature flags, deployment config, logging or analytics sinks, or network policy; request auth, route matchers, CORS, origin, cookies, sessions, or iframe and embed state; or sandboxed and model-controlled execution.

Classify added, renamed, exposed, or moved values as public, server-only, secret, environment-specific, or permission-bearing, and trace each from definition to runtime consumer. A public value must not become permission-bearing without a deterministic check. Validate runtime settings at request or load time before allocating external resources, models, sandboxes, or network access, and check every mechanism a consumer reads, not just one variable or one wrapper.

When auth, route matching, CORS, origin, user-agent, account, workspace, or permission logic changes, check at least one positive and one negative path at the boundary that owns the decision. CORS, origin, user-agent, and Fetch Metadata checks are routing signals, not authorization, unless paired with a deterministic check. Treat cookies, session fields, and iframe or embed state as display or routing inputs until a server boundary validates the current identity, and test expired, missing, mismatched, and cross-frame sessions when embedded behavior changes.

Verify that environment, tenant, and region facts cannot merge through telemetry, logs, analytics, caches, warehouses, or shared sinks. Classify values sent to sandboxed or model-controlled code and prove the lower-trust runtime cannot read higher-trust authority.
