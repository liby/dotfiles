# Next.js

Load when changed code touches Next.js App Router, Pages Router, route handlers, server actions, middleware, proxy files, cookies, cache, revalidation, generated metadata, or the server and client component boundary.

- route handlers, middleware, and proxy files: HTTP methods, status bodies, and framework discovery paths before treating responses as interchangeable; do not delete a supported handler to get 404 fallthrough unless the external contract changed.
- proxy or middleware allowlists for public assets, icons, metadata, `robots.txt`, `sitemap.xml`, framework internals, and embed entry routes when access control changes request classes.
- server actions, cache entries, revalidation, and generated metadata whose result can outlive the request that created it.
